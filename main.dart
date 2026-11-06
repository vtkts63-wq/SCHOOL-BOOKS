
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<Database> openLibraryDb() async {
  return openDatabase(p.join(await getDatabasesPath(), 'school_library.db'),
    version: 1, onCreate: (db, version) async {
      await db.execute("CREATE TABLE books(id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT, className TEXT, status TEXT NOT NULL DEFAULT 'Available', borrower TEXT, issuedAt TEXT)");
      await db.execute("CREATE TABLE students(id TEXT PRIMARY KEY, name TEXT NOT NULL, className TEXT, phone TEXT)");
    });
}
void main() async { WidgetsFlutterBinding.ensureInitialized(); runApp(const LibraryApp()); }

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'School Library QR', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff1769aa), useMaterial3: true),
    home: const HomePage());
}
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  Database? db; int tab=0; bool loading=true;
  List<Map<String,Object?>> books=[], students=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    db ??= await openLibraryDb();
    books=await db!.query('books',orderBy:'title COLLATE NOCASE');
    students=await db!.query('students',orderBy:'name COLLATE NOCASE');
    if(mounted)setState(()=>loading=false);
  }
  String _id(String prefix)=>'$prefix${DateTime.now().millisecondsSinceEpoch}';
  Future<void> _addBook() async {
    final title=TextEditingController(), author=TextEditingController(), cls=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Add book'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Book title *')),
        TextField(controller:author,decoration:const InputDecoration(labelText:'Author')),
        TextField(controller:cls,decoration:const InputDecoration(labelText:'Class / subject'))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))]));
    if(ok==true && title.text.trim().isNotEmpty){
      await db!.insert('books',{'id':_id('BK'),'title':title.text.trim(),'author':author.text.trim(),'className':cls.text.trim(),'status':'Available'});
      await _load();
    }
  }
  Future<void> _addStudent() async {
    final name=TextEditingController(), cls=TextEditingController(), phone=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Add student'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Student name *')),
        TextField(controller:cls,decoration:const InputDecoration(labelText:'Class / section')),
        TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone (optional)'))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))]));
    if(ok==true && name.text.trim().isNotEmpty){
      await db!.insert('students',{'id':_id('ST'),'name':name.text.trim(),'className':cls.text.trim(),'phone':phone.text.trim()});
      await _load();
    }
  }
  Future<void> _deleteBook(Map<String,Object?> b) async {
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Delete book?'),
      content:Text('Delete "${b['title']}"?'),actions:[
        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))]));
    if(yes==true){await db!.delete('books',where:'id=?',whereArgs:[b['id']]);await _load();}
  }
  Future<void> _scan() async {
    final code=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const ScanPage()));
    if(code==null)return;
    final found=books.where((b)=>b['id']==code).toList();
    if(found.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No matching book QR found.')));return;}
    await _bookAction(found.first);
  }
  Future<void> _bookAction(Map<String,Object?> b) async {
    if(b['status']=='Available'){
      String? selected;
      final choice=await showDialog<String>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(
        title:Text('Issue: ${b['title']}'),
        content:DropdownButton<String>(isExpanded:true,hint:const Text('Select student'),value:selected,
          items:students.map((s)=>DropdownMenuItem(value:s['id'] as String,child:Text('${s['name']} (${s['className']})'))).toList(),
          onChanged:(v)=>setLocal(()=>selected=v)),
        actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(c,selected),child:const Text('Issue'))])));
      if(choice!=null){
        await db!.update('books',{'status':'Issued','borrower':choice,'issuedAt':DateTime.now().toIso8601String()},where:'id=?',whereArgs:[b['id']]);
      }
    } else {
      final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Return book?'),
        content:Text('${b['title']} is currently issued. Mark as returned?'),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Return'))]));
      if(yes==true)await db!.update('books',{'status':'Available','borrower':null,'issuedAt':null},where:'id=?',whereArgs:[b['id']]);
    }
    await _load();
  }
  Future<void> _printStickers() async {
    final doc=pw.Document();
    doc.addPage(pw.MultiPage(build:(ctx)=>[
      pw.Header(level:0,child:pw.Text('School Library — QR Stickers')),
      pw.Wrap(spacing:12,runSpacing:12,children:books.map((b)=>pw.Container(width:145,padding:8,
        decoration:pw.BoxDecoration(border:pw.Border.all()),
        child:pw.Column(children:[
          pw.BarcodeWidget(barcode:pw.Barcode.qrCode(),data:b['id'] as String,width:78,height:78),
          pw.SizedBox(height:4),pw.Text('${b['title']}',textAlign:pw.TextAlign.center),
          pw.Text('${b['id']}',style:const pw.TextStyle(fontSize:8))
        ]))).toList())
    ]));
    await Printing.layoutPdf(onLayout:(_)=>doc.save());
  }
  Widget _stat(String label,String value,IconData icon)=>SizedBox(width:MediaQuery.of(context).size.width/2-22,
    child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:Theme.of(context).colorScheme.primary),Text(value,style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold)),Text(label)]))));
  Widget _bookTile(Map<String,Object?> b)=>Card(child:ListTile(leading:const Icon(Icons.book),
    title:Text('${b['title']}'),subtitle:Text('${b['id']} • ${b['status']}'),
    trailing:PopupMenuButton<String>(onSelected:(v){if(v=='action')_bookAction(b);if(v=='delete')_deleteBook(b);if(v=='qr')_showQr(b);},
      itemBuilder:(_)=>[const PopupMenuItem(value:'action',child:Text('Issue / Return')),
        const PopupMenuItem(value:'qr',child:Text('Show QR')),const PopupMenuItem(value:'delete',child:Text('Delete'))])));
  void _showQr(Map<String,Object?> b)=>showDialog(context:context,builder:(c)=>AlertDialog(title:Text('${b['title']}'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[QrImageView(data:b['id'] as String,size:190),Text('${b['id']}')]),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));
  Widget _dashboard()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Library dashboard',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:16),Wrap(spacing:12,runSpacing:12,children:[
      _stat('Total books','${books.length}',Icons.menu_book),
      _stat('Available','${books.where((b)=>b['status']=='Available').length}',Icons.check_circle),
      _stat('Issued','${books.where((b)=>b['status']=='Issued').length}',Icons.assignment_turned_in),
      _stat('Students','${students.length}',Icons.groups)]),
    const SizedBox(height:16),
    FilledButton.icon(onPressed:_scan,icon:const Icon(Icons.qr_code_scanner),label:const Text('Scan book QR')),
    OutlinedButton.icon(onPressed:_addBook,icon:const Icon(Icons.add),label:const Text('Add a book')),
    OutlinedButton.icon(onPressed:_printStickers,icon:const Icon(Icons.print),label:const Text('Print QR stickers')),
    const SizedBox(height:12),const Text('Recently added',style:TextStyle(fontWeight:FontWeight.bold)),
    ...books.take(5).map(_bookTile)]));
  Widget _booksPage()=>ListView(padding:const EdgeInsets.all(12),children:[
    FilledButton.icon(onPressed:_addBook,icon:const Icon(Icons.add),label:const Text('Add book')),...books.map(_bookTile)]);
  Widget _studentsPage()=>ListView(padding:const EdgeInsets.all(12),children:[
    FilledButton.icon(onPressed:_addStudent,icon:const Icon(Icons.person_add),label:const Text('Add student')),
    ...students.map((s)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text('${s['name']}'),
      subtitle:Text('${s['className']} • ${s['id']}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),
        onPressed:()async{await db!.delete('students',where:'id=?',whereArgs:[s['id']]);await _load();}))))]);
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final pages=[_dashboard(),_booksPage(),_studentsPage()];
    return Scaffold(appBar:AppBar(title:const Text('School Library QR'),actions:[
      IconButton(tooltip:'Scan QR',onPressed:_scan,icon:const Icon(Icons.qr_code_scanner))]),
      body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
        destinations:const [NavigationDestination(icon:Icon(Icons.dashboard),label:'Dashboard'),
          NavigationDestination(icon:Icon(Icons.menu_book),label:'Books'),NavigationDestination(icon:Icon(Icons.groups),label:'Students')]));
  }
}
class ScanPage extends StatelessWidget {
  const ScanPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Scan book QR')),
    body:MobileScanner(onDetect:(capture){
      final code=capture.barcodes.isNotEmpty?capture.barcodes.first.rawValue:null;
      if(code!=null && code.isNotEmpty)Navigator.pop(context,code);
    }));
}

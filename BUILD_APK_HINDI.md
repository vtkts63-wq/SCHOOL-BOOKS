# Android APK बनाने का आसान तरीका (GitHub Actions)

यह Flutter source project है। APK बनाने के लिए:

1. इस project ZIP को extract करें।
2. GitHub पर नया repository बनाएं और इस folder की सभी files upload करें। Repository का नाम `pm-shri-library` रख सकते हैं।
3. GitHub repository में **Actions** tab खोलें। यदि पहली बार Actions बंद हों तो उन्हें enable करें।
4. बाईं ओर **Build Android APK** workflow चुनें और **Run workflow** दबाएं।
5. Build पूरा होने पर उसी workflow run के नीचे **Artifacts** में `PM-SHRI-Library-APK` डाउनलोड करें।
6. ZIP खोलें। अंदर `app-release.apk` मिलेगा। इसे Android फोन में install करें। जरूरत पड़ने पर Android Settings में browser/file manager के लिए “Install unknown apps” अनुमति दें।

नोट: APK install करने से पहले केवल भरोसेमंद source से बनी फाइल ही install करें। ऐप का डेटा फिलहाल उसी फोन में स्थानीय रूप से सेव होता है; कई फोन में अपने-आप sync नहीं होगा।

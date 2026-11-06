# School Library QR — Flutter Android project

## Features
- Dashboard: total, available, issued book and student counts
- Add/delete books and student records
- Unique QR code for every book
- Scan QR to issue or return a book
- Generate a printable PDF sheet of QR stickers
- Local SQLite storage on the Android device

## Build the Android app
1. Install Flutter SDK and Android Studio on a computer.
2. Extract this ZIP and open a terminal in this folder.
3. Run:
   ```bash
   flutter create . --platforms=android
   flutter pub get
   flutter run
   ```
4. To create an installable APK:
   ```bash
   flutter build apk --release
   ```
   APK: `build/app/outputs/flutter-apk/app-release.apk`

## Important
- This starter app stores data locally on one device; it does not sync between phones.
- Add student records before issuing books.
- QR codes contain only the unique book ID.
- Print QR stickers from the Dashboard.
- Use school-approved privacy and backup practices before entering real student data.

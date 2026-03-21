---
description: How to run the Backup POS Flutter app
---

# Running the App

## Prerequisites
- Flutter SDK 3.38+ installed
- Android Studio with Android SDK (for mobile)
- Chrome (for web testing)

## Steps

// turbo-all

1. Navigate to the project directory:
```bash
cd e:\Backup_POS\backup_pos
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run on Chrome (Web):
```bash
flutter run -d chrome
```

4. Run on Android Emulator:
```bash
flutter run -d android
```

5. Build Android APK:
```bash
flutter build apk --debug
```

## Notes
- First Android build takes 5-10 minutes for Gradle setup
- Barcode scanning requires real device with camera
- Web version uses manual search instead of scanning

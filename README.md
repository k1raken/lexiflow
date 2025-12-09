<div align="center">

# LexiFlow

### Learn Smarter. Remember Faster.

*A vocabulary learning app with spaced repetition, quizzes, and gamification*

[![Flutter](https://img.shields.io/badge/Flutter-3.24-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Required-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blueviolet)](#)

</div>

---

> [!IMPORTANT]
> **Portfolio Project**: This is an open-source portfolio version. The original Firebase backend has been removed. To run this app, you must set up your own Firebase project.

---

## Features

- **Spaced Repetition (SRS)** – Science-backed review scheduling
- **Categorized Word Lists** – Business, Technology, Daily English, and more
- **Multiple Quiz Types** – Multiple choice, matching, fill-in-the-blank, translation
- **Daily Streaks** – Stay motivated with streak tracking
- **Leaderboards** – Compete with weekly and all-time rankings
- **Detailed Statistics** – Track your learning progress
- **Dark/Light Theme** – Easy on the eyes
- **Smart Notifications** – Daily word reminders
- **Offline Support** – Learn without internet

---

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.24+ (Dart) |
| Backend | Firebase (Firestore, Auth, Analytics, Crashlytics) |
| State Management | Provider + GetIt |
| Local Storage | Hive + SharedPreferences |
| Ads | Google AdMob (optional) |
| UI | Material 3 + Google Fonts |

---

## Getting Started

### Prerequisites
- Flutter SDK 3.24+
- A Firebase project (free tier works)
- Android Studio / Xcode

### 1. Clone the Repository

```bash
git clone https://github.com/k1raken/lexiflow.git
cd lexiflow
flutter pub get
```

---

## Firebase Setup

> [!NOTE]
> This app requires Firebase to function. Follow these steps to connect your own Firebase project.

### Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project" and follow the wizard
3. Enable Google Analytics (recommended)

### Step 2: Add Android App

1. In Firebase Console, click "Add app" → Android
2. Package name: `com.lexiflow.app` (or your custom package)
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

### Step 3: Add iOS App (Optional)

1. In Firebase Console, click "Add app" → iOS
2. Bundle ID: `com.lexiflow.app`
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`

### Step 4: Enable Firebase Services

In Firebase Console, enable:

| Service | Location |
|---------|----------|
| **Authentication** | Build → Authentication → Sign-in method → Enable Google |
| **Firestore** | Build → Firestore Database → Create database (production mode) |
| **Analytics** | Enabled by default |
| **Crashlytics** | Release & Monitor → Crashlytics → Enable |

### Step 5: Deploy Firestore Rules

```bash
firebase login
firebase init firestore
firebase deploy --only firestore:rules
```

Or manually copy the rules from `firestore.rules` to Firebase Console → Firestore → Rules.

### Step 6: Configure AdMob (Optional)

If you want ads, update `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="YOUR_ADMOB_APP_ID" />
```

To disable ads, set `adsEnabled: false` in `lib/utils/feature_flags.dart`.

### Step 7: Create Signing Keystore (For Release)

For release builds, create your own signing keystore:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

---

## Running the App

```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

---

## Project Structure

```
lib/
├── core/           # Configuration, constants
├── models/         # Data models (Word, User, etc.)
├── screens/        # UI screens (Dashboard, Quiz, Profile)
├── services/       # Business logic (Firebase, SRS, Sync)
├── providers/      # State management (Theme, Session)
├── widgets/        # Reusable UI components
├── utils/          # Helper functions
└── main.dart       # Entry point
```

---

## Security Notes

- No API keys committed to repository
- Firebase config files are gitignored
- Firestore rules enforce per-user access
- Production-ready clean code (no debug logs)

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

---

## License

This project is licensed under the [MIT License](./LICENSE).

---

## Author

**Kiraken** — [@k1raken](https://github.com/k1raken)

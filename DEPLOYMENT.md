# DG Yard Connect – Production Build & Deployment

This guide covers building and deploying the app for **production** (Web, Android, iOS) and **Firebase** (Firestore, Functions, Storage).

---

## 1. Prerequisites

- **Flutter SDK** (stable): `flutter --version` ≥ 3.10
- **Firebase CLI**: `npm install -g firebase-tools` and `firebase login`
- **FlutterFire**: `dart pub global activate flutterfire_cli`
- **Node.js** (for Cloud Functions): `node --version` ≥ 18

---

## 2. Configure Firebase

1. Create or use an existing Firebase project at [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication** (Email/Password), **Firestore**, **Storage**, **Cloud Messaging**.
3. In project root:
   ```bash
   flutterfire configure
   ```
   This updates `lib/core/config/firebase_options.dart` for all platforms.

---

## 3. Production Builds

### Web

```bash
flutter pub get
flutter build web --release
```

Output: `build/web/` (deploy to any static host or Firebase Hosting).

### Android (APK / App Bundle)

```bash
flutter build apk --release
# or for Play Store:
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` or `build/app/outputs/bundle/release/app-release.aab`.

### iOS

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode, set signing, and archive for App Store.

---

## 4. Deploy Firebase (Backend)

From project root:

```bash
# Firestore rules + indexes
firebase deploy --only firestore

# Storage rules
firebase deploy --only storage

# Cloud Functions (builds TypeScript first via predeploy)
firebase deploy --only functions
```

Deploy everything:

```bash
firebase deploy
```

---

## 5. Deploy Web to Firebase Hosting

1. Add Hosting to the project (if not already):
   ```bash
   firebase init hosting
   ```
   Set **public directory** to `build/web` (or leave default and build into it).

2. Build and deploy:
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

Your web app URL will be `https://<project-id>.web.app` (or your custom domain).

---

## 6. Production Checklist

Before going live:

| Item | Action |
|------|--------|
| **Firebase** | `flutterfire configure` with production project; ensure Firestore/Storage rules are restrictive (not test mode). |
| **Environment** | No API keys or secrets in source; use environment config or Firebase Remote Config for optional keys. |
| **Auth** | Email/Password enabled; consider adding phone or OAuth if required. |
| **Functions** | All callables/triggers deployed; set Node runtime (e.g. 18) in `functions/package.json` engines. |
| **Payments** | Replace `lockJobPayment` stub with real Razorpay (or gateway) verification; technician payout via Razorpay or bank. |
| **Notifications** | Wire Twilio/SendGrid/WhatsApp in `sendOtp` and `sendJobCompleteNotifications` for SMS/Email/WhatsApp. |
| **Masked call** | Wire Twilio Voice in `initMaskedCall` so technician never sees customer number. |
| **Version** | Bump `version` in `pubspec.yaml` (e.g. `1.0.0+1` → `1.0.1+2`) for each release. |
| **Testing** | Run `flutter test` and manual smoke tests on Web/Android/iOS. |

---

## 7. Quick Commands Summary

```bash
# Development
flutter pub get
flutter run -d chrome

# Production build
flutter build web --release
flutter build apk --release

# Deploy backend
firebase deploy --only firestore,storage,functions

# Deploy web app
flutter build web --release && firebase deploy --only hosting
```

- **Super Admin login and database (step-by-step):** [SUPER_ADMIN_AND_DATABASE_SETUP.md](SUPER_ADMIN_AND_DATABASE_SETUP.md)  
- **Firebase connect and first run:** [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md)  
- **Razorpay, Twilio, SendGrid, WhatsApp:** [EXTERNAL_INTEGRATIONS.md](EXTERNAL_INTEGRATIONS.md)

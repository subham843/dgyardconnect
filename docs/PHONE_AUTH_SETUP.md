# Phone Auth (OTP) Setup – Fix "missing valid app identifier" / Play Integrity

If users see **"Failed to send OTP"** with Play Integrity or reCAPTCHA errors, the Android app is not correctly linked to Firebase for Phone Authentication.

## Why does the browser open during OTP login?

Firebase Phone Auth on Android can use either **Play Integrity** (in-app, no browser) or **reCAPTCHA** (opens Chrome/WebView). If your app’s SHA-1/SHA-256 are **not** added in Firebase and **Play Integrity API** is not enabled, Firebase falls back to reCAPTCHA, which opens a browser for verification.

**To keep verification in-app (no browser):** complete **all** steps below: add SHA-1/SHA-256 in Firebase, update `google-services.json`, and enable **Play Integrity API** in Google Cloud. Use a real device or an emulator with Google Play.

## Custom OTP (e.g. Teillo / SMS gateway) instead of Firebase SMS

If you want login OTP to be sent via your own provider (e.g. Teillo, MSG91, Twilio), you cannot use Firebase’s built-in “send OTP” flow as-is. You need a **backend** that:

1. Sends the OTP via your provider (e.g. Teillo).
2. Verifies the code entered by the user.
3. Creates a **custom token** with Firebase Admin SDK and returns it to the app.
4. The app signs in with `FirebaseAuth.instance.signInWithCustomToken(customToken)`.

The current app uses Firebase’s `verifyPhoneNumber` and SMS; switching to Teillo-only OTP would require implementing the above backend and changing the app to call your API and then `signInWithCustomToken`.

## Fix steps

### 1. Get your app’s SHA-1 and SHA-256

**Debug build (development):**
```bash
cd android
./gradlew signingReport
```
Under **Variant: debug**, copy the **SHA-1** and **SHA-256** values.

**Release build:** Use the keystore you use for Play Store and run the same command with the release keystore, or get SHA from Play Console (Release > Setup > App signing).

### 2. Add fingerprints in Firebase

1. Open [Firebase Console](https://console.firebase.google.com) → your project.
2. Go to **Project settings** (gear) → **Your apps**.
3. Select your **Android app** (package name e.g. `com.example.dgyardconnect`).
4. Click **Add fingerprint** and add:
   - **SHA-1** (debug and release)
   - **SHA-256** (debug and release)
5. Save.

### 3. Update `google-services.json`

- In Firebase, download the latest **google-services.json** (Project settings → Your apps → Download).
- Replace `android/app/google-services.json` with this file.

### 4. Enable Phone Authentication

- In Firebase Console: **Build → Authentication → Sign-in method**.
- Enable **Phone** provider.

### 5. (Recommended) Play Integrity API – avoids browser/reCAPTCHA

- In [Google Cloud Console](https://console.cloud.google.com), select the same project as Firebase.
- **APIs & Services → Library** → search **Play Integrity API** → Enable.
- This helps keep verification in-app so the browser does not open for reCAPTCHA.

### 6. Rebuild the app

```bash
flutter clean
flutter pub get
flutter run
```

Use a **real device** or an emulator with **Google Play** (not a plain AOSP image) for testing. After adding the correct SHA-1/SHA-256 and updating `google-services.json`, OTP should work.

---

## Browser still opens for reCAPTCHA?

If you completed all steps and the **browser still opens** during OTP send:

1. **Device**: Use a **physical Android device** with **Google Play Services**. Many emulators (e.g. without Play Store) always fall back to reCAPTCHA and will open the browser.
2. **Wait**: After adding SHA and enabling Play Integrity, it can take **some time** (up to an hour) for Google to start using in-app verification.
3. **Check package name**: In Firebase → Project settings → Your apps, the Android app’s package name must **exactly match** the one in `android/app/build.gradle` (`applicationId`).
4. **Debug**: In Android Studio / Logcat, filter by `PhoneAuth` or `FirebaseAuth` to see whether Play Integrity or reCAPTCHA is being used.

There is **no in-app-only option** in Firebase Phone Auth: if Play Integrity is not used, the SDK will open the system browser for reCAPTCHA. To avoid the browser entirely, use a **real device with Play Services** and correct SHA + Play Integrity setup.

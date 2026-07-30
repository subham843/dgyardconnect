# Notification Setup (FCM) — Push Notifications

Is guide mein bataya gaya hai ki **push notifications** (FCM) ke liye kya setup karna hoga taaki approval, job request, etc. sahi se bheje aur receive ho sakein.

---

## 1. Kaun si notifications bheji jaati hain

- **Registration approval / rejection** — Jab Super Admin dealer/technician approve ya reject kare, us user ko notification.
- **Job request (technician)** — Jab naya job create ho, roll ke hisaab se technician ko notification.

Yeh sab **Firebase Cloud Functions** se bheji jaati hain. Notification tabhi bhej sakte hain jab user ke Firestore document (`users/{uid}`) mein **`fcmToken`** save ho.

---

## 2. FCM token kab save hota hai

App automatically FCM token save karti hai in cases mein:

| Jab | Kahan save hota hai |
|-----|----------------------|
| User **login** karta hai | `users/{uid}.fcmToken` |
| User app open karta hai (already logged in) | **Splash** screen par `fcmToken` save |
| User **register** karke **Pending approval** screen par aata hai | **Pending approval** screen load hote hi `fcmToken` save |

**Zaroori:** Notification tabhi jayegi jab user ne app **kam se kam ek baar** open kiya ho (login / splash / pending approval) taaki token Firestore mein aa chuka ho. Agar user ne kabhi app open hi nahi kiya, `fcmToken` nahi hoga aur notification nahi bheji ja sakti.

---

## 3. Firebase Console

1. [Firebase Console](https://console.firebase.google.com/) → apna project select karo.
2. **Project Settings** (gear icon) → **Cloud Messaging** tab.
3. **Cloud Messaging API (Legacy)** agar disabled hai to enable mat karo — naya FCM (HTTP v1) use hota hai; Firebase Admin SDK isi se bhejta hai.
4. **Apple app** (iOS) ke liye **APNs Authentication Key** ya **APNs Certificates** upload karne honge (step 5 dekho).

Koi alag “enable FCM” button nahi hota; project create karte hi FCM available rehta hai.

---

## 4. Android Setup

1. **google-services.json**  
   - `flutterfire configure` chalao (ya Firebase Console se Android app add karke `google-services.json` download karo).  
   - File `android/app/google-services.json` mein honi chahiye.  
   - Project mein pehle se `com.google.gms.google-services` plugin use ho raha hai.

2. **Minimum SDK**  
   - FCM ke liye generally `minSdk 21` kaafi hai. Agar `minSdk` aur bhi niche hai to build/run time check karo.

3. **Run / Test**  
   - Device ya emulator par app run karo, login (ya pending approval) tak jao — isi se token save hoga.  
   - Notification receive karne ke liye app background ya kill bhi ho sakti hai; system notification dikhayega.

Koi extra FCM-related key Android app code mein add karne ki zaroorat nahi; backend (Cloud Functions) Firebase default credentials use karta hai.

---

## 5. iOS Setup

1. **Xcode** mein project kholo:  
   `open ios/Runner.xcworkspace`

2. **Push Notifications capability**  
   - **Signing & Capabilities** → **+ Capability** → **Push Notifications** add karo.

3. **APNs key Firebase ko do**  
   - [Apple Developer](https://developer.apple.com/account/) → **Keys** → nayi key banao, **Apple Push Notifications service (APNs)** enable karo. Key download karo (.p8).  
   - **Firebase Console** → Project → **Project Settings** → **Cloud Messaging** → **Apple app configuration** → **APNs Authentication Key** upload karo (Key ID, Team ID, Bundle ID, .p8 file).

4. **Run on device**  
   - Simulator par push notifications nahi aati; **real device** par run karke test karo.  
   - Ek baar app open karo (login / splash / pending approval) taaki `fcmToken` save ho.

---

## 6. Web Setup

1. **HTTPS**  
   - FCM web ke liye **HTTPS** zaroori hai. `localhost` development ke liye allow hai.

2. **Service worker**  
   - `web/firebase-messaging-sw.js` already hai.  
   - Isme Firebase config (apiKey, projectId, messagingSenderId, appId, etc.) FlutterFire / Firebase Console se match hona chahiye.  
   - Agar project change kiya hai to `flutterfire configure` dubara chalao aur agar web ke liye config alag copy karte ho to `firebase-messaging-sw.js` bhi update karo.

3. **Permission**  
   - Pehli baar app pe user ko **notification allow** karne ka prompt aata hai. Allow karna zaroori hai.

4. **Token save**  
   - Web par bhi login / splash / pending approval se token save hota hai. Agar service worker load nahi hota (e.g. path galat) to token null ho sakta hai — browser console aur Network tab check karo.

---

## 7. Cloud Functions (Backend)

- Notifications **Cloud Functions** se bheji jaati hain (`admin.messaging()`).
- Koi alag FCM server key ya config set karne ki zaroorat nahi; Firebase Admin SDK project ki default credentials use karta hai.

**Deploy:**

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

Jin functions se notification jati hai (e.g. `onUserApprovalChanged`, `onJobCreated`), woh deploy hone chahiye. Firebase Console → **Functions** se logs dekh sakte ho.

---

## 8. Troubleshooting

| Problem | Check |
|--------|--------|
| Notification aati hi nahi | 1. User ne app open karke login / splash / pending approval dekha? (token save hona chahiye)<br>2. Firestore `users/{uid}` mein `fcmToken` field hai? |
| Android par nahi aa rahi | 1. `google-services.json` sahi jagah hai?<br>2. Device/emulator par app run kiya?<br>3. Functions deploy hue? Logs mein error to nahi? |
| iOS par nahi aa rahi | 1. Push Notifications capability add ki?<br>2. APNs key Firebase mein upload ki?<br>3. Real device par test kiya? (simulator par push nahi chalti) |
| Web par nahi aa rahi | 1. HTTPS use ho raha hai?<br>2. `firebase-messaging-sw.js` sahi path pe serve ho raha hai?<br>3. Notification permission allow ki? |
| “User approval changed but no FCM token” (Functions log) | User ke document mein `fcmToken` nahi hai. User ko ek baar app open karke login / pending approval screen tak aana hoga. |

---

## 9. Short checklist

- [ ] Firebase project create, Flutter app link (`flutterfire configure`).
- [ ] Android: `google-services.json` in `android/app/`.
- [ ] iOS: Push Notifications capability + APNs key Firebase Console mein.
- [ ] Web: `web/firebase-messaging-sw.js` sahi config ke sath.
- [ ] Cloud Functions deploy: `firebase deploy --only functions`.
- [ ] Test: User se app open karwao (login / pending approval) → Firestore `users/{uid}` mein `fcmToken` dikhna chahiye → phir approval/job test karo.

Is setup ke baad notifications bhejne aur receive karne dono ka flow kaam karna chahiye. Agar koi specific platform (Android/iOS/Web) par abhi bhi issue ho to us platform ka section aur Troubleshooting table use karo.

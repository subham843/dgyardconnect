# Firebase Setup & Super Admin Guide

**DG Yard Connect** — Firebase connect karne aur **Super Admin** user banane ka step-by-step guide.

---

## Part 1: Firebase Project Setup (Console)

### Step 1: Firebase project banao

1. Browser mein jao: **[Firebase Console](https://console.firebase.google.com/)**
2. **"Add project"** / **"Create a project"** par click karo.
3. Project name daalo (e.g. `dgyardconnect`).
4. Google Analytics optional — chaaho to enable karo, skip bhi kar sakte ho.
5. **Create project** → project ready.

### Step 2: App platform add karo (Android / iOS / Web)

- **Android**: Project Overview → **Add app** → Android icon → package name `com.example.dgyardconnect` (ya jo `android/app/build.gradle` mein hai) daalo → Register.
- **iOS**: iOS icon → Bundle ID daalo → Register.
- **Web**: Web icon (</>) → App nickname daalo → **Register app** → Firebase config object copy karo (baad mein FlutterFire use karega, isliye zaroori nahi).

### Step 3: Authentication enable karo

1. Left menu → **Build** → **Authentication**.
2. **Get started**.
3. **Sign-in method** tab → **Email/Password** → Enable → **Save**.

### Step 4: Firestore Database create karo

1. Left menu → **Build** → **Firestore Database**.
2. **Create database** → **Start in test mode** (development) ya **production mode** (rules baad mein deploy karenge).
3. Location choose karo (e.g. `asia-south1`) → **Enable**.

### Step 5: Storage enable karo (optional, KYC/docs ke liye)

1. **Build** → **Storage** → **Get started**.
2. Start in test/production mode → location same rakh sakte ho → **Done**.

---

## Part 2: Flutter app ko Firebase se connect karna

### Step 1: Firebase CLI install karo

```bash
npm install -g firebase-tools
```

Login karo:

```bash
firebase login
```

### Step 2: FlutterFire CLI install karo

```bash
dart pub global activate flutterfire_cli
```

`dart` / `flutter` PATH mein hona chahiye.

### Step 3: Project root mein Firebase init (pehli baar)

Agar project root par `firebase.json` nahi hai to pehle init karo:

```bash
cd e:\dgyardconnect
firebase init
```

- **Firestore**: rules aur indexes ke liye — existing `firebase/` folder use karna (agar pooche to "Use an existing project").
- **Functions** select karo agar Cloud Functions deploy karni hon.
- Project select karo: jo Firebase project abhi banaya (e.g. `dgyardconnect`).

Agar `firebase.json` pehle se hai to sirf FlutterFire configure karo (Step 4).

### Step 4: FlutterFire configure (important)

Yeh command Flutter app ko Firebase project se link karega aur `lib/core/config/firebase_options.dart` generate karega.

**Pehle FlutterFire CLI install karo** (sirf ek baar):

```bash
dart pub global activate flutterfire_cli
```

**Windows par agar `flutterfire` command nahi chale** (e.g. "flutterfire is not recognized"):

- **Option A:** Pub cache `bin` folder ko PATH mein add karo:
  - Path: `C:\Users\<YourUsername>\AppData\Local\Pub\Cache\bin`
  - Windows: Settings → System → About → Advanced system settings → Environment Variables → User variables → Path → Edit → New → paste the path → OK.
- **Option B:** Bina PATH change kiye run karo:
  ```powershell
  dart pub global run flutterfire_cli:flutterfire configure
  ```

**Configure chalao:**

```bash
cd e:\dgyardconnect
flutterfire configure
```

Ya specific project ke liye (project ID exact hona chahiye — Firebase Console → Project settings mein dekho):

```bash
flutterfire configure --project=YOUR_PROJECT_ID
```

- Firebase project select karo (ya `--project=...` se specify karo). **Project ID** Firebase Console → ⚙ Project settings → "Project ID" — ye exact use karo (e.g. `dgyardconnect` ya `dgyard-connect`; agar "not found" aaye to Console mein jo ID dikhe wahi use karo).
- Platforms (Android, iOS, Web) jo chahiye select karo.
- Complete hone par `firebase_options.dart` update ho jayega.

### Step 5: App run karo

```bash
flutter pub get
flutter run -d chrome
```

Ya Android/iOS device/emulator:

```bash
flutter run
```

Ab app Firebase se connect hogi; login/register Firestore + Auth use karenge.

---

## Part 3: Super Admin ID / Password — Kaise banayein

App mein **koi default Super Admin ID/password nahi hota**. Super Admin = **Firebase Auth** user + **Firestore** `users/{uid}` document jisme `role: 'superadmin'` aur `approved: true` ho.

### Option A: Firebase Console se manually (sabse simple)

#### 1. Auth user banao

1. Firebase Console → **Authentication** → **Users**.
2. **Add user** → Email aur Password daalo (e.g. `superadmin@dgyardconnect.com`, strong password).
3. **Add user** → user create ho jayega.
4. **User UID** copy karo (wahi `users` collection mein document id hogi).

#### 2. Firestore mein Super Admin document banao

1. **Firestore Database** → **Start collection** (agar `users` nahi hai) ya **users** collection open karo.
2. **Add document** (ya **users** ke andar).
   - **Document ID**: jo **UID** copy kiya (Auth user ka), wahi daalo.
3. Fields add karo:

| Field         | Type    | Value              |
|---------------|---------|--------------------|
| `email`       | string  | same email (e.g. superadmin@dgyardconnect.com) |
| `role`        | string  | **superadmin**     |
| `approved`    | boolean | **true**           |
| `createdAt`   | timestamp | (optional) current time |

4. **Save**.

Ab isi **email** aur **password** se app mein login karo → Super Admin ki tarah **Admin Home** par redirect hoga.

**Example:**  
- Email: `superadmin@dgyardconnect.com`  
- Password: jo aapne Auth mein set kiya (e.g. `Admin@123`)

---

### Option B: Seed script se (advanced — Node.js + Service Account)

Agar aap script se Super Admin create karna chahte ho (e.g. CI/deployment ke liye):

1. Firebase Console → Project **Settings** (gear) → **Service accounts** → **Generate new private key** → JSON file save karo (e.g. `serviceAccountKey.json`). **Is file ko git mein commit mat karo.**
2. Project mein `scripts/` folder use karke ek script chalao jo Firebase Admin SDK se:
   - Auth mein user create kare (email/password),
   - Firestore `users/{uid}` document create kare with `role: 'superadmin'`, `approved: true`, `email`.

Script example ke liye `scripts/README_SEED_SUPERADMIN.md` dekho (agar add kiya gaya ho).

---

## Part 4: Firestore Rules deploy karna

Project ke Firestore rules `firebase/firestore.rules` mein hain. Deploy karne ke liye:

```bash
cd e:\dgyardconnect
firebase deploy --only firestore:rules
```

Indexes deploy:

```bash
firebase deploy --only firestore:indexes
```

Storage rules:

```bash
firebase deploy --only storage
```

---

## Part 5: Cloud Functions (optional)

Functions deploy karne ke liye:

```bash
cd e:\dgyardconnect\functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

---

## Summary checklist

| Step | Task | Done |
|------|------|------|
| 1 | Firebase project create | ☐ |
| 2 | Auth (Email/Password) enable | ☐ |
| 3 | Firestore create | ☐ |
| 4 | `firebase login` + `flutterfire configure` | ☐ |
| 5 | Super Admin: Auth user + Firestore `users/{uid}` (role: superadmin, approved: true) | ☐ |
| 6 | App run: `flutter run` | ☐ |
| 7 | (Optional) Rules deploy: `firebase deploy --only firestore:rules` | ☐ |

---

## Super Admin login — short answer

- **Default ID/Password**: App mein koi default nahi hai.
- **Banane ka tareeka**:  
  - Firebase Console → Authentication → Add user (email + password).  
  - Firestore → `users` → Document ID = that user’s **UID** → fields: `email`, `role: "superadmin"`, `approved: true`.  
- **Login**: App mein wahi email/password use karo → Admin Home open hoga.

Agar koi step fail ho ya error aaye to error message share karo, us hisaab se exact step bata sakta hoon.

# Super Admin Seed Script (Optional)

Super Admin create karne ka **manual tareeka** sabse aasaan hai — [FIREBASE_SETUP_GUIDE.md](../FIREBASE_SETUP_GUIDE.md) mein **Part 3 – Option A** dekho.

Agar aap **script** se Super Admin banana chahte ho (e.g. deployment/CI ke liye), ye steps follow karo.

## Zaroorat

- Node.js 18+
- Firebase project ka **Service Account** key (JSON file)

## Service Account key kaise lo

1. [Firebase Console](https://console.firebase.google.com/) → apna project
2. **Project settings** (gear) → **Service accounts**
3. **Generate new private key** → JSON download karo
4. Is file ko safe rakhho aur **git mein commit mat karo** (e.g. `serviceAccountKey.json` project root ke bahar)

## Script chalana

```bash
cd e:\dgyardconnect\scripts
npm install
```

**Environment se email/password:**

```bash
set GOOGLE_APPLICATION_CREDENTIALS=E:\path\to\serviceAccountKey.json
set SUPERADMIN_EMAIL=superadmin@dgyardconnect.com
set SUPERADMIN_PASSWORD=YourSecurePassword123
node seed_super_admin.js
```

**Ya command-line arguments (key path, email, password):**

```bash
node seed_super_admin.js E:\path\to\serviceAccountKey.json superadmin@dgyardconnect.com YourSecurePassword123
```

Script ye karega:

1. Firebase Auth mein user create (email/password)
2. Firestore `users/{uid}` document create with `role: 'superadmin'`, `approved: true`, `email`

Uske baad app mein isi email/password se login karo → Admin Home open hoga.

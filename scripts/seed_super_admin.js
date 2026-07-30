/**
 * Creates a Super Admin user in Firebase Auth and Firestore.
 * Usage:
 *   Set env: GOOGLE_APPLICATION_CREDENTIALS, SUPERADMIN_EMAIL, SUPERADMIN_PASSWORD
 *   Or: node seed_super_admin.js <path-to-service-account.json> <email> <password>
 */
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || process.argv[2];
const email = process.env.SUPERADMIN_EMAIL || process.argv[3];
const password = process.env.SUPERADMIN_PASSWORD || process.argv[4];

if (!keyPath || !email || !password) {
  console.error('Usage: set GOOGLE_APPLICATION_CREDENTIALS, SUPERADMIN_EMAIL, SUPERADMIN_PASSWORD');
  console.error('   Or: node seed_super_admin.js <serviceAccountKey.json> <email> <password>');
  process.exit(1);
}

const key = JSON.parse(fs.readFileSync(path.resolve(keyPath), 'utf8'));

async function main() {
  const app = admin.initializeApp({ credential: admin.credential.cert(key) });
  const auth = admin.auth(app);
  const db = admin.firestore(app);

  let user;
  try {
    user = await auth.createUser({ email, password, emailVerified: true });
    console.log('Auth user created:', user.uid);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      user = await auth.getUserByEmail(email);
      console.log('Auth user already exists:', user.uid);
    } else throw e;
  }

  const userRef = db.collection('users').doc(user.uid);
  await userRef.set({
    email,
    role: 'superadmin',
    approved: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('Firestore users/%s updated with role superadmin, approved true.', user.uid);
  console.log('Done. Login with:', email);
}

main().catch((e) => { console.error(e); process.exit(1); });

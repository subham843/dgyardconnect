/**
 * Set Firestore users/{uid}.role by phone number (Firebase Auth + Firestore).
 *
 * PowerShell:
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "E:\path\to\serviceAccountKey.json"
 *   node set_user_role_by_phone.js 7004582230 user
 *   node set_user_role_by_phone.js 8298955009 superadmin
 *
 * Or pass key path as first argument:
 *   node set_user_role_by_phone.js "E:\path\to\serviceAccountKey.json" 7004582230 user
 *
 * CMD:
 *   set GOOGLE_APPLICATION_CREDENTIALS=E:\path\to\serviceAccountKey.json
 *   node set_user_role_by_phone.js 7004582230 user
 *
 * Roles: superadmin | dealer | technician | user (clears role field)
 */
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const allowedRoles = new Set(['superadmin', 'dealer', 'technician', 'user']);

function looksLikeKeyPath(arg) {
  if (!arg || typeof arg !== 'string') return false;
  if (arg.endsWith('.json')) return true;
  try {
    return fs.existsSync(path.resolve(arg));
  } catch (_) {
    return false;
  }
}

function parseArgs() {
  const envKey = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const a2 = process.argv[2];
  const a3 = process.argv[3];
  const a4 = process.argv[4];

  if (envKey) {
    return {
      keyPath: envKey,
      phoneArg: process.env.PHONE || a2,
      roleArg: (process.env.ROLE || a3 || 'user').toLowerCase(),
    };
  }
  if (looksLikeKeyPath(a2)) {
    return {
      keyPath: a2,
      phoneArg: process.env.PHONE || a3,
      roleArg: (process.env.ROLE || a4 || 'user').toLowerCase(),
    };
  }
  return {
    keyPath: null,
    phoneArg: process.env.PHONE || a2,
    roleArg: (process.env.ROLE || a3 || 'user').toLowerCase(),
  };
}

const { keyPath, phoneArg, roleArg } = parseArgs();

function normalizePhone(raw) {
  const digits = String(raw).replace(/\D/g, '');
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  if (String(raw).startsWith('+')) return String(raw);
  throw new Error(`Invalid phone: ${raw}`);
}

async function findAuthUserByPhone(auth, phone) {
  let pageToken;
  do {
    const res = await auth.listUsers(1000, pageToken);
    for (const u of res.users) {
      if (u.phoneNumber === phone) return u;
    }
    pageToken = res.pageToken;
  } while (pageToken);
  return null;
}

async function main() {
  if (!keyPath || !phoneArg) {
    console.error('Usage: node set_user_role_by_phone.js <serviceAccount.json> <phone> [role]');
    console.error('   Or: set GOOGLE_APPLICATION_CREDENTIALS, PHONE, ROLE then run script');
    process.exit(1);
  }
  if (!allowedRoles.has(roleArg)) {
    console.error(`Invalid role "${roleArg}". Use: ${[...allowedRoles].join(', ')}`);
    process.exit(1);
  }

  const resolvedKeyPath = path.resolve(keyPath);
  if (!fs.existsSync(resolvedKeyPath)) {
    console.error(`Service account key not found: ${resolvedKeyPath}`);
    console.error('');
    console.error('PowerShell example:');
    console.error('  $env:GOOGLE_APPLICATION_CREDENTIALS = "E:\\path\\to\\serviceAccountKey.json"');
    console.error('  node set_user_role_by_phone.js 7004582230 user');
    console.error('');
    console.error('Or pass the JSON path as the first argument (do not use %VAR% — that is CMD only).');
    process.exit(1);
  }

  const key = JSON.parse(fs.readFileSync(resolvedKeyPath, 'utf8'));
  const app = admin.initializeApp({ credential: admin.credential.cert(key) });
  const auth = admin.auth(app);
  const db = admin.firestore(app);

  const phone = normalizePhone(phoneArg);
  const user = await findAuthUserByPhone(auth, phone);
  if (!user) {
    console.error(`No Firebase Auth user found for ${phone}. User must sign in once via OTP first.`);
    process.exit(1);
  }

  const ref = db.collection('users').doc(user.uid);
  const snap = await ref.get();
  const patch = {
    phone,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (roleArg === 'user') {
    patch.role = admin.firestore.FieldValue.delete();
    patch.approved = false;
  } else {
    patch.role = roleArg;
    patch.approved = roleArg === 'superadmin';
  }

  if (snap.exists) {
    await ref.update(patch);
  } else {
    await ref.set({
      ...patch,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  console.log('Updated Firestore users/%s', user.uid);
  console.log('  phone:', phone);
  console.log('  role:', roleArg === 'user' ? '(none — regular user flow)' : roleArg);

  const supabaseUrl = process.env.SUPABASE_URL || 'https://xtnfmrourhzspehvhrkz.supabase.co';
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const mirror = roleArg === 'superadmin' ? 'superadmin' : 'user';
  if (serviceKey) {
    try {
      const res = await fetch(`${supabaseUrl}/rest/v1/platform_users?firebase_uid=eq.${user.uid}`, {
        method: 'PATCH',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({ role_mirror: mirror, phone, last_seen_at: new Date().toISOString() }),
      });
      if (res.ok) {
        console.log('Updated Supabase platform_users.role_mirror =', mirror);
      } else {
        console.warn('Supabase update failed:', res.status, await res.text());
      }
    } catch (e) {
      console.warn('Supabase update error:', e.message);
    }
  } else {
    console.log('');
    console.log('Supabase: set SUPABASE_SERVICE_ROLE_KEY to also fix platform_users.role_mirror');
    console.log(`  firebase_uid = ${user.uid}`);
    console.log(`  role_mirror = ${mirror}`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

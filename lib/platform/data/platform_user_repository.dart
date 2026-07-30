import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/supabase/supabase_auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../shared/services/firestore_service.dart';

/// Ensures [platform_users] row exists in Supabase after Firebase login.
class PlatformUserRepository {
  PlatformUserRepository._();
  static final PlatformUserRepository instance = PlatformUserRepository._();

  Future<bool> ensureProvisioned({String? firebaseUid}) async {
    if (!SupabaseBootstrap.isInitialized) return false;
    final uid = firebaseUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    String? phone;
    String? displayName;
    var roleMirror = 'user';

    if (FirestoreService.isAvailable) {
      try {
        final doc = await FirestoreService.users().doc(uid).get();
        final d = doc.data();
        if (d != null) {
          phone = (d['phone'] as String?) ?? (d['profile'] as Map?)?['phone'] as String?;
          displayName = (d['profile'] as Map?)?['name'] as String? ?? d['displayName'] as String?;
          if (d['role'] == 'superadmin') roleMirror = 'superadmin';
        }
      } catch (e) {
        debugPrint('PlatformUserRepository Firestore read: $e');
      }
    }

    await SupabaseAuthService.instance.rememberRoleMirror(roleMirror);

    final ok = await SupabaseAuthService.instance.syncSessionFromFirebase(
      roleMirror: roleMirror,
      forceRefresh: true,
    );
    if (!ok) return false;

    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return false;

    try {
      await client.from('platform_users').upsert({
        'firebase_uid': uid,
        'phone': phone,
        'display_name': displayName,
        'role_mirror': roleMirror,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'firebase_uid');
      return true;
    } catch (e) {
      debugPrint('PlatformUserRepository upsert: $e');
      return false;
    }
  }
}

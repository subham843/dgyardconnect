import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/firestore_safe_reads.dart';
import '../../shared/services/firestore_service.dart';
import 'supabase_bootstrap.dart';
import 'supabase_config.dart';

/// Exchanges Firebase ID token for Supabase JWT (app_role drives shop admin RLS).
class SupabaseAuthService {
  SupabaseAuthService._();
  static final SupabaseAuthService instance = SupabaseAuthService._();

  static const _prefsRoleKey = 'dgyard_supabase_app_role';
  static const _prefsBosTenantKey = 'bos_active_tenant_id';

  String? _cachedToken;
  DateTime? _tokenExpiry;
  String? _cachedRoleMirror;
  String? _cachedBosTenantId;
  String? _cachedBosRole;

  String? get accessToken => _cachedToken;

  bool get currentJwtIsSuperadmin => jwtAppRole(_cachedToken) == 'superadmin';

  /// Active BOS tenant from last exchange (JWT claim / prefs).
  String? get activeBosTenantId =>
      _cachedBosTenantId ?? jwtBosTenantId(_cachedToken);

  /// BOS member role from last exchange (owner/admin/sales/agent/viewer).
  String? get activeBosRole => _cachedBosRole ?? jwtBosRole(_cachedToken);

  /// Set after login so shop/calculator Supabase calls keep superadmin RLS on web.
  Future<void> rememberRoleMirror(String role) async {
    final r = role.trim();
    if (r != 'superadmin') {
      await clearRoleMirror();
      return;
    }
    _cachedRoleMirror = r;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsRoleKey, r);
    } catch (_) {}
  }

  Future<void> clearRoleMirror() async {
    _cachedRoleMirror = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsRoleKey);
    } catch (_) {}
  }

  /// Set active BOS tenant ID and force token refresh.
  Future<void> setActiveBosTenant(String tenantId) async {
    _cachedBosTenantId = tenantId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsBosTenantKey, tenantId);
    } catch (_) {}
    await syncSessionFromFirebase(forceRefresh: true);
  }

  Future<String?> _persistedBosTenantId() async {
    if (_cachedBosTenantId != null && _cachedBosTenantId!.isNotEmpty) return _cachedBosTenantId;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsBosTenantKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _persistedRoleMirror() async {
    if (_cachedRoleMirror != null && _cachedRoleMirror!.isNotEmpty) return _cachedRoleMirror;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsRoleKey);
    } catch (_) {
      return null;
    }
  }

  bool get hasValidSession {
    if (!SupabaseBootstrap.isInitialized) return false;
    if (_cachedToken == null) return false;
    if (_tokenExpiry == null) return false;
    return _tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }

  /// Decode a claim from our exchange JWT payload.
  static String? jwtClaim(String? token, String claim) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      final pad = payload.length % 4;
      if (pad > 0) payload += '=' * (4 - pad);
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final map = jsonDecode(utf8.decode(base64.decode(normalized))) as Map<String, dynamic>;
      final v = map[claim];
      return v?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Decode app_role from our exchange JWT (not the Postgres role claim).
  static String? jwtAppRole(String? token) => jwtClaim(token, 'app_role');

  static String? jwtBosTenantId(String? token) => jwtClaim(token, 'bos_tenant_id');

  static String? jwtBosRole(String? token) => jwtClaim(token, 'bos_role');

  Future<String> _resolveDesiredRole(String? roleMirror) async {
    if (roleMirror != null && roleMirror.trim().isNotEmpty) {
      return roleMirror.trim() == 'superadmin' ? 'superadmin' : 'user';
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      if (!kIsWeb && FirestoreService.isAvailable) {
        try {
          final doc = await FirestoreService.users().doc(uid).get();
          if (doc.data()?['role'] == 'superadmin') return 'superadmin';
        } catch (_) {}
      } else if (kIsWeb && FirestoreService.isAvailable) {
        try {
          final doc = await safeGetUserDocument(uid, timeout: const Duration(seconds: 4));
          if (doc?.data()?['role'] == 'superadmin') return 'superadmin';
        } catch (_) {}
      }

      // role_mirror from platform_users (readable with user JWT).
      try {
        final client = SupabaseBootstrap.clientOrNull;
        if (client != null) {
          final row = await client
              .from('platform_users')
              .select('role_mirror')
              .eq('firebase_uid', uid)
              .maybeSingle();
          if (row?['role_mirror'] == 'superadmin') {
            // Only trust Supabase superadmin when Firestore also says superadmin.
            if (!kIsWeb && FirestoreService.isAvailable) {
              try {
                final doc = await FirestoreService.users().doc(uid).get();
                if (doc.data()?['role'] == 'superadmin') return 'superadmin';
              } catch (_) {}
            } else if (kIsWeb && FirestoreService.isAvailable) {
              try {
                final doc = await safeGetUserDocument(uid, timeout: const Duration(seconds: 4));
                if (doc?.data()?['role'] == 'superadmin') return 'superadmin';
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }

    final persisted = await _persistedRoleMirror();
    if (persisted == 'superadmin') return 'superadmin';

    return 'user';
  }

  /// Re-exchange if JWT app_role does not match desired role (fixes web hot restart).
  Future<bool> syncSessionFromFirebase({String? roleMirror, bool forceRefresh = false}) async {
    if (!SupabaseBootstrap.isInitialized) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final desiredRole = await _resolveDesiredRole(roleMirror);
    final desiredTenant = await _persistedBosTenantId();

    if (!forceRefresh && hasValidSession && _cachedToken != null) {
      final tokenRole = jwtAppRole(_cachedToken);
      final tokenTenant = jwtBosTenantId(_cachedToken);
      final roleOk = tokenRole == desiredRole;
      final tenantOk = desiredTenant == null ||
          desiredTenant.isEmpty ||
          tokenTenant == desiredTenant;
      if (roleOk && tenantOk) {
        _cachedBosRole ??= jwtBosRole(_cachedToken);
        _cachedBosTenantId ??= tokenTenant;
        return true;
      }
      debugPrint(
        'SupabaseAuthService: re-exchange '
        '(role $tokenRole→$desiredRole, tenant $tokenTenant→$desiredTenant)',
      );
      _cachedToken = null;
      _tokenExpiry = null;
    } else if (forceRefresh) {
      _cachedToken = null;
      _tokenExpiry = null;
    } else if (hasValidSession) {
      return true;
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return false;

    final url = SupabaseConfig.exchangeTokenUrl;
    if (url.isEmpty) {
      debugPrint('SupabaseAuthService: exchange URL not configured');
      return false;
    }

    try {
      final bosTenantId = await _persistedBosTenantId();
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'roleMirror': desiredRole,
          'bosTenantId': ?bosTenantId,
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('Supabase token exchange failed: ${res.statusCode} ${res.body}');
        return false;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final accessToken = body['access_token'] as String?;
      final firebaseUid = body['firebase_uid'] as String? ?? '';
      final exchangedRole = body['role'] as String? ?? desiredRole;
      final returnedBosTenant = body['bos_tenant_id'] as String?;
      final returnedBosRole = body['bos_role'] as String?;
      if (returnedBosRole != null && returnedBosRole.isNotEmpty) {
        _cachedBosRole = returnedBosRole;
      } else {
        _cachedBosRole = jwtBosRole(accessToken);
      }
      if (returnedBosTenant != null && returnedBosTenant.isNotEmpty) {
        _cachedBosTenantId = returnedBosTenant;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsBosTenantKey, returnedBosTenant);
        } catch (_) {}
      } else if (accessToken != null) {
        _cachedBosTenantId ??= jwtBosTenantId(accessToken);
      }
      if (accessToken == null || accessToken.isEmpty) return false;

      final client = SupabaseBootstrap.clientOrNull;
      if (client == null) return false;

      try {
        await client.auth.setSession(accessToken);
      } catch (_) {
        await client.auth.recoverSession(
          jsonEncode({
            'access_token': accessToken,
            'refresh_token': accessToken,
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {'id': firebaseUid, 'role': 'authenticated', 'app_role': exchangedRole},
          }),
        );
      }
      _cachedToken = accessToken;
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
      await rememberRoleMirror(exchangedRole);
      return true;
    } catch (e) {
      debugPrint('SupabaseAuthService.syncSession: $e');
      return false;
    }
  }

  /// Shop admin writes require JWT app_role = superadmin.
  Future<void> ensureSuperadminWriteAccess() async {
    if (currentJwtIsSuperadmin) return;
    final desired = await _resolveDesiredRole(null);
    if (desired != 'superadmin') {
      throw StateError(
        'Shop admin changes need a superadmin account. Sign out, sign in again, then retry.',
      );
    }
    final ok = await syncSessionFromFirebase(roleMirror: 'superadmin', forceRefresh: true);
    if (!ok || !currentJwtIsSuperadmin) {
      throw StateError(
        'Could not refresh admin session. Sign out, sign in again as superadmin, then retry.',
      );
    }
  }

  Future<void> clearSession() async {
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedBosRole = null;
    // Keep active tenant preference across logout so re-login restores context.
    await clearRoleMirror();
    if (!SupabaseBootstrap.isInitialized) return;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/firebase_firestore_web.dart';
import '../../core/constants/route_names.dart';
import '../../core/supabase/supabase_auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../features/ai_business_os/domain/bos_access.dart';
import '../../features/ai_business_os/data/bos_repository.dart';
import '../widgets/success_animation_screen.dart';
import '../../platform/data/platform_user_repository.dart';
import 'fcm_service.dart';
import 'firestore_safe_reads.dart';

/// Result of loading the Firebase user profile after sign-in.
sealed class AuthProfileOutcome {}

class AuthProfileExisting extends AuthProfileOutcome {
  AuthProfileExisting(this.role);
  final String role;
}

class AuthProfileNewUser extends AuthProfileOutcome {}

/// Firestore unreachable (e.g. web SDK internal assertion after hot restart).
class AuthProfileUnavailable extends AuthProfileOutcome {}

/// Shared post-login routing — safe Firestore read, web recovery, Supabase role mirror.
class AuthPostLogin {
  /// In-memory role verified from Firestore for this browser/app session only.
  /// Survives transient Firestore web failures without trusting SharedPreferences.
  static String? _sessionUid;
  static String? _sessionRole;

  static String normalizeRole(String? raw) => (raw ?? '').trim().toLowerCase();

  static String? sessionRoleFor(String uid) {
    if (_sessionUid == uid) return _sessionRole;
    return null;
  }

  static void rememberSessionRole(String uid, String role) {
    _sessionUid = uid;
    _sessionRole = normalizeRole(role);
  }

  static void clearSessionRole() {
    _sessionUid = null;
    _sessionRole = null;
  }

  static AuthProfileExisting _existingFromDoc(
    String uid,
    Map<String, dynamic>? data,
  ) {
    final role = normalizeRole(data?['role'] as String?);
    rememberSessionRole(uid, role);
    return AuthProfileExisting(role);
  }

  static Future<void> recoverBrokenFirestoreWeb() async {
    if (!kIsWeb) return;
    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      debugPrint('AuthPostLogin: Firestore web client reset');
    } catch (e) {
      debugPrint('AuthPostLogin: Firestore reset failed: $e');
    }
  }

  static Future<AuthProfileOutcome> resolveProfile(String uid) async {
    if (kIsWeb) await configureWebFirestore();
    var doc = await safeGetUserDocument(uid);
    if (doc != null && doc.exists) {
      return _existingFromDoc(uid, doc.data());
    }
    if (doc == null) {
      await recoverBrokenFirestoreWeb();
      doc = await safeGetUserDocument(uid);
      if (doc != null && doc.exists) {
        return _existingFromDoc(uid, doc.data());
      }
      // Prefer role verified earlier this session (login → /admin race).
      final cached = sessionRoleFor(uid);
      if (cached != null && cached.isNotEmpty) {
        return AuthProfileExisting(cached);
      }
      final mirror = normalizeRole(await _roleMirrorFromSupabase(uid));
      // Never promote to superadmin from Supabase alone (stale mirror after role fix).
      if (mirror.isNotEmpty && mirror != 'superadmin') {
        rememberSessionRole(uid, mirror);
        return AuthProfileExisting(mirror);
      }
      return AuthProfileUnavailable();
    }
    return AuthProfileNewUser();
  }

  static Future<String?> _roleMirrorFromSupabase(String uid) async {
    if (!SupabaseBootstrap.isInitialized) return null;
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return null;
    try {
      final row = await client
          .from('platform_users')
          .select('role_mirror')
          .eq('firebase_uid', uid)
          .maybeSingle();
      return row?['role_mirror'] as String?;
    } catch (e) {
      debugPrint('AuthPostLogin: Supabase role_mirror read: $e');
      return null;
    }
  }

  static String homeRouteForRole(String role) {
    switch (normalizeRole(role)) {
      case 'superadmin':
        return RouteNames.adminHome;
      case 'dealer':
        // Connect dealer shell is mobile-only; web lands on shop.
        return kIsWeb ? RouteNames.publicStore : RouteNames.dealerHome;
      case 'technician':
        return kIsWeb ? RouteNames.publicStore : RouteNames.technicianHome;
      case 'customer':
        return RouteNames.accountHome;
      default:
        return kIsWeb ? RouteNames.publicHome : RouteNames.serviceAreaPicker;
    }
  }

  /// Optional post-login redirect (e.g. checkout / calculator) — must be an in-app path.
  static String? redirectFromUri(Uri uri) {
    return sanitizeRedirect(uri.queryParameters['redirect']);
  }

  /// Safe return path after login. Blocks open redirects and web-only-missing Connect shells.
  static String? sanitizeRedirect(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var path = raw;
    try {
      path = Uri.decodeComponent(raw);
    } catch (_) {}
    if (!path.startsWith('/') || path.startsWith('//')) return null;
    // Never bounce into missing Connect shells on web.
    if (kIsWeb &&
        (path.startsWith('/dealer') || path.startsWith('/technician'))) {
      return null;
    }
    if (path.startsWith('/admin')) return null;
    return path;
  }

  /// Prefer explicit return URL, else role home (platform-safe).
  /// Superadmin always lands on admin — ignore shop/calculator return URLs.
  static String resolvePostLoginRoute(String role, {String? redirectAfterLogin}) {
    final normalized = normalizeRole(role);
    if (normalized == 'superadmin') {
      return RouteNames.adminHome;
    }
    return sanitizeRedirect(redirectAfterLogin) ?? homeRouteForRole(normalized);
  }

  /// Like [resolvePostLoginRoute], but bos tenant members land on AI Business OS.
  static Future<String> resolvePostLoginRouteAsync(
    String role, {
    String? redirectAfterLogin,
  }) async {
    final normalized = normalizeRole(role);
    if (normalized == 'superadmin') {
      return RouteNames.adminHome;
    }
    final redirect = sanitizeRedirect(redirectAfterLogin);
    if (redirect != null) return redirect;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && await BosAccess.hasActiveMembership(uid)) {
      try {
        final done = await BosRepository().isOnboardingCompleted();
        if (!done) return RouteNames.adminAiOsOnboarding;
      } catch (_) {}
      return RouteNames.adminAiOsHome;
    }
    return homeRouteForRole(normalized);
  }

  /// Build login URL that returns the user to [returnPath] after sign-in.
  static String loginUrlWithReturn(String returnPath) {
    final safe = sanitizeRedirect(returnPath) ?? returnPath;
    if (!safe.startsWith('/')) return RouteNames.login;
    return '${RouteNames.login}?redirect=${Uri.encodeComponent(safe)}';
  }

  static String phoneUrlWithReturn(String returnPath) {
    final safe = sanitizeRedirect(returnPath) ?? returnPath;
    if (!safe.startsWith('/')) return RouteNames.phoneEntry;
    return '${RouteNames.phoneEntry}?redirect=${Uri.encodeComponent(safe)}';
  }

  /// Web public site → homepage; native app → phone login entry.
  static String postLogoutRoute() =>
      kIsWeb ? RouteNames.publicHome : RouteNames.phoneEntry;

  static Future<void> complete(
    BuildContext context,
    UserCredential cred, {
    bool useSuccessAnimation = false,
    VoidCallback? onLoadingEnd,
    String? redirectAfterLogin,
  }) async {
    final uid = cred.user?.uid;
    if (uid == null || uid.isEmpty) {
      onLoadingEnd?.call();
      return;
    }

    final outcome = await resolveProfile(uid);
    if (!context.mounted) return;
    onLoadingEnd?.call();

    switch (outcome) {
      case AuthProfileUnavailable():
        _showProfileUnavailable(context);
        return;
      case AuthProfileNewUser():
        final redirect = redirectAfterLogin;
        if (redirect != null &&
            (redirect.startsWith('/store') ||
                redirect.startsWith('/calculator') ||
                redirect.startsWith('/app/calculator') ||
                redirect.startsWith('/account') ||
                redirect.startsWith('/product'))) {
          context.go('${RouteNames.registerCustomer}?redirect=${Uri.encodeComponent(redirect)}');
          return;
        }
        context.go(kIsWeb ? RouteNames.registerCustomer : RouteNames.serviceAreaPicker);
        return;
      case AuthProfileExisting(:final role):
        try {
          await FcmService.saveTokenToUser(uid);
          await FcmService.saveCurrentRole(role);
        } catch (_) {}
        await PlatformUserRepository.instance.ensureProvisioned(firebaseUid: uid);
        await SupabaseAuthService.instance.rememberRoleMirror(role);
        final normalized = normalizeRole(role);
        rememberSessionRole(uid, normalized);
        await SupabaseAuthService.instance.syncSessionFromFirebase(
          roleMirror: normalized == 'superadmin' ? 'superadmin' : 'user',
          forceRefresh: true,
        );
        if (!context.mounted) return;
        final redirect = redirectAfterLogin;
        final next = resolvePostLoginRoute(normalized, redirectAfterLogin: redirect);
        // Admin: skip success flash — guard + deferred admin load is enough friction.
        if (useSuccessAnimation && normalized != 'superadmin') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.go(
              RouteNames.successAnimation,
              extra: {
                'successType': SuccessType.loginSuccess,
                'nextRoute': next,
                'extra': null,
              },
            );
          });
        } else {
          context.go(next);
        }
    }
  }

  static Future<void> finishExistingUser(
    BuildContext context,
    String uid, {
    String? redirectAfterLogin,
    bool useSuccessAnimation = false,
  }) async {
    final outcome = await resolveProfile(uid);
    if (!context.mounted) return;

    switch (outcome) {
      case AuthProfileUnavailable():
        _showProfileUnavailable(context);
        return;
      case AuthProfileNewUser():
        context.go(RouteNames.registerCustomer);
        return;
      case AuthProfileExisting(:final role):
        try {
          await FcmService.saveTokenToUser(uid);
          await FcmService.saveCurrentRole(role);
        } catch (_) {}
        await PlatformUserRepository.instance.ensureProvisioned(firebaseUid: uid);
        await SupabaseAuthService.instance.rememberRoleMirror(role);
        final normalized = normalizeRole(role);
        rememberSessionRole(uid, normalized);
        await SupabaseAuthService.instance.syncSessionFromFirebase(
          roleMirror: normalized == 'superadmin' ? 'superadmin' : 'user',
          forceRefresh: true,
        );
        if (!context.mounted) return;
        final next = resolvePostLoginRoute(normalized, redirectAfterLogin: redirectAfterLogin);
        if (useSuccessAnimation) {
          context.go(
            RouteNames.successAnimation,
            extra: {
              'successType': SuccessType.registerSuccess,
              'nextRoute': next,
              'extra': null,
            },
          );
        } else {
          context.go(next);
        }
    }
  }

  static void _showProfileUnavailable(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profile could not load'),
        content: const Text(
          'You signed in successfully, but user data could not be read. '
          'On web, fully refresh the page (F5) or stop and restart flutter run, then sign in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}

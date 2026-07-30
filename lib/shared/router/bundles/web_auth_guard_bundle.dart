import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/firebase_bootstrap.dart';
import '../../../core/constants/route_names.dart';
import '../../../features/ai_business_os/domain/bos_access.dart';
import '../../services/auth_post_login.dart';

/// Firebase Auth guards — deferred so home cold-start skips Firebase JS.
Future<String?> authRouteRedirect(GoRouterState state) async {
  await FirebaseBootstrap.ensureInitialized();
  if (Firebase.apps.isEmpty) return null;

  final path = state.uri.path;
  final user = FirebaseAuth.instance.currentUser;

  if (path.startsWith('/admin')) {
    if (user == null) return RouteNames.login;
    final outcome = await AuthPostLogin.resolveProfile(user.uid);
    if (outcome is AuthProfileExisting) {
      final isSuper =
          AuthPostLogin.normalizeRole(outcome.role) == 'superadmin';
      if (await BosAccess.canAccessAdminPath(path, isFirebaseSuperadmin: isSuper)) {
        return null;
      }
      return RouteNames.publicHome;
    }
    if (outcome is AuthProfileNewUser) return RouteNames.publicHome;
    // Transient Firestore failure: keep admin if this session already verified.
    if (AuthPostLogin.sessionRoleFor(user.uid) == 'superadmin') return null;
    if (await BosAccess.hasActiveMembership(user.uid) &&
        (path == RouteNames.adminHome ||
            path == '/admin' ||
            path.startsWith('/admin/ai-os'))) {
      return null;
    }
    return RouteNames.login;
  }

  if ((path.startsWith('/account') ||
          path == RouteNames.publicCheckout ||
          path.startsWith('/app/calculator')) &&
      user == null) {
    final target = state.uri.hasQuery
        ? '${state.uri.path}?${state.uri.query}'
        : state.uri.path;
    return AuthPostLogin.loginUrlWithReturn(target);
  }

  if (user != null &&
      (path == RouteNames.login || path == RouteNames.phoneEntry)) {
    final outcome = await AuthPostLogin.resolveProfile(user.uid);
    switch (outcome) {
      case AuthProfileExisting(:final role):
        final redirect = AuthPostLogin.redirectFromUri(state.uri);
        return AuthPostLogin.resolvePostLoginRouteAsync(
          role,
          redirectAfterLogin: redirect,
        );
      case AuthProfileNewUser():
        final redirect = AuthPostLogin.redirectFromUri(state.uri);
        if (redirect != null) {
          return '${RouteNames.registerCustomer}?redirect=${Uri.encodeComponent(redirect)}';
        }
        return RouteNames.registerCustomer;
      case AuthProfileUnavailable():
        return null;
    }
  }

  return null;
}

WebAuthRefreshNotifier? _globalAuthRefresh;

Future<WebAuthRefreshNotifier> ensureAuthRefreshNotifier() async {
  _globalAuthRefresh ??= WebAuthRefreshNotifier();
  await _globalAuthRefresh!.ensureAttached();
  return _globalAuthRefresh!;
}

/// Refreshes GoRouter when auth state changes (login/admin/settings only).
class WebAuthRefreshNotifier extends ChangeNotifier {
  StreamSubscription<User?>? _sub;

  Future<void> ensureAttached() async {
    if (_sub != null) return;
    await FirebaseBootstrap.ensureInitialized();
    if (Firebase.apps.isEmpty) return;
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

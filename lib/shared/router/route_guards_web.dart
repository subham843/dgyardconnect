import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../features/ai_business_os/domain/bos_access.dart';
import '../services/auth_post_login.dart';

/// Web route guards — role-aware redirects after Firebase Auth.
abstract final class RouteGuards {
  static Future<String?> redirect(
    BuildContext context,
    GoRouterState state,
  ) async {
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
      if (AuthPostLogin.sessionRoleFor(user.uid) == 'superadmin') return null;
      if (await BosAccess.hasActiveMembership(user.uid) &&
          (path == RouteNames.adminHome ||
              path == '/admin' ||
              path.startsWith('/admin/ai-os'))) {
        return null;
      }
      return RouteNames.login;
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
          return RouteNames.registerCustomer;
        case AuthProfileUnavailable():
          return null;
      }
    }

    return null;
  }
}

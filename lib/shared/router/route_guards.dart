import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/remote_config/app_remote_config_controller_export.dart';
import '../../features/marketplace/config/marketplace_feature_flags.dart';
import '../../features/shop/config/shop_feature_flags.dart';
import '../services/account_completion_guard.dart';
import '../services/auth_post_login.dart';
import '../services/firestore_safe_reads.dart';

/// Auth and role checks for go_router. Redirects to login, pending approval, or role home.
class RouteGuards {
  static Future<String?> redirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    try {
      return await _redirect(context, state);
    } catch (e, st) {
      debugPrint('RouteGuards.redirect: $e');
      if (isFirestoreInternalAssertion(e)) {
        // Do not crash the app when Firestore web client is in a bad state (hot restart).
        return null;
      }
      debugPrint('$st');
      return null;
    }
  }

  static Future<String?> _redirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    if (Firebase.apps.isEmpty) return null;
    final authUser = FirebaseAuth.instance.currentUser;
    final isLoggedIn = authUser != null;
    final path = state.uri.path;

    // Public routes (no login or no user doc required)
    if (path == RouteNames.splash ||
        path == RouteNames.appWalkthrough ||
        // New public web routes
        path == RouteNames.publicHome ||
        path == RouteNames.publicStore ||
        path.startsWith('/store/category/') ||
        path == RouteNames.publicCart ||
        path.startsWith('/product/') ||
        path == RouteNames.publicCalculatorList ||
        _isPublicCalculatorDetailPath(path) ||
        path == RouteNames.publicServices ||
        path == RouteNames.publicConnect ||
        path == RouteNames.publicAbout ||
        path == RouteNames.publicContact ||
        path == RouteNames.supportHome ||
        path == RouteNames.supportFaq ||
        // Legal pages
        path == RouteNames.webPrivacyPolicy ||
        path == RouteNames.webDataDeletion ||
        // Auth routes
        path == RouteNames.phoneEntry ||
        path == RouteNames.otpVerify ||
        path == RouteNames.serviceAreaPicker ||
        path == RouteNames.serviceAreaDetails ||
        path == RouteNames.roleChoice ||
        path == RouteNames.login ||
        path.startsWith(RouteNames.registerDealer) ||
        path.startsWith(RouteNames.registerTechnician) ||
        path == RouteNames.pendingApproval ||
        path == RouteNames.successAnimation ||
        path.startsWith(RouteNames.customerRate) ||
        path.startsWith(RouteNames.customerChat) ||
        path == RouteNames.verifyRecord ||
        path.startsWith(RouteNames.registerCustomer) ||
        path == RouteNames.bosTrialSignup ||
        path == RouteNames.bosPublicChat ||
        path.startsWith(RouteNames.legalMenu) ||
        path.startsWith('/legal/')) {
      if (isLoggedIn &&
          (path == RouteNames.login ||
              path == RouteNames.phoneEntry ||
              path == RouteNames.otpVerify)) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return null;
        var userDoc = await safeGetUserDocument(uid);
        if (userDoc == null) {
          await AuthPostLogin.recoverBrokenFirestoreWeb();
          userDoc = await safeGetUserDocument(uid);
        }
        if (userDoc == null || !userDoc.exists) {
          final outcome = await AuthPostLogin.resolveProfile(uid);
          if (outcome is AuthProfileExisting) {
            return AuthPostLogin.homeRouteForRole(outcome.role);
          }
          return null;
        }
        return await _redirectToRoleHome(userDoc);
      }
      if (isLoggedIn && path == RouteNames.serviceAreaPicker) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return RouteNames.phoneEntry;
        final userDoc = await safeGetUserDocument(uid);
        if (userDoc != null && userDoc.exists) {
          return await _redirectToRoleHome(userDoc);
        }
      }
      return null;
    }

    if (!isLoggedIn) {
      return kIsWeb ? RouteNames.publicHome : RouteNames.phoneEntry;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return kIsWeb ? RouteNames.publicHome : RouteNames.phoneEntry;
    }
    final remoteConfig = _readRemoteConfig(context);
    final userDoc = await safeGetUserDocument(uid);
    if (userDoc == null) return null;

    if (!userDoc.exists) {
      return kIsWeb ? RouteNames.publicHome : RouteNames.phoneEntry;
    }

    // Customer account + shop checkout (any logged-in role)
    if (path == RouteNames.accountHome ||
        path == RouteNames.accountOrders ||
        path.startsWith('/account/orders/') ||
        path == RouteNames.publicCheckout) {
      return null;
    }

    if (path.startsWith('/marketplace')) {
      try {
        final config = remoteConfig?.config;
        if (config == null) return await _redirectToRoleHome(userDoc);
        if (ShopFeatureFlags.isSupabaseShopEnabled(config) ||
            ShopFeatureFlags.hideMarketplaceBuyer(config)) {
          return RouteNames.shopHome;
        }
        if (!MarketplaceFeatureFlags.isMarketplaceEnabled(config)) {
          return await _redirectToRoleHome(userDoc);
        }
      } catch (_) {
        return await _redirectToRoleHome(userDoc);
      }
    }

    if (path.startsWith('/admin/marketplace')) {
      try {
        final config = remoteConfig?.config;
        if (config == null) return await _redirectToRoleHome(userDoc);
        if (!MarketplaceFeatureFlags.isMarketplaceEnabled(config)) {
          return await _redirectToRoleHome(userDoc);
        }
      } catch (_) {
        return await _redirectToRoleHome(userDoc);
      }
    }

    // Authenticated shop/calculator routes (not public store/calculator)
    if (path.startsWith('/shop') && !path.startsWith('/shop/')) {
      // /shop is the authenticated shop home, require feature flag
      try {
        final config = remoteConfig?.config;
        if (config == null) return await _redirectToRoleHome(userDoc);
        if (!ShopFeatureFlags.isSupabaseShopEnabled(config)) {
          return await _redirectToRoleHome(userDoc);
        }
      } catch (_) {
        return await _redirectToRoleHome(userDoc);
      }
    }

    final approved = userDoc.data()?['approved'] as bool? ?? false;
    final role = userDoc.data()?['role'] as String? ?? '';
    final userData = userDoc.data() ?? <String, dynamic>{};

    // Unapproved dealer/technician can access their home; pop-up shown there
    if (!approved && role != 'superadmin') {
      return null; // Allow navigation to role home
    }

    // Role-based redirect from login / phone
    if (path == RouteNames.login || path == RouteNames.phoneEntry) {
      return await _redirectToRoleHome(userDoc);
    }

    // Dealer: protect post-job deep link by profile + KYC completion
    if (path == RouteNames.dealerPostJob && role == 'dealer') {
      if (!AccountCompletionGuard.isDealerProfileComplete(userData)) {
        return RouteNames.dealerProfile;
      }
      if (!AccountCompletionGuard.isKycVerified(userData)) {
        return RouteNames.dealerKyc;
      }
    }

    // Technician: protect acceptance flows by profile + KYC completion
    if (role == 'technician' &&
        (path == RouteNames.technicianIncomingJob ||
            RegExp(r'^/technician/jobs/[^/]+/bidding$').hasMatch(path))) {
      if (!AccountCompletionGuard.isTechnicianProfileComplete(userData)) {
        return RouteNames.technicianProfile;
      }
      if (!AccountCompletionGuard.isKycVerified(userData)) {
        return RouteNames.technicianKyc;
      }
    }

    // KYC routes are available only after profile completion.
    if (role == 'dealer' && path == RouteNames.dealerKyc) {
      if (!AccountCompletionGuard.isDealerProfileComplete(userData)) {
        return RouteNames.dealerProfile;
      }
    }
    if (role == 'technician' && path == RouteNames.technicianKyc) {
      if (!AccountCompletionGuard.isTechnicianProfileComplete(userData)) {
        return RouteNames.technicianProfile;
      }
    }

    return null;
  }

  static AppRemoteConfigController? _readRemoteConfig(BuildContext context) {
    try {
      return Provider.of<AppRemoteConfigController>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _redirectToRoleHome(
    DocumentSnapshot<Map<String, dynamic>> userDoc,
  ) async {
    final approved = userDoc.data()?['approved'] as bool? ?? false;
    final role = userDoc.data()?['role'] as String? ?? '';

    if (!approved && role != 'superadmin') {
      // Go to role home; profile-under-review pop-up shown there
      if (role == 'dealer') {
        return kIsWeb ? RouteNames.publicStore : RouteNames.dealerHome;
      }
      if (role == 'technician') {
        return kIsWeb ? RouteNames.publicStore : RouteNames.technicianHome;
      }
      if (role == 'customer') return RouteNames.accountHome;
      return RouteNames.phoneEntry;
    }
    switch (role) {
      case 'superadmin':
        return RouteNames.adminHome;
      case 'dealer':
        return kIsWeb ? RouteNames.publicStore : RouteNames.dealerHome;
      case 'technician':
        return kIsWeb ? RouteNames.publicStore : RouteNames.technicianHome;
      case 'customer':
        return RouteNames.accountHome;
      default:
        return kIsWeb ? RouteNames.publicHome : RouteNames.phoneEntry;
    }
  }

  /// Public marketing calculator detail (`/calculator/:slug`), not in-app wizard routes.
  static bool _isPublicCalculatorDetailPath(String path) {
    if (!path.startsWith('/calculator/')) return false;
    if (path.startsWith('/app/calculator')) return false;
    const blocked = {'template', 'quotations'};
    final slug = path.substring('/calculator/'.length).split('/').first;
    return slug.isNotEmpty && !blocked.contains(slug);
  }
}

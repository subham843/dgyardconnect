import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../features/web_public/pages/home/home_shell_bundle.dart' deferred as home_shell;
import '../deferred_go_route.dart';
import '../home_cold_start_placeholder.dart';
import '../deferred_route_child.dart';
import '../navigator_key.dart';
import '../router_transitions.dart';
import 'web_account_routes_bundle.dart' deferred as web_account;
import 'web_admin_routes_bundle.dart' deferred as web_admin;
import 'web_connect_admin_routes_bundle.dart' deferred as web_connect_admin;
import 'web_auth_guard_bundle.dart' deferred as web_auth_guard;
import 'web_auth_routes_bundle.dart' deferred as web_auth;
import 'web_seo_routes_bundle.dart' deferred as web_seo;
import 'web_static_routes_bundle.dart' deferred as web_static;
import 'web_store_routes_bundle.dart' deferred as web_store;

/// Loads Firebase Auth refresh only on login/admin/settings (not home cold-start).
class _LazyAuthRefresh extends ChangeNotifier {
  Future<void>? _attachFuture;

  void attachIfNeeded() {
    _attachFuture ??= web_auth_guard.loadLibrary().then((_) async {
      final notifier = await web_auth_guard.ensureAuthRefreshNotifier();
      notifier.addListener(notifyListeners);
    });
    unawaited(_attachFuture);
  }
}

final _lazyAuthRefresh = _LazyAuthRefresh();

bool _needsAuthGuard(String path) =>
    path.startsWith('/login') ||
    path.startsWith('/phone') ||
    path.startsWith('/otp') ||
    path.startsWith('/admin') ||
    path.startsWith('/settings') ||
    path.startsWith('/account') ||
    path.startsWith('/store/checkout') ||
    path.startsWith('/app/calculator');

String? _connectRedirect(String path) {
  if (path.startsWith('/dealer') || path.startsWith('/technician')) {
    return RouteNames.publicStore;
  }
  // Connect + Shop + Calculator admin all stay on web.
  if (path.startsWith('/admin')) {
    return null;
  }
  // Legacy marketplace → public store. Authenticated /shop and /app/calculator stay.
  if (path.startsWith('/marketplace')) {
    return RouteNames.publicStore;
  }
  // Mobile shop paths → public store / account on web.
  if (path.startsWith('/shop')) {
    if (path == RouteNames.shopCart) return RouteNames.publicCart;
    if (path == RouteNames.shopCheckout) return RouteNames.publicCheckout;
    if (path == RouteNames.shopOrders) return RouteNames.accountOrders;
    return RouteNames.publicStore;
  }
  if (path.startsWith('/walkthrough') ||
      path.startsWith('/service-area') ||
      path.startsWith('/role-choice') ||
      path == RouteNames.offers) {
    return RouteNames.login;
  }
  return null;
}

GoRouter createFullWebRouter({String initialLocation = RouteNames.publicHome}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  refreshListenable: _lazyAuthRefresh,
  initialLocation: initialLocation,
  redirect: (context, state) async {
    final path = state.uri.path;
    final trimmed = _connectRedirect(path);
    if (trimmed != null) return trimmed;
    if (!_needsAuthGuard(path)) return null;
    _lazyAuthRefresh.attachIfNeeded();
    await web_auth_guard.loadLibrary();
    return web_auth_guard.authRouteRedirect(state);
  },
  routes: [
    GoRoute(
      path: RouteNames.publicHome,
      name: 'publicHome',
      pageBuilder: (c, s) => deferredPage(
        s,
        load: home_shell.loadLibrary,
        build: (context, state) => home_shell.buildPublicHome(),
        loading: const HomeColdStartPlaceholder(),
        errorLabel: 'Could not load home page.',
      ),
    ),

    GoRoute(
      path: RouteNames.publicStore,
      name: 'publicStore',
      pageBuilder: (c, s) => _lazyStorePage(s),
    ),
    GoRoute(
      path: '/store/category/:slug',
      name: 'publicStoreCategory',
      pageBuilder: (c, s) => _lazyStorePage(s),
    ),
    GoRoute(
      path: RouteNames.publicCart,
      name: 'publicCart',
      pageBuilder: (c, s) => _lazyStorePage(s),
    ),
    GoRoute(
      path: RouteNames.publicCheckout,
      name: 'publicCheckout',
      pageBuilder: (c, s) => _lazyStorePage(s),
    ),
    GoRoute(
      path: RouteNames.publicProductDetail,
      name: 'publicProductDetail',
      pageBuilder: (c, s) => _lazyStorePage(s),
    ),

    GoRoute(
      path: RouteNames.publicCalculatorList,
      name: 'publicCalculatorList',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.publicCalculatorDetail,
      name: 'publicCalculatorDetail',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.publicServices,
      name: 'publicServices',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.publicServicesInstallations,
      name: 'publicServicesInstallations',
      pageBuilder: (c, s) => _lazySeoPage(s),
    ),
    GoRoute(
      path: RouteNames.publicServicesCities,
      name: 'publicServicesCities',
      pageBuilder: (c, s) => _lazySeoPage(s),
    ),
    GoRoute(
      path: RouteNames.publicBlogDetail,
      name: 'publicBlogDetail',
      pageBuilder: (c, s) => _lazySeoPage(s),
    ),
    GoRoute(
      path: RouteNames.publicConnect,
      name: 'publicConnect',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.publicAbout,
      name: 'publicAbout',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.publicContact,
      name: 'publicContact',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.webPrivacyPolicy,
      name: 'webPrivacyPolicy',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.webDataDeletion,
      name: 'webDataDeletion',
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),
    GoRoute(
      path: RouteNames.supportHome,
      pageBuilder: (c, s) => _lazyStaticPage(s),
    ),

    GoRoute(
      path: RouteNames.splash,
      name: 'splash',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.login,
      name: 'login',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.phoneEntry,
      name: 'phone',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.otpVerify,
      name: 'otp',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.registerDealer,
      name: 'registerDealer',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.registerTechnician,
      name: 'registerTechnician',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.registerCustomer,
      name: 'registerCustomer',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.bosTrialSignup,
      name: 'bosTrialSignup',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.bosPublicChat,
      name: 'bosPublicChat',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.pendingApproval,
      name: 'pendingApproval',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),
    GoRoute(
      path: RouteNames.successAnimation,
      name: 'success',
      pageBuilder: (c, s) => _lazyAuthPage(s),
    ),

    GoRoute(
      path: RouteNames.settings,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.legalMenu,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: '/legal/:documentId',
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.supportFaq,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.supportCreateTicket,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.supportTickets,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.verifyRecord,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.customerRate,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.customerChat,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),

    GoRoute(
      path: RouteNames.accountHome,
      name: 'accountHome',
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.accountOrders,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: '/account/orders/:orderId',
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),

    GoRoute(
      path: RouteNames.calculatorHome,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: '/app/calculator/template/:templateId',
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: RouteNames.calculatorQuotations,
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),
    GoRoute(
      path: '/app/calculator/quotations/:quotationId',
      pageBuilder: (c, s) => _lazyAccountPage(s),
    ),

    GoRoute(
      path: RouteNames.adminHome,
      name: 'adminHome',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopHome,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopCategories,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopSubCategories,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopSubCategoryCreate,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/shop/sub-categories/new/:categoryId',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/shop/sub-categories/:subCategoryId/edit',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopAttributeMaster,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopAttributeCreate,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/shop/attribute-master/:attributeId/edit',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopAttributeGroups,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopBrands,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopBulkImport,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopProductImport,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopProducts,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopProductCreate,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/shop/products/new/:subCategoryId',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/shop/products/:productId/edit',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopInventory,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopPurchases,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopSuppliers,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopCustomers,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopQuotations,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopReports,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminShopOrders,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorHome,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorFamilies,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorFamilyCreate,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/calculator/families/:familyId/edit',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorQuestionGroups,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorOptions,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorTemplates,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorQuestions,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorRules,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorRuleProducts,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorQuotationBuilder,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminSeoHome,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminSeoCities,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminSeoCityCreate,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/seo/cities/:cityId/edit',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminSeoServices,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminSeoServiceCreate,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/seo/services/:serviceId/edit',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminSeoBlogPosts,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminSeoBlogCreate,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: '/admin/seo/blogs/:blogId/edit',
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsHome,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsHowToUse,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsCrm,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsLeads,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsCalendar,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsWhatsapp,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsVoice,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsCampaigns,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsKnowledge,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsProposals,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsQuotations,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsMarketing,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsEstimator,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsTickets,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsProjects,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsReports,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsBilling,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsMarketplace,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsSettings,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsAcceptInvite,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),
    GoRoute(
      path: RouteNames.adminAiOsOnboarding,
      pageBuilder: (c, s) => _lazyAdminPage(s),
    ),

    // Dynamic SEO landing pages
    GoRoute(
      path: RouteNames.publicSeoLandingPattern,
      name: 'publicSeoLanding',
      pageBuilder: (c, s) => _lazySeoPage(s),
    ),

    // Connect admin (Firebase) — deferred; does not affect homepage PSI.
    GoRoute(
      path: '/admin/:rest(.*)',
      pageBuilder: (c, s) => _lazyConnectAdminPage(s),
    ),
  ],
);

CustomTransitionPage<void> _lazyPage(
  GoRouterState state,
  Future<void> Function() loader,
  Widget Function() builder,
) {
  return routerTransitionPage(
    state,
    DeferredRouteChild(loader: loader, builder: builder),
  );
}

Future<void> _loadAuthBundle() async {
  await SupabaseBootstrap.ensureInitialized();
  await web_auth.loadLibrary();
}

Future<void> _loadAccountBundle() async {
  await SupabaseBootstrap.ensureInitialized();
  await web_account.loadLibrary();
}

Future<void> _loadStoreBundle() async {
  await SupabaseBootstrap.ensureInitialized();
  await web_store.loadLibrary();
}

Future<void> _loadSeoBundle() async {
  await SupabaseBootstrap.ensureInitialized();
  await web_seo.loadLibrary();
}

Future<void> _loadStaticBundle() async {
  await SupabaseBootstrap.ensureInitialized();
  await web_static.loadLibrary();
}

Future<void> _loadAdminBundle() async {
  await SupabaseBootstrap.ensureInitialized();
  await web_admin.loadLibrary();
}

Future<void> _loadConnectAdminBundle() async {
  await web_connect_admin.loadLibrary();
}

CustomTransitionPage<void> _lazyAuthPage(GoRouterState state) => _lazyPage(
      state,
      _loadAuthBundle,
      () => web_auth.buildAuthScreen(state),
    );

CustomTransitionPage<void> _lazyAccountPage(GoRouterState state) => _lazyPage(
      state,
      _loadAccountBundle,
      () => web_account.buildAccountScreen(state),
    );

CustomTransitionPage<void> _lazyStorePage(GoRouterState state) =>
    publicTransitionPage(
      state,
      DeferredRouteChild(
        loader: _loadStoreBundle,
        builder: () => web_store.buildStoreScreen(state),
      ),
    );

CustomTransitionPage<void> _lazySeoPage(GoRouterState state) =>
    publicTransitionPage(
      state,
      DeferredRouteChild(
        loader: _loadSeoBundle,
        builder: () => web_seo.buildSeoScreen(state),
      ),
    );

CustomTransitionPage<void> _lazyStaticPage(GoRouterState state) =>
    publicTransitionPage(
      state,
      DeferredRouteChild(
        loader: _loadStaticBundle,
        builder: () => web_static.buildStaticScreen(state),
      ),
    );

CustomTransitionPage<void> _lazyAdminPage(GoRouterState state) => _lazyPage(
      state,
      _loadAdminBundle,
      () => web_admin.buildAdminScreen(state),
    );

CustomTransitionPage<void> _lazyConnectAdminPage(GoRouterState state) =>
    _lazyPage(
      state,
      _loadConnectAdminBundle,
      () => web_connect_admin.buildConnectAdminScreen(state),
    );

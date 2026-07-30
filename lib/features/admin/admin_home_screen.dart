import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/remote_config/app_remote_config_controller_export.dart';
import '../../core/supabase/supabase_auth_service.dart';
import '../marketplace/config/marketplace_feature_flags.dart';
import 'modules/admin_module.dart';
import 'modules/ai_business_os_module_sections.dart';
import 'modules/calculator_module_sections.dart';
import 'modules/connect_module_sections.dart' as connect_nav;
import 'modules/shop_module_sections.dart';
import 'modules/seo_module_sections.dart';
import 'admin_module_embedded_content.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/router/app_router.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/firestore_service.dart';
import '../ai_business_os/domain/bos_access.dart';
import '../ai_business_os/domain/bos_feature_flags.dart';
import '../ai_business_os/data/bos_repository.dart';

const _adminBg = Color(0xFFF8FAFC);
const _adminText = Color(0xFF0F172A);
const _adminTextSoft = Color(0xFF64748B);
const _adminBorder = Color(0xFFE2E8F0);
const _kRunningStatuses = [
  'bidding',
  'agreed',
  'paymentPending',
  'paid',
  'inProgress',
  'pendingDealerConfirm',
];

/// Super Admin Command Center (v2) — full UI rebuild.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;
  AdminModule _platformModule = AdminModule.connect;
  String _query = '';
  bool _moduleHubExpanded = true;
  String? _embeddedRoute;
  late final TextEditingController _searchController;
  bool _isFirebaseSuperadmin = true;

  static bool _usesEmbeddedShell(AdminModule module) =>
      module == AdminModule.shop ||
      module == AdminModule.calculator ||
      module == AdminModule.seo ||
      module == AdminModule.aiBusinessOs;

  static bool _navRouteMatches(String itemRoute, String selectedRoute) {
    if (itemRoute == selectedRoute) return true;
    if (itemRoute == RouteNames.adminCalculatorFamilies &&
        (selectedRoute == RouteNames.adminCalculatorFamilyCreate ||
            RouteNames.parseAdminCalculatorFamilyEditId(selectedRoute) !=
                null)) {
      return true;
    }
    if (itemRoute == RouteNames.adminShopProducts &&
        (selectedRoute == RouteNames.adminShopProductCreate ||
            RouteNames.parseAdminShopProductEditId(selectedRoute) != null ||
            RouteNames.parseAdminShopProductCreateSubCategoryId(
                  selectedRoute,
                ) !=
                null)) {
      return true;
    }
    return false;
  }

  static String _defaultEmbeddedRoute(AdminModule module) {
    switch (module) {
      case AdminModule.shop:
        return RouteNames.adminShopHome;
      case AdminModule.calculator:
        return RouteNames.adminCalculatorFamilies;
      case AdminModule.seo:
        return RouteNames.adminSeoHome;
      case AdminModule.aiBusinessOs:
        return RouteNames.adminAiOsHome;
      case AdminModule.connect:
        return RouteNames.adminPlatformDashboard;
    }
  }

  String get _activeEmbeddedRoute =>
      _embeddedRoute ?? _defaultEmbeddedRoute(_platformModule);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _query);
    _searchController.addListener(() {
      final next = _searchController.text;
      if (next == _query) return;
      setState(() => _query = next);
    });
    _resolveAccess();
  }

  Future<void> _resolveAccess() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    var isSuper = SupabaseAuthService.instance.currentJwtIsSuperadmin;
    if (uid != null) {
      final outcome = await AuthPostLogin.resolveProfile(uid);
      if (outcome is AuthProfileExisting) {
        isSuper = AuthPostLogin.normalizeRole(outcome.role) == 'superadmin';
      }
    }
    // Load plan feature flags for AI OS Mega Menu gating.
    try {
      await BosRepository().refreshFeatureFlags();
    } catch (_) {}
    if (mounted) setState(() {});
    if (!isSuper) {
      final member = await BosAccess.hasActiveMembership(uid);
      if (mounted) {
        setState(() {
          _isFirebaseSuperadmin = false;
          if (member) {
            _platformModule = AdminModule.aiBusinessOs;
            _embeddedRoute = RouteNames.adminAiOsHome;
            _tab = 1;
          }
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isFirebaseSuperadmin = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    BosAccess.clearCache();
    await AuthService().signOut();
    if (mounted) {
      rootNavigatorKey.currentContext?.go(AuthPostLogin.postLogoutRoute());
    }
  }

  void _go(String route) => context.push(route);

  void _onNavRoute(String route) {
    if (_usesEmbeddedShell(_platformModule)) {
      setState(() {
        _embeddedRoute = route;
        _moduleHubExpanded = true;
      });
      return;
    }
    _go(route);
  }

  void _onPlatformModuleChanged(AdminModule module) {
    if (!_isFirebaseSuperadmin && module != AdminModule.aiBusinessOs) {
      return;
    }
    setState(() {
      _platformModule = module;
      _tab = 0;
      if (_usesEmbeddedShell(module)) {
        _embeddedRoute = _defaultEmbeddedRoute(module);
        _moduleHubExpanded = true;
      }
    });
  }

  List<connect_nav.AdminNavSection> _rawSectionsForModule() {
    switch (_platformModule) {
      case AdminModule.shop:
        return shopModuleSections();
      case AdminModule.calculator:
        return calculatorModuleSections();
      case AdminModule.seo:
        return seoModuleSections();
      case AdminModule.aiBusinessOs:
        return aiBusinessOsModuleSections();
      case AdminModule.connect:
        return connect_nav.connectModuleSections();
    }
  }

  List<_AdminNavSection> get _sections {
    return _rawSectionsForModule()
        .map(
          (s) => _AdminNavSection(
            title: s.title,
            icon: s.icon,
            accent: s.accent,
            hubLabel: s.hubLabel,
            hubRoute: s.hubRoute,
            hubIcon: s.hubIcon,
            items: [
              for (final it in s.items)
                _AdminNavItem(
                  it.title,
                  it.subtitle,
                  it.icon,
                  it.route,
                  it.color,
                ),
            ],
          ),
        )
        .toList(growable: false);
  }

  List<_AdminNavSection> _visibleSections(BuildContext context) {
    var sec = _sections;
    if (_platformModule == AdminModule.aiBusinessOs) {
      sec = [
        for (final s in sec)
          _AdminNavSection(
            title: s.title,
            icon: s.icon,
            accent: s.accent,
            hubLabel: s.hubLabel,
            hubRoute: s.hubRoute,
            hubIcon: s.hubIcon,
            items: [
              for (final it in s.items)
                if (BosFeatureFlags.allowsRoute(it.route)) it,
            ],
          ),
      ];
      return sec;
    }
    if (_platformModule != AdminModule.connect) return sec;
    try {
      final rc = context.watch<AppRemoteConfigController>();
      if (!MarketplaceFeatureFlags.isMarketplaceEnabled(rc.config)) {
        sec = [
          for (final s in _sections)
            _AdminNavSection(
              title: s.title,
              icon: s.icon,
              accent: s.accent,
              items: [
                for (final it in s.items)
                  if (it.route != RouteNames.adminMarketplaceHome) it,
              ],
            ),
        ];
      }
    } catch (_) {}
    return sec;
  }

  List<_AdminNavSection> _tabSectionsVisible(BuildContext context) {
    final v = _visibleSections(context);
    if (_platformModule != AdminModule.connect) return v;
    if (_tab == 1) return v.isNotEmpty ? [v[0]] : v;
    if (_tab == 2) return v.length > 1 ? [v[1]] : v;
    if (_tab == 3) return v.length > 2 ? [v[2], if (v.length > 3) v[3]] : v;
    return v;
  }

  List<_AdminNavItem> _filteredItemsWithMarketplace(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = _tabSectionsVisible(
      context,
    ).expand((s) => s.items).toList(growable: false);
    if (q.isEmpty) return items;
    return items
        .where(
          (it) =>
              it.title.toLowerCase().contains(q) ||
              it.subtitle.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;
    final useEmbeddedShell = _usesEmbeddedShell(_platformModule);
    final useSplitPanel = useEmbeddedShell && width >= 720;
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: _adminBg),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            const _AdminV2Background(),
            SafeArea(
              bottom: false,
              child: useSplitPanel
                  ? Row(
                      children: [
                        _AdminSidebar(
                          selectedTab: _tab,
                          onSelectTab: (i) => setState(() => _tab = i),
                          sections: _visibleSections(context),
                          onTapItem: _onNavRoute,
                          onLogout: _logout,
                          embeddedModuleMode: true,
                          moduleHubExpanded: _moduleHubExpanded,
                          selectedEmbeddedRoute: _activeEmbeddedRoute,
                          onToggleModuleHub: () => setState(
                            () => _moduleHubExpanded = !_moduleHubExpanded,
                          ),
                        ),
                        const VerticalDivider(width: 1, color: _adminBorder),
                        Expanded(
                          child: _AdminEmbeddedWorkspace(
                            platformModule: _platformModule,
                            embeddedRoute: _activeEmbeddedRoute,
                            onPlatformModuleChanged: _onPlatformModuleChanged,
                            onShopNavigate: _onNavRoute,
                            onLogout: _logout,
                            allowedModules: _isFirebaseSuperadmin
                                ? null
                                : const [AdminModule.aiBusinessOs],
                          ),
                        ),
                      ],
                    )
                  : isWide
                  ? Row(
                      children: [
                        _AdminSidebar(
                          selectedTab: _tab,
                          onSelectTab: (i) => setState(() => _tab = i),
                          sections: _visibleSections(context),
                          onTapItem: _onNavRoute,
                          onLogout: _logout,
                        ),
                        const VerticalDivider(width: 1, color: _adminBorder),
                        Expanded(
                          child: _AdminMainContent(
                            tab: _tab,
                            platformModule: _platformModule,
                            onPlatformModuleChanged: _onPlatformModuleChanged,
                            query: _query,
                            controller: _searchController,
                            filteredItems: _filteredItemsWithMarketplace(
                              context,
                            ),
                            onGo: _go,
                            onLogout: _logout,
                            onSetQuery: (q) => setState(() => _query = q),
                            onClear: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            allowedModules: _isFirebaseSuperadmin
                                ? null
                                : const [AdminModule.aiBusinessOs],
                          ),
                        ),
                      ],
                    )
                  : _AdminMainContent(
                      tab: _tab,
                      platformModule: _platformModule,
                      onPlatformModuleChanged: _onPlatformModuleChanged,
                      query: _query,
                      controller: _searchController,
                      filteredItems: _filteredItemsWithMarketplace(context),
                      onGo: useEmbeddedShell ? _onNavRoute : _go,
                      onLogout: _logout,
                      onSetQuery: (q) => setState(() => _query = q),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      embeddedRoute: useEmbeddedShell
                          ? _activeEmbeddedRoute
                          : null,
                      moduleHubExpanded: _moduleHubExpanded,
                      onToggleModuleHub: () => setState(
                        () => _moduleHubExpanded = !_moduleHubExpanded,
                      ),
                      sections: useEmbeddedShell
                          ? _visibleSections(context)
                          : null,
                      onShopNavigate: useEmbeddedShell ? _onNavRoute : null,
                      allowedModules: _isFirebaseSuperadmin
                          ? null
                          : const [AdminModule.aiBusinessOs],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : _AdminBottomNav(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
      ),
    );
  }
}

class _AdminEmbeddedWorkspace extends StatelessWidget {
  const _AdminEmbeddedWorkspace({
    required this.platformModule,
    required this.embeddedRoute,
    required this.onPlatformModuleChanged,
    required this.onShopNavigate,
    required this.onLogout,
    this.allowedModules,
  });

  final AdminModule platformModule;
  final String embeddedRoute;
  final ValueChanged<AdminModule> onPlatformModuleChanged;
  final ValueChanged<String> onShopNavigate;
  final VoidCallback onLogout;
  final List<AdminModule>? allowedModules;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: _TopBar(
            onLogout: onLogout,
            onOpenDashboard: () {},
            showLogout: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: _AdminModuleChips(
            selected: platformModule,
            onSelected: onPlatformModuleChanged,
            allowedModules: allowedModules,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _adminBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AdminModuleEmbeddedContent(
                  route: embeddedRoute,
                  onShopNavigate: onShopNavigate,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminMainContent extends StatelessWidget {
  const _AdminMainContent({
    required this.tab,
    required this.platformModule,
    required this.onPlatformModuleChanged,
    required this.query,
    required this.controller,
    required this.filteredItems,
    required this.onGo,
    required this.onLogout,
    required this.onSetQuery,
    required this.onClear,
    this.embeddedRoute,
    this.moduleHubExpanded = true,
    this.onToggleModuleHub,
    this.sections,
    this.onShopNavigate,
    this.allowedModules,
  });

  final int tab;
  final AdminModule platformModule;
  final ValueChanged<AdminModule> onPlatformModuleChanged;
  final String query;
  final TextEditingController controller;
  final List<_AdminNavItem> filteredItems;
  final ValueChanged<String> onGo;
  final VoidCallback onLogout;
  final ValueChanged<String> onSetQuery;
  final VoidCallback onClear;
  final String? embeddedRoute;
  final bool moduleHubExpanded;
  final VoidCallback? onToggleModuleHub;
  final List<_AdminNavSection>? sections;
  final ValueChanged<String>? onShopNavigate;
  final List<AdminModule>? allowedModules;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _TopBar(
              onLogout: onLogout,
              onOpenDashboard: () => onGo(RouteNames.adminPlatformDashboard),
              showLogout: true,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _AdminModuleChips(
              selected: platformModule,
              onSelected: onPlatformModuleChanged,
              allowedModules: allowedModules,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _AdminHeroCard(
              title: 'Super Admin · ${platformModule.title}',
              subtitle: platformModule == AdminModule.connect
                  ? 'Command Center · Queues · Users · Finance · Config'
                  : platformModule == AdminModule.shop
                  ? 'Supabase catalog · Products · Inventory · Orders'
                  : platformModule == AdminModule.calculator
                  ? 'Family master · Options · Questions · Rules'
                  : platformModule == AdminModule.seo
                  ? 'SEO cities × services · Dynamic landing pages'
                  : 'AI CRM · Leads · WhatsApp · Campaigns · Knowledge',
              primaryLabel: platformModule == AdminModule.connect
                  ? 'Platform dashboard'
                  : 'Module hub',
              primaryIcon: platformModule == AdminModule.connect
                  ? Icons.dashboard_rounded
                  : Icons.hub_rounded,
              onPrimary: () {
                if (embeddedRoute != null && onToggleModuleHub != null) {
                  onToggleModuleHub!();
                  onGo(
                    platformModule == AdminModule.shop
                        ? RouteNames.adminShopHome
                        : platformModule == AdminModule.calculator
                        ? RouteNames.adminCalculatorHome
                        : platformModule == AdminModule.seo
                        ? RouteNames.adminSeoHome
                        : platformModule == AdminModule.aiBusinessOs
                        ? RouteNames.adminAiOsHome
                        : RouteNames.adminPlatformDashboard,
                  );
                } else {
                  onGo(
                    platformModule == AdminModule.shop
                        ? RouteNames.adminShopHome
                        : platformModule == AdminModule.calculator
                        ? RouteNames.adminCalculatorHome
                        : platformModule == AdminModule.seo
                        ? RouteNames.adminSeoHome
                        : platformModule == AdminModule.aiBusinessOs
                        ? RouteNames.adminAiOsHome
                        : RouteNames.adminPlatformDashboard,
                  );
                }
              },
              secondaryLabel: 'Audit logs',
              secondaryIcon: Icons.history_edu_rounded,
              onSecondary: () => onGo(RouteNames.adminAuditLogs),
            ),
          ),
        ),
        if (tab == 0 && platformModule == AdminModule.connect)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: _AdminKpisAndTrends(),
            ),
          ),
        if (embeddedRoute != null && sections != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: _MobileModuleNav(
                sections: sections!,
                hubExpanded: moduleHubExpanded,
                selectedRoute: embeddedRoute!,
                onToggleHub: onToggleModuleHub ?? () {},
                onSelectRoute: onGo,
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _adminBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AdminModuleEmbeddedContent(
                    route: embeddedRoute!,
                    onShopNavigate: onShopNavigate,
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: _SearchBar(
                controller: controller,
                onChanged: onSetQuery,
                onClear: onClear,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Text(
                    tab == 0
                        ? 'All shortcuts'
                        : (tab == 1
                              ? 'Queues shortcuts'
                              : tab == 2
                              ? 'Users shortcuts'
                              : 'Config shortcuts'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _adminText,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _adminBorder),
                    ),
                    child: Text(
                      '${filteredItems.length}',
                      style: GoogleFonts.inter(
                        color: _adminTextSoft,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.crossAxisExtent;
                final crossAxisCount = w >= 1100
                    ? 5
                    : w >= 820
                    ? 4
                    : w >= 560
                    ? 3
                    : 2;
                return SliverGrid.count(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.08,
                  children: [
                    for (final it in filteredItems)
                      _ShortcutCard(
                        title: it.title,
                        subtitle: it.subtitle,
                        icon: it.icon,
                        accent: it.accent,
                        onTap: () => onGo(it.route),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.selectedTab,
    required this.onSelectTab,
    required this.sections,
    required this.onTapItem,
    required this.onLogout,
    this.embeddedModuleMode = false,
    this.moduleHubExpanded = true,
    this.selectedEmbeddedRoute,
    this.onToggleModuleHub,
  });

  final int selectedTab;
  final ValueChanged<int> onSelectTab;
  final List<_AdminNavSection> sections;
  final ValueChanged<String> onTapItem;
  final VoidCallback onLogout;
  final bool embeddedModuleMode;
  final bool moduleHubExpanded;
  final String? selectedEmbeddedRoute;
  final VoidCallback? onToggleModuleHub;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: Colors.white.withValues(alpha: 0.92),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Console',
                        style: GoogleFonts.inter(
                          color: _adminText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enterprise',
                        style: GoogleFonts.inter(
                          color: _adminTextSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _TopIconButton(icon: Icons.logout_rounded, onTap: onLogout),
              ],
            ),
          ),
          if (!embeddedModuleMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  _SideChip(
                    label: 'Home',
                    icon: Icons.grid_view_rounded,
                    selected: selectedTab == 0,
                    onTap: () => onSelectTab(0),
                  ),
                  const SizedBox(width: 8),
                  _SideChip(
                    label: 'Queues',
                    icon: Icons.pending_actions_rounded,
                    selected: selectedTab == 1,
                    onTap: () => onSelectTab(1),
                  ),
                  const SizedBox(width: 8),
                  _SideChip(
                    label: 'Users',
                    icon: Icons.people_alt_rounded,
                    selected: selectedTab == 2,
                    onTap: () => onSelectTab(2),
                  ),
                  const SizedBox(width: 8),
                  _SideChip(
                    label: 'Config',
                    icon: Icons.tune_rounded,
                    selected: selectedTab == 3,
                    onTap: () => onSelectTab(3),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: _adminBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              children: [
                for (final s in sections) ...[
                  if (embeddedModuleMode && s.hasExpandableHub) ...[
                    _SidebarHubHeader(
                      title: s.hubLabel!,
                      icon: s.hubIcon ?? s.icon,
                      accent: s.accent,
                      expanded: moduleHubExpanded,
                      onTap: onToggleModuleHub ?? () {},
                    ),
                    if (moduleHubExpanded)
                      for (final it in s.items)
                        _SidebarLink(
                          title: it.title,
                          icon: it.icon,
                          accent: it.accent,
                          selected:
                              selectedEmbeddedRoute != null &&
                              _AdminHomeScreenState._navRouteMatches(
                                it.route,
                                selectedEmbeddedRoute!,
                              ),
                          indented: true,
                          onTap: () => onTapItem(it.route),
                        ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                      child: Row(
                        children: [
                          Icon(s.icon, size: 18, color: s.accent),
                          const SizedBox(width: 8),
                          Text(
                            s.title,
                            style: GoogleFonts.inter(
                              color: _adminText,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final it in s.items)
                      _SidebarLink(
                        title: it.title,
                        icon: it.icon,
                        accent: it.accent,
                        onTap: () => onTapItem(it.route),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideChip extends StatelessWidget {
  const _SideChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : _adminTextSoft;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _adminBorder),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 78;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(icon, size: 18, color: color),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SidebarHubHeader extends StatelessWidget {
  const _SidebarHubHeader({
    required this.title,
    required this.icon,
    required this.accent,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: _adminText,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.chevron_right_rounded, color: accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.selected = false,
    this.indented = false,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool selected;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: EdgeInsets.only(left: indented ? 14 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: selected
            ? BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: accent.withValues(alpha: 0.10),
                border: Border.all(color: _adminBorder),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: _adminText,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileModuleNav extends StatelessWidget {
  const _MobileModuleNav({
    required this.sections,
    required this.hubExpanded,
    required this.selectedRoute,
    required this.onToggleHub,
    required this.onSelectRoute,
  });

  final List<_AdminNavSection> sections;
  final bool hubExpanded;
  final String selectedRoute;
  final VoidCallback onToggleHub;
  final ValueChanged<String> onSelectRoute;

  @override
  Widget build(BuildContext context) {
    final section = sections.first;
    final items = section.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(section.icon, color: section.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final it = items[i];
              final selected = _AdminHomeScreenState._navRouteMatches(
                it.route,
                selectedRoute,
              );
              return FilterChip(
                label: Text(it.title),
                selected: selected,
                onSelected: (_) => onSelectRoute(it.route),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminKpisAndTrends extends StatelessWidget {
  const _AdminKpisAndTrends();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 920;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: GoogleFonts.inter(
                color: _adminText,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            wide
                ? Row(
                    children: const [
                      Expanded(child: _KpiUsersCard()),
                      SizedBox(width: 12),
                      Expanded(child: _KpiJobsCard()),
                    ],
                  )
                : const Column(
                    children: [
                      _KpiUsersCard(),
                      SizedBox(height: 12),
                      _KpiJobsCard(),
                    ],
                  ),
          ],
        );
      },
    );
  }
}

class _KpiUsersCard extends StatelessWidget {
  const _KpiUsersCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.isAvailable
          ? FirestoreService.users().snapshots()
          : const Stream.empty(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final dealers = docs
            .where((d) => (d.data()['role'] ?? '').toString() == 'dealer')
            .length;
        final technicians = docs
            .where((d) => (d.data()['role'] ?? '').toString() == 'technician')
            .length;
        final total = docs.length;
        return _KpiCard(
          title: 'Users',
          accent: const Color(0xFF2563EB),
          value: '$total',
          lines: ['Dealers: $dealers', 'Technicians: $technicians'],
          icon: Icons.people_alt_rounded,
          sparkSource: docs
              .map((d) => d.data()['createdAt'])
              .toList(growable: false),
        );
      },
    );
  }
}

class _KpiJobsCard extends StatelessWidget {
  const _KpiJobsCard();

  @override
  Widget build(BuildContext context) {
    final since = DateTime.now().subtract(const Duration(days: 14));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.isAvailable
          ? FirestoreService.jobs()
                .where('createdAt', isGreaterThanOrEqualTo: since)
                .snapshots()
          : const Stream.empty(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final total = docs.length;
        final running = docs
            .where(
              (d) => _kRunningStatuses.contains(
                (d.data()['status'] ?? '').toString(),
              ),
            )
            .length;
        final completed = docs
            .where((d) => (d.data()['status'] ?? '').toString() == 'completed')
            .length;
        return _KpiCard(
          title: 'Jobs (14d)',
          accent: const Color(0xFFF59E0B),
          value: '$total',
          lines: ['Running: $running', 'Completed: $completed'],
          icon: Icons.work_rounded,
          sparkSource: docs
              .map((d) => d.data()['createdAt'])
              .toList(growable: false),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.accent,
    required this.value,
    required this.lines,
    required this.icon,
    required this.sparkSource,
  });

  final String title;
  final Color accent;
  final String value;
  final List<String> lines;
  final IconData icon;
  final List<dynamic> sparkSource;

  @override
  Widget build(BuildContext context) {
    final points = _bucketByDay(sparkSource, days: 14);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _adminBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.18),
                      accent.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(color: _adminBorder),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: _adminTextSoft,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        color: _adminText,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                height: 44,
                child: _Sparkline(values: points, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l,
                style: GoogleFonts.inter(
                  color: _adminTextSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV).abs();
    final dx = size.width / (values.length - 1).clamp(1, 999);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final t = span == 0 ? 0.5 : (v - minV) / span;
      final x = i * dx;
      final y = size.height - (t * (size.height - 6)) - 3;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

List<int> _bucketByDay(List<dynamic> raw, {required int days}) {
  final now = DateTime.now();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days - 1));
  final buckets = List<int>.filled(days, 0);

  for (final v in raw) {
    DateTime? dt;
    if (v is DateTime) dt = v;
    if (v is Timestamp) dt = v.toDate();
    if (dt == null) continue;
    final d = DateTime(dt.year, dt.month, dt.day);
    final idx = d.difference(start).inDays;
    if (idx >= 0 && idx < days) buckets[idx] += 1;
  }

  return buckets;
}

class _AdminV2Background extends StatelessWidget {
  const _AdminV2Background();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.6, -0.9),
            radius: 1.2,
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              const Color(0xFFEFF6FF),
              _adminBg,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onLogout,
    required this.onOpenDashboard,
    this.showLogout = true,
  });
  final VoidCallback onLogout;
  final VoidCallback onOpenDashboard;
  final bool showLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Console',
                style: GoogleFonts.inter(
                  color: _adminText,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppConstants.roleAdmin,
                style: GoogleFonts.inter(
                  color: _adminTextSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _TopIconButton(
          icon: Icons.dashboard_customize_rounded,
          onTap: onOpenDashboard,
        ),
        if (showLogout) ...[
          const SizedBox(width: 8),
          _TopIconButton(icon: Icons.logout_rounded, onTap: onLogout),
        ],
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _adminBorder),
        ),
        child: Icon(icon, color: _adminText, size: 22),
      ),
    );
  }
}

class _AdminHeroCard extends StatelessWidget {
  const _AdminHeroCard({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: _adminBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _adminText,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _adminBorder),
                ),
                child: Text(
                  'Ultra Pro',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: _adminTextSoft,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: primaryLabel,
                  icon: primaryIcon,
                  primary: true,
                  onTap: onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroButton(
                  label: secondaryLabel,
                  icon: secondaryIcon,
                  primary: false,
                  onTap: onSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = primary
        ? const [Color(0xFF60A5FA), Color(0xFF2563EB)]
        : const [Color(0xFFEFF6FF), Colors.white];
    final iconColor = primary ? Colors.white : _adminText;
    final textColor = primary ? Colors.white : _adminText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: _adminBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _adminBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _adminTextSoft),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search admin tools...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _adminTextSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _adminBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: _adminBorder),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                color: _adminText,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _adminTextSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  const _AdminBottomNav({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _adminBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            _AdminNavIcon(
              label: 'Home',
              icon: Icons.grid_view_rounded,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
            _AdminNavIcon(
              label: 'Queues',
              icon: Icons.pending_actions_rounded,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
            _AdminNavIcon(
              label: 'Users',
              icon: Icons.people_alt_rounded,
              selected: index == 2,
              onTap: () => onChanged(2),
            ),
            _AdminNavIcon(
              label: 'Config',
              icon: Icons.tune_rounded,
              selected: index == 3,
              onTap: () => onChanged(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavIcon extends StatelessWidget {
  const _AdminNavIcon({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : _adminTextSoft;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminModuleChips extends StatelessWidget {
  const _AdminModuleChips({
    required this.selected,
    required this.onSelected,
    this.allowedModules,
  });

  final AdminModule selected;
  final ValueChanged<AdminModule> onSelected;
  final List<AdminModule>? allowedModules;

  @override
  Widget build(BuildContext context) {
    final modules = allowedModules ?? AdminModule.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modules.map((m) {
        final isSel = m == selected;
        return ChoiceChip(
          label: Text(m.title),
          selected: isSel,
          onSelected: (_) => onSelected(m),
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: isSel ? AppColors.primary : _adminTextSoft,
          ),
        );
      }).toList(),
    );
  }
}

class _AdminNavSection {
  const _AdminNavSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    this.hubLabel,
    this.hubRoute,
    this.hubIcon,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final List<_AdminNavItem> items;
  final String? hubLabel;
  final String? hubRoute;
  final IconData? hubIcon;

  bool get hasExpandableHub => hubRoute != null && hubLabel != null;
}

class _AdminNavItem {
  const _AdminNavItem(
    this.title,
    this.subtitle,
    this.icon,
    this.route,
    this.accent,
  );
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color accent;
}

// V2 Navbar — premium floating glass navigation for Flutter Web.
//
// Floating glassmorphism · mega menu · magnetic hover · gradient auth CTA.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/bootstrap/firebase_auth_safe.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/widgets/brand_kit_provider.dart';
import '../../shared/widgets/public_brand_logo.dart';
import '../../core/brand/public_brand_scope.dart';
import '../v2_colors.dart';
import '../v2_glass.dart';
import '../v2_tokens.dart';
import '../v2_navbar_layout.dart';
import 'navbar_mega_bundle.dart' deferred as navbar_mega;
import 'v2_auth_nav_button.dart';
import 'v2_button.dart';
import 'v2_morph_search_bar.dart';
import 'v2_services_mega_menu.dart';

class V2Navbar extends StatefulWidget {
  const V2Navbar({
    super.key,
    this.scrollController,
    this.embedded = false,
    this.floating = false,
    this.overMedia = false,
  });

  final ScrollController? scrollController;
  final bool embedded;
  final bool floating;
  final bool overMedia;

  static const double floatingMarginTop = V2NavbarLayout.floatingMarginTop;

  static double barHeight({required bool isDesktop}) =>
      V2NavbarLayout.barHeight(isDesktop: isDesktop);

  static double totalHeight(
    BuildContext context, {
    required bool isDesktop,
    bool floating = false,
  }) =>
      V2NavbarLayout.totalHeight(
        context,
        isDesktop: isDesktop,
        floating: floating,
      );

  @override
  State<V2Navbar> createState() => _V2NavbarState();
}

class _V2NavbarState extends State<V2Navbar> {
  final _searchController = TextEditingController();
  final _productsKey = GlobalKey();
  final _servicesKey = GlobalKey();
  OverlayEntry? _megaOverlayEntry;
  OverlayEntry? _servicesOverlayEntry;
  bool _scrolled = false;
  bool _megaOpen = false;
  bool _servicesOpen = false;
  static const double _megaMenuWidth = 420;
  static const double _servicesMenuWidth = 420;
  static const double _servicesCityFlyoutWidth = 280;
  static const Duration _megaCloseDelay = Duration(milliseconds: 450);
  Timer? _megaCloseTimer;
  Timer? _servicesCloseTimer;

  static const _navLinks = [
    _NavSpec('Shop', null, Icons.storefront_rounded, hasMega: true),
    _NavSpec(
      'Services',
      RouteNames.publicServices,
      Icons.design_services_rounded,
      hasServicesMenu: true,
    ),
    _NavSpec('Connect', RouteNames.publicConnect, Icons.engineering_rounded),
    _NavSpec(
      'Calculator',
      RouteNames.publicCalculatorList,
      Icons.calculate_rounded,
    ),
    _NavSpec('About', RouteNames.publicAbout, Icons.info_outline_rounded),
    _NavSpec('Support', RouteNames.supportHome, Icons.support_agent_rounded),
  ];

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  void _onScroll() {
    final next = (widget.scrollController?.offset ?? 0) > 24;
    if (next != _scrolled && mounted) setState(() => _scrolled = next);
  }

  @override
  void dispose() {
    _megaCloseTimer?.cancel();
    _removeMegaOverlay();
    _servicesCloseTimer?.cancel();
    _removeServicesOverlay();
    widget.scrollController?.removeListener(_onScroll);
    _searchController.dispose();
    super.dispose();
  }

  void _openMega() {
    _megaCloseTimer?.cancel();
    setState(() => _megaOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMegaOverlay());
  }

  void _scheduleMegaClose() {
    _megaCloseTimer?.cancel();
    _megaCloseTimer = Timer(_megaCloseDelay, () {
      if (!mounted) return;
      _removeMegaOverlay();
      setState(() => _megaOpen = false);
    });
  }

  void _closeMegaNow() {
    _megaCloseTimer?.cancel();
    _removeMegaOverlay();
    if (mounted && _megaOpen) setState(() => _megaOpen = false);
  }

  void _cancelMegaClose() {
    _megaCloseTimer?.cancel();
  }

  void _toggleMega() {
    if (_megaOpen) {
      _closeMegaNow();
    } else {
      _openMega();
    }
  }

  void _showMegaOverlay() {
    if (!mounted || !_megaOpen) return;

    final v = V2Responsive(context);
    if (v.width < V2Breakpoints.lg) return;

    _removeMegaOverlay();

    final anchorBox =
        _productsKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) return;

    final anchorOrigin = anchorBox.localToGlobal(Offset.zero);
    final anchorSize = anchorBox.size;
    final screenW = MediaQuery.sizeOf(context).width;

    var left = anchorOrigin.dx + (anchorSize.width - _megaMenuWidth) / 2;
    left = left.clamp(8.0, screenW - _megaMenuWidth - 8);
    final top = anchorOrigin.dy + anchorSize.height - 12;

    _megaOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: MouseRegion(
              onEnter: (_) => _cancelMegaClose(),
              onExit: (_) => _scheduleMegaClose(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: _megaMenuWidth, height: 16),
                  _DeferredMegaMenu(
                    visible: true,
                    onClose: _closeMegaNow,
                    anchorWidth: _megaMenuWidth,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_megaOverlayEntry!);
  }

  void _removeMegaOverlay() {
    _megaOverlayEntry?.remove();
    _megaOverlayEntry = null;
  }

  void _openServicesMenu() {
    _servicesCloseTimer?.cancel();
    if (mounted) setState(() => _servicesOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showServicesOverlay());
  }

  void _scheduleServicesClose() {
    _servicesCloseTimer?.cancel();
    _servicesCloseTimer = Timer(_megaCloseDelay, () {
      if (!mounted) return;
      _removeServicesOverlay();
      setState(() => _servicesOpen = false);
    });
  }

  void _closeServicesNow() {
    _servicesCloseTimer?.cancel();
    _removeServicesOverlay();
    if (mounted && _servicesOpen) setState(() => _servicesOpen = false);
  }

  void _cancelServicesClose() {
    _servicesCloseTimer?.cancel();
  }

  void _showServicesOverlay() {
    if (!mounted || !_servicesOpen) return;
    final v = V2Responsive(context);
    if (v.width < V2Breakpoints.lg) return;

    _removeServicesOverlay();

    final anchorBox =
        _servicesKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) return;

    final anchorOrigin = anchorBox.localToGlobal(Offset.zero);
    final anchorSize = anchorBox.size;
    final screenW = MediaQuery.sizeOf(context).width;

    var left = anchorOrigin.dx + (anchorSize.width - _servicesMenuWidth) / 2;
    left = left.clamp(8.0, screenW - _servicesMenuWidth - _servicesCityFlyoutWidth - 16);
    final top = anchorOrigin.dy + anchorSize.height - 12;

    _servicesOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: MouseRegion(
              onEnter: (_) => _cancelServicesClose(),
              onExit: (_) => _scheduleServicesClose(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _servicesMenuWidth + _servicesCityFlyoutWidth + 8,
                    height: 16,
                  ),
                  _ServicesMenu(
                    onClose: _closeServicesNow,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_servicesOverlayEntry!);
  }

  void _removeServicesOverlay() {
    _servicesOverlayEntry?.remove();
    _servicesOverlayEntry = null;
  }

  void _submitSearch(BuildContext context) {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      context.go(RouteNames.publicStore);
      return;
    }
    context.go('${RouteNames.publicStore}?q=${Uri.encodeComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final showInlineNav = v.width >= V2Breakpoints.lg;
    final showSearch = v.width >= V2Breakpoints.md;
    final darkMode = false;

    final navContent = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.floating ? v.gutter : v.gutter,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: SizedBox(
            height: V2Navbar.barHeight(isDesktop: showInlineNav),
            child: Row(
              children: [
                SizedBox(
                  width: v.r<double>(xs: 92, sm: 104, md: 124, lg: 136),
                  child: _Logo(
                    maxWidth: v.r<double>(xs: 92, sm: 104, md: 124, lg: 136),
                    darkMode: darkMode,
                  ),
                ),
                if (showInlineNav) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    child: Center(
                      child: _InlineNav(
                        links: _navLinks,
                        darkMode: darkMode,
                        productsKey: _productsKey,
                        servicesKey: _servicesKey,
                        megaOpen: _megaOpen,
                        servicesOpen: _servicesOpen,
                        onProductsEnter: _openMega,
                        onProductsExit: _scheduleMegaClose,
                        onProductsTap: _toggleMega,
                        onDismissMega: _closeMegaNow,
                        onServicesEnter: _openServicesMenu,
                        onServicesExit: _scheduleServicesClose,
                        onDismissServices: _closeServicesNow,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (showInlineNav)
                  SizedBox(
                    width: v.r<double>(xs: 470, lg: 470, xl: 560, xxl: 620),
                    child: _NavActions(
                      showSearch: showSearch,
                      darkMode: darkMode,
                      showInlineNav: showInlineNav,
                      searchController: _searchController,
                      onSubmitSearch: () => _submitSearch(context),
                    ),
                  )
                else
                  Expanded(
                    child: _NavActions(
                      showSearch: showSearch,
                      darkMode: darkMode,
                      showInlineNav: showInlineNav,
                      searchController: _searchController,
                      onSubmitSearch: () => _submitSearch(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final shell = widget.embedded && !widget.floating
        ? navContent
        : _LiquidNavShell(
            scrolled: _scrolled,
            floating: widget.floating,
            overMedia: widget.overMedia && !_scrolled,
            child: SafeArea(bottom: false, child: navContent),
          );

    return shell;
  }
}

class _NavActions extends StatelessWidget {
  const _NavActions({
    required this.showSearch,
    required this.darkMode,
    required this.showInlineNav,
    required this.searchController,
    required this.onSubmitSearch,
  });

  final bool showSearch;
  final bool darkMode;
  final bool showInlineNav;
  final TextEditingController searchController;
  final VoidCallback onSubmitSearch;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Align(
      alignment: Alignment.centerRight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final showSearchHere = showSearch && available >= 320;
          final cartCompact = v.width < V2Breakpoints.md || available < 560;
          final authCompact = v.width < V2Breakpoints.lg;
          final searchBar = V2MorphSearchBar(
            controller: searchController,
            onSubmit: onSubmitSearch,
            compact: v.width < V2Breakpoints.lg,
          );
          final trailing = <Widget>[
            _CartButton(compact: cartCompact, darkMode: darkMode),
            const SizedBox(width: 4),
            V2AuthNavButton(compact: authCompact, darkMode: darkMode),
            if (!showInlineNav) ...[
              const SizedBox(width: 2),
              _MenuToggle(
                searchController: searchController,
                onSubmitSearch: onSubmitSearch,
                darkMode: darkMode,
              ),
            ],
          ];

          if (showInlineNav) {
            return Row(
              children: [
                if (showSearchHere)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: v.r<double>(xs: 4, md: 8),
                      ),
                      child: searchBar,
                    ),
                  ),
                ...trailing,
              ],
            );
          }

          final mobileActions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSearchHere) ...[
                SizedBox(
                  width: (available - (authCompact ? 96 : 148))
                      .clamp(120.0, 280.0),
                  child: searchBar,
                ),
                SizedBox(width: v.r<double>(xs: 4, md: 8)),
              ],
              ...trailing,
            ],
          );

          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: mobileActions,
          );
        },
      ),
    );
  }
}

class _LiquidNavShell extends StatelessWidget {
  const _LiquidNavShell({
    required this.child,
    required this.scrolled,
    required this.floating,
    required this.overMedia,
  });

  final Widget child;
  final bool scrolled;
  final bool floating;
  final bool overMedia;

  @override
  Widget build(BuildContext context) {
    final bgAlpha = scrolled ? 0.86 : 0.82;
    final borderColor = V2Colors.inkSaaS.withValues(
      alpha: scrolled ? 0.24 : 0.12,
    );

    return v2BackdropGlass(
      blurSigma: 24,
      backgroundColor: Colors.white.withValues(alpha: bgAlpha),
      border: Border(bottom: BorderSide(color: borderColor, width: 0.6)),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: scrolled ? 0.4 : 0.62),
          blurRadius: scrolled ? 18 : 30,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: const Color(0xFF020617).withValues(alpha: scrolled ? 0.07 : 0.03),
          blurRadius: scrolled ? 18 : 24,
          offset: const Offset(0, 8),
        ),
      ],
      child: AnimatedContainer(
          duration: V2.dMed,
          curve: V2.eOut,
          decoration: const BoxDecoration(),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.6),
                        const Color(0xFFF8FAFC).withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        V2Colors.inkSaaS.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
    );
  }
}

class _NavSpec {
  const _NavSpec(
    this.label,
    this.route,
    this.icon, {
    this.hasMega = false,
    this.hasServicesMenu = false,
  });
  final String label;
  final String? route;
  final IconData icon;
  final bool hasMega;
  final bool hasServicesMenu;
}

class _InlineNav extends StatelessWidget {
  const _InlineNav({
    required this.links,
    required this.darkMode,
    required this.productsKey,
    required this.servicesKey,
    required this.megaOpen,
    required this.servicesOpen,
    required this.onProductsEnter,
    required this.onProductsExit,
    required this.onProductsTap,
    required this.onDismissMega,
    required this.onServicesEnter,
    required this.onServicesExit,
    required this.onDismissServices,
  });

  final List<_NavSpec> links;
  final bool darkMode;
  final GlobalKey productsKey;
  final GlobalKey servicesKey;
  final bool megaOpen;
  final bool servicesOpen;
  final VoidCallback onProductsEnter;
  final VoidCallback onProductsExit;
  final VoidCallback onProductsTap;
  final VoidCallback onDismissMega;
  final VoidCallback onServicesEnter;
  final VoidCallback onServicesExit;
  final VoidCallback onDismissServices;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final link in links)
            if (link.hasMega)
              _NavLinkItem(
                key: productsKey,
                label: link.label,
                icon: link.icon,
                darkMode: darkMode,
                active: megaOpen || _isStoreActive(currentPath),
                hasDropdown: true,
                dropdownOpen: megaOpen,
                onEnter: onProductsEnter,
                onExit: onProductsExit,
                onTap: onProductsTap,
              )
            else if (link.hasServicesMenu)
              _NavLinkItem(
                key: servicesKey,
                label: link.label,
                icon: link.icon,
                darkMode: darkMode,
                active: servicesOpen || _isActive(currentPath, link.route!),
                hasDropdown: true,
                dropdownOpen: servicesOpen,
                onEnter: onServicesEnter,
                onExit: onServicesExit,
                onTap: () {
                  onDismissMega();
                  onDismissServices();
                  context.go(link.route!);
                },
              )
            else
              _NavLinkItem(
                label: link.label,
                icon: link.icon,
                darkMode: darkMode,
                active: _isActive(currentPath, link.route!),
                onEnter: onDismissMega,
                onTap: () {
                  onDismissMega();
                  context.go(link.route!);
                },
              ),
        ],
      ),
    );
  }

  bool _isActive(String currentPath, String route) {
    if (route == RouteNames.publicHome) return currentPath == '/';
    return currentPath == route || currentPath.startsWith('$route/');
  }

  bool _isStoreActive(String currentPath) =>
      currentPath == RouteNames.publicStore ||
      currentPath.startsWith('${RouteNames.publicStore}/');
}

class _ServicesMenu extends StatelessWidget {
  const _ServicesMenu({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return V2ServicesMegaMenu(
      visible: true,
      onClose: onClose,
      anchorWidth: 420,
      cityFlyoutWidth: 280,
    );
  }
}

class _NavLinkItem extends StatefulWidget {
  const _NavLinkItem({
    super.key,
    required this.label,
    required this.icon,
    required this.darkMode,
    required this.active,
    this.hasDropdown = false,
    this.dropdownOpen = false,
    this.onTap,
    this.onEnter,
    this.onExit,
  });

  final String label;
  final IconData icon;
  final bool darkMode;
  final bool active;
  final bool hasDropdown;
  final bool dropdownOpen;
  final VoidCallback? onTap;
  final VoidCallback? onEnter;
  final VoidCallback? onExit;

  @override
  State<_NavLinkItem> createState() => _NavLinkItemState();
}

class _NavLinkItemState extends State<_NavLinkItem> {
  bool _hover = false;
  Offset _magnetic = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final selected = widget.active || widget.dropdownOpen;
    final primary = widget.darkMode ? Colors.white : V2Colors.inkSaaS;
    final muted = widget.darkMode
        ? Colors.white.withValues(alpha: 0.72)
        : V2Colors.inkMutedSaaS;
    final color = selected ? primary : (_hover ? primary : muted);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hover = true);
        widget.onEnter?.call();
      },
      onExit: (_) {
        setState(() {
          _hover = false;
          _magnetic = Offset.zero;
        });
        widget.onExit?.call();
      },
      onHover: (e) {
        if (!mounted) return;
        setState(() {
          _magnetic = Offset(
            (e.localPosition.dx - 40).clamp(-1.5, 1.5),
            (e.localPosition.dy - 16).clamp(-0.8, 0.8),
          );
        });
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Transform.translate(
          offset: _hover ? _magnetic : Offset.zero,
          child: AnimatedContainer(
            duration: V2.d,
            curve: V2.eOut,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: V2FontStyles.inter(
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: color,
                        letterSpacing: -0.05,
                      ),
                    ),
                    if (widget.hasDropdown) ...[
                      const SizedBox(width: 3),
                      AnimatedRotation(
                        turns: widget.dropdownOpen ? 0.5 : 0,
                        duration: V2.d,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: V2.dMed,
                  curve: V2.eOut,
                  height: 1.5,
                  width: selected || _hover ? (selected ? 28 : 18) : 0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: selected
                        ? primary
                        : primary.withValues(
                            alpha: widget.darkMode ? 0.5 : 0.38,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.maxWidth, required this.darkMode});
  final double maxWidth;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final content = PublicBrandScope.contentOf(context);
    final kit = BrandKitProvider.of(context);
    final hasLandscape =
        (kit.logoColorUrl?.trim().isNotEmpty ?? false) ||
        (kit.logoWhiteUrl?.trim().isNotEmpty ?? false);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(RouteNames.publicHome),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            height: 30,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              child: hasLandscape
                  ? PublicBrandLogo(
                      size: 30,
                      showName: false,
                      forDarkBackground: darkMode,
                      landscape: true,
                      maxLayoutWidth: maxWidth,
                    )
                  : _LogoFallback(
                      name: content.companyShortName,
                      darkMode: darkMode,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.name, required this.darkMode});
  final String name;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: darkMode ? Colors.white : V2Colors.inkSaaS,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: (darkMode ? Colors.white : V2Colors.inkSaaS).withValues(
                  alpha: 0.12,
                ),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.hub_rounded,
            color: darkMode ? V2Colors.inkSaaS : Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V2FontStyles.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: darkMode ? Colors.white : V2Colors.inkSaaS,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientAuthButton extends StatefulWidget {
  const _GradientAuthButton({required this.compact, required this.darkMode});
  final bool compact;
  final bool darkMode;

  @override
  State<_GradientAuthButton> createState() => _GradientAuthButtonState();
}

class _GradientAuthButtonState extends State<_GradientAuthButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const label = 'Login / Register';
    const route = RouteNames.login;

    return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go(route),
            child: AnimatedContainer(
              duration: V2.dFast,
              curve: V2.eOut,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 12 : 16,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(V2.rFull),
                color: widget.darkMode
                    ? (_hover
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9))
                    : (_hover ? const Color(0xFF1D1D1F) : V2Colors.inkSaaS),
                boxShadow: [
                  BoxShadow(
                    color: (widget.darkMode ? Colors.white : V2Colors.inkSaaS)
                        .withValues(alpha: _hover ? 0.16 : 0.1),
                    blurRadius: _hover ? 14 : 8,
                    offset: Offset(0, _hover ? 6 : 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 17,
                    color: widget.darkMode ? V2Colors.inkSaaS : Colors.white,
                  ),
                  if (!widget.compact) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: V2FontStyles.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.darkMode
                            ? V2Colors.inkSaaS
                            : Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
  }
}

class _DeferredMegaMenu extends StatefulWidget {
  const _DeferredMegaMenu({
    required this.visible,
    required this.onClose,
    required this.anchorWidth,
  });

  final bool visible;
  final VoidCallback onClose;
  final double anchorWidth;

  @override
  State<_DeferredMegaMenu> createState() => _DeferredMegaMenuState();
}

class _DeferredMegaMenuState extends State<_DeferredMegaMenu> {
  static Future<void>? _libraryFuture;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant _DeferredMegaMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !_ready) _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    _libraryFuture ??= navbar_mega.loadLibrary();
    await _libraryFuture;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    if (!_ready) {
      return const SizedBox(
        width: 420,
        height: 120,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return navbar_mega.buildNavbarMegaMenu(
      visible: widget.visible,
      onClose: widget.onClose,
      anchorWidth: widget.anchorWidth,
    );
  }
}

class _CartButton extends StatefulWidget {
  const _CartButton({required this.compact, required this.darkMode});
  final bool compact;
  final bool darkMode;

  @override
  State<_CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<_CartButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go(RouteNames.publicCart),
            child: AnimatedContainer(
                duration: V2.dFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _hover
                      ? (widget.darkMode ? Colors.white : V2Colors.inkSaaS)
                            .withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.0),
                  borderRadius: BorderRadius.circular(V2.rFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 20,
                      color: _hover
                          ? (widget.darkMode
                                ? Colors.white
                                : V2Colors.inkSaaS)
                          : (widget.darkMode
                                ? Colors.white.withValues(alpha: 0.9)
                                : V2Colors.inkSaaS),
                    ),
                    if (!widget.compact) ...[
                      const SizedBox(width: 5),
                      Text(
                        'Cart',
                        style: V2FontStyles.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _hover
                              ? (widget.darkMode
                                    ? Colors.white
                                    : V2Colors.inkSaaS)
                              : (widget.darkMode
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : V2Colors.inkSaaS),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _MenuToggle extends StatelessWidget {
  const _MenuToggle({
    required this.searchController,
    required this.onSubmitSearch,
    required this.darkMode,
  });

  final TextEditingController searchController;
  final VoidCallback onSubmitSearch;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: (darkMode ? Colors.white : V2Colors.inkSaaS)
              .withValues(alpha: darkMode ? 0.1 : 0.06),
          hoverColor: (darkMode ? Colors.white : V2Colors.inkSaaS).withValues(
            alpha: darkMode ? 0.16 : 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V2.rFull),
          ),
        ),
        icon: Icon(
          Icons.menu_rounded,
          color: darkMode ? Colors.white : V2Colors.inkSaaS,
        ),
        onPressed: () => _openSheet(context),
        tooltip: 'Menu',
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (_) => _MobileMenu(
        searchController: searchController,
        onSubmitSearch: onSubmitSearch,
      ),
    );
  }
}

Stream<User?> _safeAuthStream() => FirebaseAuthSafe.authStateChanges();

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({
    required this.searchController,
    required this.onSubmitSearch,
  });

  final TextEditingController searchController;
  final VoidCallback onSubmitSearch;

  static const _links = [
    _NavSpec('Shop', RouteNames.publicStore, Icons.storefront_rounded),
    _NavSpec(
      'Services',
      RouteNames.publicServices,
      Icons.design_services_rounded,
    ),
    _NavSpec('Connect', RouteNames.publicConnect, Icons.engineering_rounded),
    _NavSpec(
      'Calculator',
      RouteNames.publicCalculatorList,
      Icons.calculate_rounded,
    ),
    _NavSpec('About', RouteNames.publicAbout, Icons.info_outline_rounded),
    _NavSpec('Support', RouteNames.supportHome, Icons.support_agent_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Container(
      height: h * 0.92,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(V2.rXl)),
        boxShadow: V2Colors.paperHigh,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const PublicBrandLogo(
                    size: 32,
                    showName: false,
                    landscape: true,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: V2MorphSearchBar(
                controller: searchController,
                onSubmit: () {
                  Navigator.pop(context);
                  onSubmitSearch();
                },
                compact: true,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: V2Colors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final item in _links)
                    _MobileItem(label: item.label, route: item.route!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: StreamBuilder<User?>(
                stream: _safeAuthStream(),
                builder: (context, snap) {
                  final loggedIn = snap.hasError ? false : snap.data != null;
                  return V2Button(
                    label: loggedIn ? 'My account' : 'Login / Register',
                    variant: V2BtnVariant.primary,
                    size: V2BtnSize.lg,
                    expand: true,
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(
                        loggedIn ? RouteNames.accountHome : RouteNames.login,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileItem extends StatelessWidget {
  const _MobileItem({required this.label, required this.route});
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
      borderRadius: BorderRadius.circular(V2.rMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: V2FontStyles.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: V2Colors.inkSaaS,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

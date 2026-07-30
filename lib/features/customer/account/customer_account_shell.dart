import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../shared/router/navigator_key.dart';
import '../../web_public/state/public_cart.dart';
import '../../web_public/v2/v2_animate_export.dart';
import '../../web_public/v2/v2_colors.dart';
import '../../web_public/v2/v2_font_styles.dart';
import '../../web_public/v2/v2_text.dart';
import '../../web_public/v2/v2_tokens.dart';
import '../../web_public/v2/widgets/navbar_mega_bundle.dart' deferred as navbar_mega;
import '../../web_public/v2/widgets/v2_footer.dart';
import '../../web_public/v2/widgets/v2_page_container.dart';
import '../../web_public/v2/widgets/v2_services_mega_menu.dart';
import '../../web_public/widgets/public_nav_menus.dart';

enum CustomerAccountTab {
  home,
  shop,
  services,
  connect,
  calculator,
  about,
  support,
  cart,
  account,
}

/// Public account-area shell — floating bottom menu (no top navbar).
class CustomerAccountShell extends StatefulWidget {
  const CustomerAccountShell({
    super.key,
    required this.activeTab,
    required this.child,
    this.title,
    this.subtitle,
    this.actions,
    this.showFooter = true,
    this.maxWidth = V2.maxMedium,
    this.stickyBottom,
    this.showBackButton = true,
    this.backFallback,
  });

  final CustomerAccountTab activeTab;
  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showFooter;
  final double maxWidth;
  final Widget? stickyBottom;
  /// Shows a back control above page content (default on).
  final bool showBackButton;
  /// Used when the browser history stack cannot pop.
  final String? backFallback;

  @override
  State<CustomerAccountShell> createState() => _CustomerAccountShellState();
}

class _CustomerAccountShellState extends State<CustomerAccountShell> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Active tab highlighted by global PublicFloatingMenu via route path.
    final _ = widget.activeTab;
    final v = V2Responsive(context);
    final safe = MediaQuery.paddingOf(context).bottom;
    // Global PublicFloatingMenu sits below sticky strips (~100 + safe).
    final menuReserve = 100.0 + safe;
    final bottomPad = widget.stickyBottom != null ? 180.0 + safe : menuReserve;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          const AccountAmbientMesh(),
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: v.r(xs: 20, lg: 28))),
              SliverToBoxAdapter(
                child: V2PageContainer(
                  maxWidth: widget.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showBackButton)
                        Padding(
                          padding: EdgeInsets.only(bottom: widget.title != null ? 12 : 16),
                          child: AccountBackButton(fallback: widget.backFallback),
                        ).animate().fadeIn(duration: 280.ms).slideX(begin: -0.04, end: 0),
                      if (widget.title != null)
                        AccountPageHeader(
                          title: widget.title!,
                          subtitle: widget.subtitle,
                          actions: widget.actions,
                        ).animate().fadeIn(duration: 360.ms).slideY(begin: 0.06, end: 0),
                      widget.child,
                      SizedBox(height: bottomPad),
                    ],
                  ),
                ),
              ),
              if (widget.showFooter) const SliverToBoxAdapter(child: V2Footer()),
            ],
          ),
          if (widget.stickyBottom != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: menuReserve,
              child: widget.stickyBottom!,
            ),
        ],
      ),
    );
  }
}

/// Navigates back via history, or [fallback] / home when there is no stack.
void accountNavigateBack(BuildContext context, {String? fallback}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback ?? RouteNames.publicHome);
}

class AccountBackButton extends StatefulWidget {
  const AccountBackButton({
    super.key,
    this.fallback,
    this.label = 'Back',
  });

  final String? fallback;
  final String label;

  @override
  State<AccountBackButton> createState() => _AccountBackButtonState();
}

class _AccountBackButtonState extends State<AccountBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => accountNavigateBack(context, fallback: widget.fallback),
          child: AnimatedScale(
            scale: _hover ? 1.03 : 1,
            duration: const Duration(milliseconds: 160),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _hover ? 0.95 : 0.82),
                borderRadius: BorderRadius.circular(980),
                border: Border.all(color: V2Colors.border.withValues(alpha: 0.9)),
                boxShadow: _hover
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18, color: V2Colors.ink),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: V2FontStyles.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: V2Colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountPageHeader extends StatelessWidget {
  const AccountPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: V2Text.h2(context).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class AccountGlassCard extends StatelessWidget {
  const AccountGlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AccountEmptyState extends StatelessWidget {
  const AccountEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: V2Colors.plasma.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 34, color: V2Colors.fgSubtle),
            ),
            const SizedBox(height: 20),
            Text(title, style: V2FontStyles.inter(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: V2Text.small().copyWith(color: V2Colors.fgSubtle, height: 1.45)),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: V2Colors.ink,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerAccountBottomBar extends StatefulWidget {
  const CustomerAccountBottomBar({
    super.key,
    required this.active,
    this.router,
  });

  final CustomerAccountTab active;
  final GoRouter? router;

  @override
  State<CustomerAccountBottomBar> createState() =>
      _CustomerAccountBottomBarState();
}

class _CustomerAccountBottomBarState extends State<CustomerAccountBottomBar> {
  static const _megaWidth = 420.0;
  static const _cityFlyoutWidth = 280.0;
  static const _closeDelay = Duration(milliseconds: 220);

  final _shopLink = LayerLink();
  final _servicesLink = LayerLink();

  Timer? _shopCloseTimer;
  Timer? _servicesCloseTimer;
  bool _shopLibReady = false;
  bool _shopOpen = false;
  bool _servicesOpen = false;

  static const _items = <({
    CustomerAccountTab tab,
    IconData icon,
    String label,
    String? route,
    bool cartBadge,
    bool opensShopMenu,
    bool opensServicesMenu,
  })>[
    (
      tab: CustomerAccountTab.home,
      icon: Icons.home_rounded,
      label: 'Home',
      route: RouteNames.publicHome,
      cartBadge: false,
      opensShopMenu: false,
      opensServicesMenu: false,
    ),
    (
      tab: CustomerAccountTab.shop,
      icon: Icons.storefront_rounded,
      label: 'Shop',
      route: null,
      cartBadge: false,
      opensShopMenu: true,
      opensServicesMenu: false,
    ),
    (
      tab: CustomerAccountTab.services,
      icon: Icons.design_services_rounded,
      label: 'Services',
      route: null,
      cartBadge: false,
      opensShopMenu: false,
      opensServicesMenu: true,
    ),
    (
      tab: CustomerAccountTab.connect,
      icon: Icons.engineering_rounded,
      label: 'Connect',
      route: RouteNames.publicConnect,
      cartBadge: false,
      opensShopMenu: false,
      opensServicesMenu: false,
    ),
    (
      tab: CustomerAccountTab.calculator,
      icon: Icons.calculate_rounded,
      label: 'Calc',
      route: RouteNames.publicCalculatorList,
      cartBadge: false,
      opensShopMenu: false,
      opensServicesMenu: false,
    ),
    (
      tab: CustomerAccountTab.about,
      icon: Icons.info_outline_rounded,
      label: 'About',
      route: RouteNames.publicAbout,
      cartBadge: false,
      opensShopMenu: false,
      opensServicesMenu: false,
    ),
    (
      tab: CustomerAccountTab.support,
      icon: Icons.support_agent_rounded,
      label: 'Support',
      route: RouteNames.supportHome,
      cartBadge: false,
      opensShopMenu: false,
      opensServicesMenu: false,
    ),
    (
      tab: CustomerAccountTab.cart,
      icon: Icons.shopping_cart_rounded,
      label: 'Cart',
      route: RouteNames.publicCart,
      cartBadge: true,
      opensShopMenu: false,
      opensServicesMenu: false,
    ),
    (
      tab: CustomerAccountTab.account,
      icon: Icons.person_rounded,
      label: 'Account',
      route: RouteNames.accountHome,
      cartBadge: false,
      opensShopMenu: false,
      opensServicesMenu: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Load shop mega chunk only when first opened (faster idle).
  }

  @override
  void dispose() {
    _shopCloseTimer?.cancel();
    _servicesCloseTimer?.cancel();
    super.dispose();
  }

  bool _useHoverMenus(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= V2Breakpoints.md;

  GoRouter _router() {
    final injected = widget.router;
    if (injected != null) return injected;
    return GoRouter.of(context);
  }

  /// Navigator under GoRouter — MaterialApp.builder context has no Navigator.
  BuildContext? _navContext() {
    return rootNavigatorKey.currentContext ??
        (_router().routerDelegate.navigatorKey.currentContext);
  }

  void _go(String route) {
    _closeMenus();
    _router().go(route);
  }

  Future<void> _openShopSheet() async {
    final ctx = _navContext();
    if (ctx == null || !ctx.mounted) return;
    await showPublicShopMenu(ctx);
  }

  Future<void> _openServicesSheet() async {
    final ctx = _navContext();
    if (ctx == null || !ctx.mounted) return;
    await showPublicServicesMenu(ctx);
  }

  void _openShopMenu({required bool fromHover}) {
    if (!_useHoverMenus(context)) {
      if (!fromHover) _openShopSheet();
      return;
    }
    if (_shopOpen) {
      _cancelMenuClose();
      return;
    }
    _shopCloseTimer?.cancel();
    _servicesCloseTimer?.cancel();
    if (!_shopLibReady) {
      navbar_mega.loadLibrary().then((_) {
        if (mounted) setState(() => _shopLibReady = true);
      });
    }
    setState(() {
      _shopOpen = true;
      _servicesOpen = false;
    });
  }

  void _openServicesMenu({required bool fromHover}) {
    if (!_useHoverMenus(context)) {
      if (!fromHover) _openServicesSheet();
      return;
    }
    if (_servicesOpen) {
      _cancelMenuClose();
      return;
    }
    _shopCloseTimer?.cancel();
    _servicesCloseTimer?.cancel();
    setState(() {
      _servicesOpen = true;
      _shopOpen = false;
    });
  }

  void _scheduleShopClose() {
    _shopCloseTimer?.cancel();
    _shopCloseTimer = Timer(_closeDelay, () {
      if (mounted && _shopOpen) setState(() => _shopOpen = false);
    });
  }

  void _scheduleServicesClose() {
    _servicesCloseTimer?.cancel();
    _servicesCloseTimer = Timer(_closeDelay, () {
      if (mounted && _servicesOpen) setState(() => _servicesOpen = false);
    });
  }

  void _cancelMenuClose() {
    _shopCloseTimer?.cancel();
    _servicesCloseTimer?.cancel();
  }

  void _closeMenus() {
    _cancelMenuClose();
    if (!mounted) return;
    if (_shopOpen || _servicesOpen) {
      setState(() {
        _shopOpen = false;
        _servicesOpen = false;
      });
    }
  }

  void _onItemTap({
    required bool opensShopMenu,
    required bool opensServicesMenu,
    required String? route,
  }) {
    if (opensShopMenu) {
      if (_useHoverMenus(context)) {
        if (_shopOpen) {
          _closeMenus();
        } else {
          _openShopMenu(fromHover: false);
        }
      } else {
        _openShopSheet();
      }
      return;
    }
    if (opensServicesMenu) {
      if (_useHoverMenus(context)) {
        if (_servicesOpen) {
          _closeMenus();
        } else {
          _openServicesMenu(fromHover: false);
        }
      } else {
        _openServicesSheet();
      }
      return;
    }
    if (route != null) _go(route);
  }

  Widget _buildMegaPanel({required bool isShop}) {
    final screen = MediaQuery.sizeOf(context);
    final maxH = (screen.height * 0.78).clamp(320.0, 720.0);

    final megaBody = isShop
        ? (_shopLibReady
            ? navbar_mega.buildNavbarMegaMenu(
                visible: true,
                onClose: _closeMenus,
                anchorWidth: _megaWidth,
              )
            : const Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ))
        : V2ServicesMegaMenu(
            visible: true,
            onClose: _closeMenus,
            anchorWidth: _megaWidth,
            cityFlyoutWidth: _cityFlyoutWidth,
          );

    return MouseRegion(
      onEnter: (_) => _cancelMenuClose(),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _closeMenus,
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 22,
                        color: V2Colors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                megaBody,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final laptop = screenW >= V2Breakpoints.md;
    final desktop = screenW >= V2Breakpoints.lg;
    final barMax = laptop
        ? (screenW - 40).clamp(640.0, 1080.0)
        : (screenW - 24).clamp(280.0, 560.0);
    final barHeight = laptop ? 76.0 : 68.0;
    final fitAll = barMax >= (desktop ? 820 : 700);

    final bar = Container(
      height: barHeight,
      constraints: BoxConstraints(maxWidth: barMax),
      decoration: BoxDecoration(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(980),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListenableBuilder(
        listenable: PublicCart.instance,
        builder: (context, _) {
          final cartCount = PublicCart.instance.itemCount;
          final children = <Widget>[
            for (final item in _items)
              Builder(
                builder: (context) {
                  final tile = _BottomItem(
                    icon: item.icon,
                    label: item.label,
                    selected: widget.active == item.tab ||
                        (item.opensShopMenu && _shopOpen) ||
                        (item.opensServicesMenu && _servicesOpen),
                    badge:
                        item.cartBadge && cartCount > 0 ? '$cartCount' : null,
                    expanded: fitAll,
                    compact: !laptop,
                    showUpArrow: item.opensShopMenu || item.opensServicesMenu,
                    menuOpen: (item.opensShopMenu && _shopOpen) ||
                        (item.opensServicesMenu && _servicesOpen),
                    onTap: () => _onItemTap(
                      opensShopMenu: item.opensShopMenu,
                      opensServicesMenu: item.opensServicesMenu,
                      route: item.route,
                    ),
                    onHoverEnter: item.opensShopMenu
                        ? () => _openShopMenu(fromHover: true)
                        : item.opensServicesMenu
                            ? () => _openServicesMenu(fromHover: true)
                            : _closeMenus,
                  );
                  if (item.opensShopMenu) {
                    return CompositedTransformTarget(
                      link: _shopLink,
                      child: tile,
                    );
                  }
                  if (item.opensServicesMenu) {
                    return CompositedTransformTarget(
                      link: _servicesLink,
                      child: tile,
                    );
                  }
                  return tile;
                },
              ),
          ];

          return ClipRRect(
            borderRadius: BorderRadius.circular(980),
            child: fitAll
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 12 : 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(child: children[i]),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: children.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 2),
                    itemBuilder: (_, i) => children[i],
                  ),
          );
        },
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(laptop ? 20 : 12, 0, laptop ? 20 : 12, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: MouseRegion(
            onEnter: (_) => _cancelMenuClose(),
            onExit: (_) {
              if (_shopOpen) _scheduleShopClose();
              if (_servicesOpen) _scheduleServicesClose();
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: barMax),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  bar,
                  if (_shopOpen)
                    CompositedTransformFollower(
                      link: _shopLink,
                      showWhenUnlinked: false,
                      targetAnchor: Alignment.topCenter,
                      followerAnchor: Alignment.bottomCenter,
                      offset: const Offset(0, -10),
                      child: _buildMegaPanel(isShop: true),
                    ),
                  if (_servicesOpen)
                    CompositedTransformFollower(
                      link: _servicesLink,
                      showWhenUnlinked: false,
                      // Main services panel centered on the tab; city flyout opens to the right.
                      targetAnchor: Alignment.topCenter,
                      followerAnchor: Alignment.bottomLeft,
                      offset: Offset(-_megaWidth / 2, -10),
                      child: _buildMegaPanel(isShop: false),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatefulWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.expanded = false,
    this.compact = true,
    this.showUpArrow = false,
    this.menuOpen = false,
    this.onHoverEnter,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final bool expanded;
  final bool compact;
  final bool showUpArrow;
  final bool menuOpen;
  final VoidCallback? onHoverEnter;

  @override
  State<_BottomItem> createState() => _BottomItemState();
}

/// Lightweight tile — avoid per-item AnimationControllers / shadows on web.
class _BottomItemState extends State<_BottomItem> {
  bool _hover = false;

  bool get _active => widget.selected || _hover || widget.menuOpen;

  @override
  Widget build(BuildContext context) {
    final color = _active ? V2Colors.ember : const Color(0xFF6B7280);
    final iconSize = widget.compact ? 20.0 : 21.0;
    final labelSize = widget.compact ? 9.5 : 10.5;
    final minW = widget.compact ? 54.0 : 68.0;

    final content = ColoredBox(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.compact ? 34 : 36,
                height: widget.compact ? 34 : 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected || widget.menuOpen
                      ? V2Colors.ember.withValues(alpha: 0.14)
                      : _hover
                          ? V2Colors.ember.withValues(alpha: 0.08)
                          : Colors.transparent,
                ),
                child: Icon(widget.icon, size: iconSize, color: color),
              ),
              if (widget.badge != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: V2Colors.ember,
                      borderRadius: BorderRadius.circular(980),
                    ),
                    child: Text(
                      widget.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: V2FontStyles.inter(
                    fontSize: labelSize,
                    fontWeight: _active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    height: 1.05,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (widget.showUpArrow)
                Icon(
                  widget.menuOpen
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  size: 12,
                  color: color,
                ),
            ],
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
        widget.onHoverEnter?.call();
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.expanded ? content : SizedBox(width: minW, child: content),
      ),
    );
  }
}

class AccountAmbientMesh extends StatelessWidget {
  const AccountAmbientMesh({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: V2Colors.plasma.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: V2Colors.ember.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/seo/web_seo_binder.dart';
import '../core/theme/app_theme_export.dart';
import '../features/web_public/widgets/public_floating_menu.dart';
import '../shared/models/brand_kit_model.dart';
import '../shared/widgets/brand_kit_provider.dart';

Widget buildWebMaterialApp({required GoRouter router, Key? routerKey}) {
  const kit = BrandKitModel();
  return BrandKitProvider(
    kit: kit,
    child: MaterialApp.router(
      key: routerKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(kit),
      routerConfig: router,
      builder: (context, child) {
        final content = SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: child ?? const SizedBox.shrink(),
        );
        final bound = kIsWeb ? WebSeoBinder(router: router, child: content) : content;
        // MaterialApp.builder sits ABOVE GoRouter's nav InheritedGoRouter.
        // Re-provide it so the floating menu can context.go / open sheets.
        return InheritedGoRouter(
          goRouter: router,
          child: _PublicMenuHost(router: router, child: bound),
        );
      },
    ),
  );
}

/// Injects the same floating menu on every public page (not admin / special docks).
class _PublicMenuHost extends StatefulWidget {
  const _PublicMenuHost({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_PublicMenuHost> createState() => _PublicMenuHostState();
}

class _PublicMenuHostState extends State<_PublicMenuHost> {
  String _path = '/';
  bool _routeListenScheduled = false;

  static bool _showsGlobalMenu(String path) {
    if (path.startsWith('/admin')) return false;
    // These pages own a custom strip above the menu (price / buy bar).
    if (path.startsWith('/calculator')) return false;
    if (path.startsWith('/product')) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _path = _readPath();
    widget.router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didUpdateWidget(covariant _PublicMenuHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
      widget.router.routerDelegate.addListener(_onRouteChanged);
      _path = _readPath();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  String _readPath() {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '/';
    }
  }

  void _onRouteChanged() {
    // GoRouter notifies during Router restore/build — never setState synchronously.
    if (_routeListenScheduled) return;
    _routeListenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _routeListenScheduled = false;
      if (!mounted) return;
      final next = _readPath();
      if (next == _path) return;
      setState(() => _path = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showsGlobalMenu(_path)) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PublicFloatingMenu(
            active: PublicFloatingMenu.tabForPath(_path),
            router: widget.router,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/web_material_app.dart';
import '../../core/constants/route_names.dart';
import '../../features/web_public/pages/home/home_shell_bundle.dart' deferred as home_shell;
import 'bundles/web_router_full_bundle.dart' deferred as web_router_full;
import 'deferred_go_route.dart';
import 'home_cold_start_placeholder.dart';
import 'navigator_key.dart';

/// Home-only GoRouter; full routes load on first navigation away from `/`.
class WebRouterApp extends StatefulWidget {
  const WebRouterApp({super.key});

  @override
  State<WebRouterApp> createState() => _WebRouterAppState();
}

class _WebRouterAppState extends State<WebRouterApp> {
  bool _isFullRouter = false;
  bool _upgrading = false;
  Future<void>? _upgradeFuture;
  int _routerGeneration = 0;
  late GoRouter _router = _minimalRouter();

  static String _browserLocation() {
    final uri = Uri.base;
    final path = uri.path.isEmpty ? RouteNames.publicHome : uri.path;
    if (!uri.hasQuery) return path;
    return '$path?${uri.query}';
  }

  static GoRouter _minimalRouter() {
    final location = _browserLocation();
    final startOnHome = location == RouteNames.publicHome;

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: startOnHome ? RouteNames.publicHome : location,
      routes: [
        GoRoute(
          path: RouteNames.publicHome,
          name: 'publicHome',
          pageBuilder: (context, state) => deferredPage(
            state,
            load: home_shell.loadLibrary,
            build: (context, state) => home_shell.buildPublicHome(),
            loading: const HomeColdStartPlaceholder(),
            errorLabel: 'Could not load home page.',
          ),
        ),
        GoRoute(
          path: '/:rest(.*)',
          name: 'routerUpgrade',
          builder: (context, state) => _RouterUpgradePage(
            location: state.uri.toString(),
            onUpgrade: _WebRouterAppState._sharedUpgrade,
          ),
        ),
      ],
    );
  }

  static _WebRouterAppState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  static Future<void> _sharedUpgrade(String location) {
    final state = _instance;
    if (state == null) return Future.value();
    return state._ensureFullRouter(location);
  }

  Future<void> _ensureFullRouter(String location) {
    if (_isFullRouter) {
      _router.go(location);
      return Future.value();
    }
    return _upgradeFuture ??= _upgradeToFullRouter(location);
  }

  Future<void> _upgradeToFullRouter(String location) async {
    if (_upgrading) {
      await _upgradeFuture;
      return;
    }
    _upgrading = true;
    await web_router_full.loadLibrary();
    if (!mounted) return;
    setState(() {
      _isFullRouter = true;
      _routerGeneration++;
      _router = web_router_full.createFullWebRouter(initialLocation: location);
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildWebMaterialApp(
      router: _router,
      routerKey: ValueKey(_routerGeneration),
    );
  }
}

class _RouterUpgradePage extends StatefulWidget {
  const _RouterUpgradePage({
    required this.location,
    required this.onUpgrade,
  });

  final String location;
  final Future<void> Function(String location) onUpgrade;

  @override
  State<_RouterUpgradePage> createState() => _RouterUpgradePageState();
}

class _RouterUpgradePageState extends State<_RouterUpgradePage> {
  @override
  void initState() {
    super.initState();
    widget.onUpgrade(widget.location);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF070A12),
      body: SizedBox.expand(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home_cold_start_placeholder.dart';

typedef DeferredLoad = Future<void> Function();
typedef DeferredPageBuilder = Widget Function(BuildContext context, GoRouterState state);

/// GoRouter page that loads a deferred library before building the route widget.
Page<void> deferredPage(
  GoRouterState state, {
  required DeferredLoad load,
  required DeferredPageBuilder build,
  Widget? loading,
  String? errorLabel,
}) {
  return MaterialPage<void>(
    key: state.pageKey,
    child: DeferredRouteShell(
      load: load,
      loading: loading ?? const HomeColdStartPlaceholder(),
      errorLabel: errorLabel ?? 'Could not load this page.',
      builder: (context) => build(context, state),
    ),
  );
}

class DeferredRouteShell extends StatefulWidget {
  const DeferredRouteShell({
    super.key,
    required this.load,
    required this.builder,
    required this.loading,
    required this.errorLabel,
  });

  final DeferredLoad load;
  final Widget Function(BuildContext context) builder;
  final Widget loading;
  final String errorLabel;

  @override
  State<DeferredRouteShell> createState() => _DeferredRouteShellState();
}

class _DeferredRouteShellState extends State<DeferredRouteShell> {
  late final Future<void> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loading;
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${widget.errorLabel}\n${snapshot.error}'),
              ),
            ),
          );
        }
        return widget.builder(context);
      },
    );
  }
}

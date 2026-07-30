import 'package:flutter/material.dart';

/// Loads a deferred library once, then builds the route widget.
class DeferredRouteChild extends StatefulWidget {
  const DeferredRouteChild({
    super.key,
    required this.loader,
    required this.builder,
  });

  final Future<void> Function() loader;
  final Widget Function() builder;

  @override
  State<DeferredRouteChild> createState() => _DeferredRouteChildState();
}

class _DeferredRouteChildState extends State<DeferredRouteChild> {
  late final Future<void> _loadFuture = widget.loader();
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load admin module.\n${snapshot.error}'),
              ),
            ),
          );
        }
        return _child ??= widget.builder();
      },
    );
  }
}

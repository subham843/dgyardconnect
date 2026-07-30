import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'public_seo_registry.dart';
import 'site_seo_config.dart';
import 'web_document_head.dart';
import 'web_seo_meta.dart';

/// Syncs document head tags whenever the browser route changes.
class WebSeoBinder extends StatefulWidget {
  const WebSeoBinder({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<WebSeoBinder> createState() => _WebSeoBinderState();
}

class _WebSeoBinderState extends State<WebSeoBinder> {
  String? _lastPath;
  WebSeoMeta? _dynamicOverride;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRouteChanged());
  }

  @override
  void didUpdateWidget(covariant WebSeoBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
      widget.router.routerDelegate.addListener(_onRouteChanged);
      _onRouteChanged();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    final uri = widget.router.routerDelegate.currentConfiguration.uri;
    final path = SiteSeoConfig.normalizePath(uri.path);
    if (path == _lastPath && _dynamicOverride == null) return;
    _lastPath = path;
    _dynamicOverride = null;
    _applyForPath(path);
  }

  void _applyForPath(String path) {
    if (PublicSeoRegistry.isPrivatePath(path)) {
      WebDocumentHead.apply(PublicSeoRegistry.metaForPrivatePath(path));
      return;
    }

    final staticMeta = PublicSeoRegistry.forPath(path);
    if (staticMeta != null) {
      WebDocumentHead.apply(staticMeta);
      return;
    }

    // Dynamic routes set meta via [WebSeoScope]; keep sensible fallback.
    WebDocumentHead.apply(PublicSeoRegistry.home());
  }

  @override
  Widget build(BuildContext context) {
    return WebSeoScopeNotifier(
      onApply: (meta) {
        _dynamicOverride = meta;
        WebDocumentHead.apply(meta);
      },
      child: widget.child,
    );
  }
}

/// Allows child pages to push dynamic SEO (products, categories, calculators).
class WebSeoScopeNotifier extends InheritedWidget {
  const WebSeoScopeNotifier({
    super.key,
    required this.onApply,
    required super.child,
  });

  final void Function(WebSeoMeta meta) onApply;

  static WebSeoScopeNotifier? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WebSeoScopeNotifier>();
  }

  @override
  bool updateShouldNotify(WebSeoScopeNotifier oldWidget) => false;
}

/// Call from a page when async content loads to update head tags.
class WebSeoScope extends StatefulWidget {
  const WebSeoScope({
    super.key,
    required this.meta,
    required this.child,
  });

  final WebSeoMeta meta;
  final Widget child;

  @override
  State<WebSeoScope> createState() => _WebSeoScopeState();
}

class _WebSeoScopeState extends State<WebSeoScope> {
  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant WebSeoScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meta.title != widget.meta.title ||
        oldWidget.meta.canonicalPath != widget.meta.canonicalPath ||
        oldWidget.meta.index != widget.meta.index) {
      _apply();
    }
  }

  void _apply() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = WebSeoScopeNotifier.maybeOf(context);
      if (notifier != null) {
        notifier.onApply(widget.meta);
      } else {
        WebDocumentHead.apply(widget.meta);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

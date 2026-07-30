import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/web_public/core/brand/public_brand_scope.dart';

CustomTransitionPage<void> routerTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}

/// Public website pages need Brand Kit scope (navbar, hero, footer, theme).
CustomTransitionPage<void> publicTransitionPage(GoRouterState state, Widget child) {
  return routerTransitionPage(state, PublicBrandShell(child: child));
}

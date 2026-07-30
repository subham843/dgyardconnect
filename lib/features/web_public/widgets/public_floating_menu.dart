import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../customer/account/customer_account_shell.dart';
import '../../../core/constants/route_names.dart';

/// Floating bottom chrome used across the public web app (replaces top navbar).
class PublicFloatingMenu extends StatelessWidget {
  const PublicFloatingMenu({
    super.key,
    required this.active,
    this.above,
    this.router,
  });

  final CustomerAccountTab active;
  /// Optional strip stacked above the floating menu (e.g. calculator price dock).
  final Widget? above;
  /// Preferred for navigation from MaterialApp.builder (outside Navigator).
  final GoRouter? router;

  /// Space to leave at the bottom of scroll content so the menu does not cover it.
  static double contentBottomInset(BuildContext context, {bool hasAbove = false}) {
    final safe = MediaQuery.paddingOf(context).bottom;
    // hasAbove covers calculator price dock (+ Save/Order row when signed in).
    return (hasAbove ? 230.0 : 100.0) + safe;
  }

  static CustomerAccountTab tabForPath(String path) {
    if (path.startsWith(RouteNames.publicCart) ||
        path.contains('/cart') ||
        path.contains('/checkout')) {
      return CustomerAccountTab.cart;
    }
    if (path.startsWith(RouteNames.publicCalculatorList) ||
        path.startsWith('/calculator')) {
      return CustomerAccountTab.calculator;
    }
    if (path.startsWith(RouteNames.accountHome) ||
        path.startsWith('/account') ||
        path.startsWith('/orders')) {
      return CustomerAccountTab.account;
    }
    if (path.startsWith(RouteNames.publicServices) ||
        path.startsWith('/services')) {
      return CustomerAccountTab.services;
    }
    if (path.startsWith(RouteNames.publicConnect) ||
        path.startsWith('/connect')) {
      return CustomerAccountTab.connect;
    }
    if (path.startsWith(RouteNames.publicAbout) || path.startsWith('/about')) {
      return CustomerAccountTab.about;
    }
    if (path.startsWith(RouteNames.supportHome) ||
        path.startsWith('/support') ||
        path.startsWith(RouteNames.publicContact) ||
        path.startsWith('/contact')) {
      return CustomerAccountTab.support;
    }
    if (path.startsWith(RouteNames.publicStore) ||
        path.startsWith('/store') ||
        path.startsWith('/product')) {
      return CustomerAccountTab.shop;
    }
    return CustomerAccountTab.home;
  }

  static CustomerAccountTab tabOf(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return tabForPath(path);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?above,
          CustomerAccountBottomBar(active: active, router: router),
        ],
      ),
    );
  }
}

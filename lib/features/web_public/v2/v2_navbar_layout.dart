import 'package:flutter/material.dart';

/// Navbar dimensions only — safe for main.dart.js cold path (no heavy navbar UI).
abstract final class V2NavbarLayout {
  static const double floatingMarginTop = 0;

  static double barHeight({required bool isDesktop}) => isDesktop ? 52 : 48;

  static double totalHeight(
    BuildContext context, {
    required bool isDesktop,
    bool floating = false,
  }) {
    return MediaQuery.paddingOf(context).top + barHeight(isDesktop: isDesktop);
  }
}

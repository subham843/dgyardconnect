import 'package:flutter/animation.dart';

/// Motion tokens to keep animations consistent across the app.
abstract final class MotionTokens {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);
  static const Duration slower = Duration(milliseconds: 320);

  static const Curve inCurve = Curves.easeOutCubic;
  static const Curve outCurve = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutBack;

  static const int listStaggerMs = 35;
}


// V2 Section — consistent container for every page section.
//
// Guarantees:
//   - Vertical rhythm: fluid Y padding via V2Responsive.sectionPadY
//   - Horizontal gutter: fluid via V2Responsive.gutter
//   - Max content width: 1280px (centered)
//   - No fixed heights (intrinsic)
//   - No horizontal overflow (children stretch within max-width)

import 'package:flutter/material.dart';

import '../v2_colors.dart';
import '../v2_tokens.dart';

class V2Section extends StatelessWidget {
  const V2Section({
    super.key,
    required this.child,
    this.background = V2Colors.bg,
    this.dark = false,
    this.maxWidth = V2.maxContentWidth,
    this.padYOverride,
    this.padTopOverride,
    this.padBottomOverride,
    this.gradient,
    this.borderTop = false,
    this.borderBottom = false,
  });

  final Widget child;
  final Color background;
  final bool dark;
  final double maxWidth;
  final double? padYOverride;
  final double? padTopOverride;
  final double? padBottomOverride;
  final Gradient? gradient;
  final bool borderTop;
  final bool borderBottom;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final padY = padYOverride ?? v.sectionPadY;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient,
        border: Border(
          top: borderTop
              ? BorderSide(color: dark ? Colors.white12 : V2Colors.border)
              : BorderSide.none,
          bottom: borderBottom
              ? BorderSide(color: dark ? Colors.white12 : V2Colors.border)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: v.gutter,
          right: v.gutter,
          top: padTopOverride ?? padY,
          bottom: padBottomOverride ?? padY,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A spacing primitive that adapts to breakpoints. Replaces magic-numbered
/// `SizedBox(height: ...)` calls throughout the page.
class V2Gap extends StatelessWidget {
  const V2Gap.xs({super.key}) : _factor = 0.5;
  const V2Gap.sm({super.key}) : _factor = 1;
  const V2Gap.md({super.key}) : _factor = 1.5;
  const V2Gap.lg({super.key}) : _factor = 2.25;
  const V2Gap.xl({super.key}) : _factor = 3.0;
  const V2Gap.xxl({super.key}) : _factor = 4.5;

  final double _factor;

  @override
  Widget build(BuildContext context) {
    // Base ~16px on mobile → ~24px on desktop.
    final v = V2Responsive(context);
    final base = v.r<double>(xs: 12.0, md: 14.0, lg: 16.0);
    return SizedBox(height: base * _factor);
  }
}

class V2HGap extends StatelessWidget {
  const V2HGap.xs({super.key}) : _factor = 0.5;
  const V2HGap.sm({super.key}) : _factor = 1;
  const V2HGap.md({super.key}) : _factor = 1.5;
  const V2HGap.lg({super.key}) : _factor = 2.25;
  const V2HGap.xl({super.key}) : _factor = 3;

  final double _factor;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final base = v.r<double>(xs: 8.0, md: 12.0, lg: 14.0);
    return SizedBox(width: base * _factor);
  }
}

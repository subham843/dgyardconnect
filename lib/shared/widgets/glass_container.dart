import 'dart:ui';

import 'package:flutter/material.dart';

/// Apple-style glass morphism container: frosted glass with blur and subtle border.
/// Use for cards, buttons, and panels on the login and other screens.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurSigma = 20,
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fillColor = color ??
        (isLight
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.12));
    final border = borderColor ??
        (isLight
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.2));

    // Ensure hit-testable area is never zero size (avoids "Cannot hit test a render box with no size").
    final content = onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1, minHeight: 1),
                child: child,
              ),
            ),
          )
        : child;

    Widget inner = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: inner,
      ),
    );
  }
}

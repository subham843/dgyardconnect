import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/dealer_ui_tokens.dart';

/// Premium frosted surface: backdrop blur + translucent white — DGYard prototype [GlassBox].
///
/// Optional [tintColors] / [tintStops] draw a subtle gradient over the frost (same role as
/// tinted [GlassCard] overlays).
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.child,
    this.radius = 0,
    this.opacity = 0.4,
    this.blurSigma = 25,
    this.padding,
    this.margin,
    this.onTap,
    this.showBorder = true,
    this.borderWidth,
    this.borderOpacity,
    this.tintColors,
    this.tintStops,
  });

  final Widget child;
  final double radius;
  final double opacity;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool showBorder;

  /// Edge highlight (white rim). Defaults: 1.2px @ 50% when [showBorder] is true.
  final double? borderWidth;
  final double? borderOpacity;

  final List<Color>? tintColors;
  final List<double>? tintStops;

  @override
  Widget build(BuildContext context) {
    final r = radius;
    List<double>? stops = tintStops;
    final tints = tintColors;
    if (tints != null && tints.isNotEmpty) {
      if (stops == null || stops.length != tints.length) {
        final n = tints.length;
        stops = n <= 1
            ? const [0.0]
            : List<double>.generate(n, (i) => i / (n - 1));
      }
    }

    Widget panel = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(r),
              border: showBorder
                  ? Border.all(
                      color: Colors.white.withValues(
                        alpha: borderOpacity ?? 0.5,
                      ),
                      width: borderWidth ?? 1.2,
                    )
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                if (tints != null &&
                    tints.isNotEmpty &&
                    stops != null &&
                    stops.length == tints.length)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: tints,
                          stops: stops,
                        ),
                      ),
                    ),
                  ),
                Padding(padding: padding ?? EdgeInsets.zero, child: child),
              ],
            ),
          ),
        ),
      ),
    );

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        splashColor: Colors.black.withValues(alpha: 0.08),
        highlightColor: Colors.black.withValues(alpha: 0.04),
        child: panel,
      ),
    );
  }
}

/// Apple-style frosted glass panel with real [BackdropFilter] blur.
///
/// Wrapped in [RepaintBoundary] to limit repaint cost when scrollables move behind it.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.blurSigma,
    this.margin,
    this.onTap,
    this.tintStops,
    this.tintColors,
    this.showBorder = true,
    this.referenceStyle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? blurSigma;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Optional extra tint on top of the base frosted layer (stops 0→1).
  final List<double>? tintStops;
  final List<Color>? tintColors;

  /// When false, no rim / outer glow — blur + tint only (e.g. search field).
  final bool showBorder;

  /// Solid gradient + white rim + soft shadow (glass reference demo) — **no** backdrop blur.
  final bool referenceStyle;

  static const Color _ink = Color(0xFF1C1C1E);
  static const Color _inkMuted = Color(0xFF636366);

  static TextStyle heading({double fontSize = 17}) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: _ink,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static TextStyle body({double fontSize = 14}) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: _ink,
    height: 1.25,
  );

  static TextStyle caption({double fontSize = 12.5}) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: _inkMuted,
    height: 1.25,
  );

  @override
  Widget build(BuildContext context) {
    final r = borderRadius;
    if (referenceStyle) {
      return _buildReferenceStyle(context, r);
    }
    final sigma = blurSigma ?? DealerUiTokens.glassCardBlurSigma;
    final stops = tintStops ?? const [0.0, 0.45, 1.0];
    final tints =
        tintColors ??
        [
          Colors.white.withValues(alpha: 0.095),
          Colors.white.withValues(alpha: 0.072),
          Colors.white.withValues(alpha: 0.088),
        ];

    const rimWhite = Color(0xFFFFFFFF);
    final List<BoxShadow> cardShadows = showBorder
        ? [
            ...DealerUiTokens.glassDepthShadows,
            BoxShadow(
              color: rimWhite.withValues(alpha: 0.38),
              blurRadius: 14,
              spreadRadius: -5,
              offset: const Offset(0, -1.5),
            ),
            BoxShadow(
              color: rimWhite.withValues(alpha: 0.2),
              blurRadius: 22,
              spreadRadius: -4,
              offset: Offset.zero,
            ),
          ]
        : const <BoxShadow>[];

    Widget panel = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          boxShadow: cardShadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: tints,
                        stops: stops,
                      ),
                    ),
                  ),
                ),
                if (showBorder)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.12,
                          colors: [
                            rimWhite.withValues(alpha: 0.062),
                            rimWhite.withValues(alpha: 0.05),
                            rimWhite.withValues(alpha: 0.056),
                          ],
                          stops: const [0.0, 0.52, 1.0],
                        ),
                      ),
                    ),
                  ),
                if (showBorder)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        gradient: RadialGradient(
                          center: const Alignment(-0.82, -0.92),
                          radius: 1.35,
                          colors: [
                            rimWhite.withValues(alpha: 0.1),
                            rimWhite.withValues(alpha: 0.035),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.38, 1.0],
                        ),
                      ),
                    ),
                  ),
                if (showBorder)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            rimWhite.withValues(alpha: 0.045),
                            rimWhite.withValues(alpha: 0.018),
                            rimWhite.withValues(alpha: 0.032),
                          ],
                          stops: const [0.0, 0.48, 1.0],
                        ),
                      ),
                    ),
                  ),
                if (showBorder)
                  ..._glassInsetEdgeHighlights(
                    cornerRadius: r,
                    rimWhite: rimWhite,
                  ),
                if (showBorder)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        border: Border.all(
                          color: rimWhite.withValues(alpha: 0.28),
                          width: 0.9,
                        ),
                      ),
                    ),
                  ),
                if (showBorder)
                  Positioned(
                    top: 1,
                    left: r * 0.35,
                    right: r * 0.35,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            rimWhite.withValues(alpha: 0.38),
                            rimWhite.withValues(alpha: 0.52),
                            rimWhite.withValues(alpha: 0.38),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
                        ),
                      ),
                    ),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: panel,
      ),
    );
  }

  /// Matches [GlassReferenceShowcaseScreen] cards: gradient white fill, bright rim, lift shadow.
  Widget _buildReferenceStyle(BuildContext context, double r) {
    const rimWhite = Color(0xFFFFFFFF);
    final tints = tintColors;
    List<double>? stops = tintStops;
    if (tints != null && tints.isNotEmpty) {
      if (stops == null || stops.length != tints.length) {
        final n = tints.length;
        stops = n <= 1
            ? const [0.0]
            : List<double>.generate(n, (i) => i / (n - 1));
      }
    }

    Widget panel = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.88),
              Colors.white.withValues(alpha: 0.68),
            ],
          ),
          border: showBorder
              ? Border.all(color: rimWhite.withValues(alpha: 0.95), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              if (tints != null &&
                  tints.isNotEmpty &&
                  stops != null &&
                  stops.length == tints.length)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: tints,
                        stops: stops,
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        splashColor: Colors.black.withValues(alpha: 0.08),
        highlightColor: Colors.black.withValues(alpha: 0.04),
        child: panel,
      ),
    );
  }
}

/// Floating bottom bar with stronger blur and a subtle top-edge highlight.
class GlassNavbar extends StatelessWidget {
  const GlassNavbar({
    super.key,
    required this.child,
    this.blurSigma,
    this.borderRadius = 30,
    this.padding = const EdgeInsets.fromLTRB(10, 10, 10, 10),
  });

  final Widget child;
  final double? blurSigma;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius;
    final sigma = blurSigma ?? DealerUiTokens.glassNavBlurSigma;
    const rimW = 0.9;
    final navShadows = [
      ...DealerUiTokens.glassDepthShadows,
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.36),
        blurRadius: 14,
        spreadRadius: -5,
        offset: const Offset(0, -1.5),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.18),
        blurRadius: 22,
        spreadRadius: -4,
        offset: Offset.zero,
      ),
    ];

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          boxShadow: navShadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.028),
                        ],
                        stops: const [0.0, 0.35, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r),
                      gradient: RadialGradient(
                        center: const Alignment(-0.75, -0.95),
                        radius: 1.2,
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.38, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: rimW,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 1,
                  left: 10,
                  right: 10,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.32),
                          Colors.white.withValues(alpha: 0.48),
                          Colors.white.withValues(alpha: 0.32),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary: soft iOS-style blue gradient. Secondary: frosted outline pill.
enum GlassButtonVariant { primary, secondary }

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.variant = GlassButtonVariant.primary,
    this.height = 52,
    this.borderRadius = 22,
    this.fontSize = 13,
    this.flatPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;
  final GlassButtonVariant variant;
  final double height;
  final double borderRadius;
  final double fontSize;

  /// Primary only: solid gradient, no glossy rim / glow (e.g. Command Center CTA).
  final bool flatPrimary;

  static const List<Color> _iosBlue = [
    Color(0xFF5AC8FA),
    Color(0xFF0A84FF),
    Color(0xFF0066CC),
  ];

  @override
  Widget build(BuildContext context) {
    final r = borderRadius;
    if (variant == GlassButtonVariant.secondary) {
      return Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(r),
            splashColor: Colors.white.withValues(alpha: 0.14),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                boxShadow: DealerUiTokens.glassDepthShadows,
              ),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: const Color(0xFF0A84FF)),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: fontSize,
                          color: const Color(0xFF1C1C1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(r),
          splashColor: Colors.white.withValues(alpha: 0.28),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _iosBlue,
              ),
              border: flatPrimary
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
              boxShadow: flatPrimary
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF0A84FF).withValues(alpha: 0.42),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: -2,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: fontSize,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White fade from all four inner edges so the whole card reads like a framed glass panel.
List<Widget> _glassInsetEdgeHighlights({
  required double cornerRadius,
  required Color rimWhite,
}) {
  final d = (cornerRadius * 0.38).clamp(6.0, 14.0);
  final r = cornerRadius;
  return [
    Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: d,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              rimWhite.withValues(alpha: 0.12),
              rimWhite.withValues(alpha: 0.04),
              Colors.transparent,
            ],
            stops: const [0.0, 0.44, 1.0],
          ),
        ),
      ),
    ),
    Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: d,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(r),
            bottomRight: Radius.circular(r),
          ),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              rimWhite.withValues(alpha: 0.085),
              rimWhite.withValues(alpha: 0.028),
              Colors.transparent,
            ],
            stops: const [0.0, 0.46, 1.0],
          ),
        ),
      ),
    ),
    Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      width: d,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(r),
            bottomLeft: Radius.circular(r),
          ),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              rimWhite.withValues(alpha: 0.1),
              rimWhite.withValues(alpha: 0.032),
              Colors.transparent,
            ],
            stops: const [0.0, 0.46, 1.0],
          ),
        ),
      ),
    ),
    Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: d,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(r),
            bottomRight: Radius.circular(r),
          ),
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              rimWhite.withValues(alpha: 0.1),
              rimWhite.withValues(alpha: 0.032),
              Colors.transparent,
            ],
            stops: const [0.0, 0.46, 1.0],
          ),
        ),
      ),
    ),
  ];
}

/// Small square glass control (notifications, settings, etc.).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.borderRadius = 14,
    this.iconSize = 20,
    this.iconColor = const Color(0xFF1C1C1E),
    this.blurSigma,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double borderRadius;
  final double iconSize;
  final Color iconColor;
  final double? blurSigma;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: borderRadius,
      blurSigma: blurSigma ?? 25,
      opacity: 0.48,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}

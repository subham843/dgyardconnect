import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/technician_ui_tokens.dart';

/// Animated light canvas with soft drifting blobs (subtle, 60fps-friendly).
class TechnicianGlassBackground extends StatefulWidget {
  const TechnicianGlassBackground({
    super.key,
    this.child,
    this.animateOrbs = true,
    this.animateChildFadeIn = true,
  });

  final Widget? child;
  final bool animateOrbs;
  /// One-shot fade when this background mounts (safe with scrollables; inner [StreamBuilder] updates do not re-run it).
  final bool animateChildFadeIn;

  @override
  State<TechnicianGlassBackground> createState() => _TechnicianGlassBackgroundState();
}

class _TechnicianGlassBackgroundState extends State<TechnicianGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.animateOrbs) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(TechnicianGlassBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateOrbs && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animateOrbs && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animate = widget.animateOrbs && !reduceMotion;
    Widget? foreground = widget.child;
    if (foreground != null && widget.animateChildFadeIn && !reduceMotion) {
      foreground = foreground
          .animate()
          .fadeIn(duration: 320.ms, curve: Curves.easeOutCubic);
    }

    if (!animate && _controller.isAnimating) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.stop();
      });
    } else if (animate && !_controller.isAnimating) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.repeat();
      });
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = animate ? _controller.value : 0.0;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TechnicianUiTokens.glassTintTop,
                  TechnicianUiTokens.glassTintMid,
                  TechnicianUiTokens.glassTintBottom,
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Blob(
                  color: TechnicianUiTokens.bgBlobA,
                  alignment: Alignment(
                    -0.85 + 0.06 * math.sin(t * math.pi * 2),
                    -0.75 + 0.05 * math.cos(t * math.pi * 2 * 0.67),
                  ),
                  diameter: 1.15,
                ),
                _Blob(
                  color: TechnicianUiTokens.bgBlobB,
                  alignment: Alignment(
                    0.75 + 0.05 * math.cos(t * math.pi * 2 * 1.02),
                    -0.35 + 0.06 * math.sin(t * math.pi * 2 * 0.74),
                  ),
                  diameter: 0.95,
                ),
                _Blob(
                  color: TechnicianUiTokens.bgBlobC,
                  alignment: Alignment(
                    -0.2 + 0.07 * math.sin(t * math.pi * 2 * 0.9),
                    0.85 + 0.04 * math.cos(t * math.pi * 2 * 1.16),
                  ),
                  diameter: 1.05,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.85),
                      radius: 1.2,
                      colors: [
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
                ?foreground,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.alignment,
    required this.diameter,
  });

  final Color color;
  final Alignment alignment;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: MediaQuery.sizeOf(context).shortestSide * diameter,
        height: MediaQuery.sizeOf(context).shortestSide * diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class TechnicianGlassCard extends StatelessWidget {
  const TechnicianGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = TechnicianUiTokens.rLg,
    this.blurSigma = TechnicianUiTokens.blurMedium,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: TechnicianUiTokens.glassSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: TechnicianUiTokens.hairlineOnGlass, width: 1),
            boxShadow: TechnicianUiTokens.shadowCard,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Full-bleed frosted layer for [AppBar.flexibleSpace] (readable on busy backgrounds).
class TechnicianGlassBarBackdrop extends StatelessWidget {
  const TechnicianGlassBarBackdrop({super.key, this.animate = true});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // No [BackdropFilter] here: without a strict clip it can blur the whole route on some
    // embedders (Windows/desktop), making the entire screen unreadable. Frosted look = gradient + fill.
    // Rectangular bar — no corner radius (avoids gaps next to scaffold).
    Widget backdrop = const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TechnicianUiTokens.glassTintTop,
              TechnicianUiTokens.appBarGlassBottom,
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: Color(0xB8FFFFFF),
              width: 1,
            ),
          ),
        ),
        child: SizedBox.expand(),
      ),
    );

    if (animate && !reduceMotion) {
      backdrop = backdrop
          .animate()
          .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
          .slideY(
            begin: -0.08,
            end: 0,
            duration: 320.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return backdrop;
  }
}

class TechnicianGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TechnicianGlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final bottomH = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomH);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: TechnicianUiTokens.labelPrimary,
      letterSpacing: -0.4,
    );
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      foregroundColor: TechnicianUiTokens.labelPrimary,
      iconTheme: const IconThemeData(
        color: TechnicianUiTokens.labelPrimary,
        size: 22,
      ),
      actionsIconTheme: const IconThemeData(
        color: TechnicianUiTokens.labelPrimary,
        size: 22,
      ),
      title: Text(title, style: titleStyle),
      leading: leading,
      actions: actions,
      bottom: bottom,
      flexibleSpace: const TechnicianGlassBarBackdrop(),
    );
  }
}

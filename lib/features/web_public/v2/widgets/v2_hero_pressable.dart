import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../v2_colors.dart';
import '../v2_tokens.dart';

/// Hover / press state exposed to hero CTA builders.
class V2HeroPointerState {
  const V2HeroPointerState({required this.hover, required this.pressed});

  final bool hover;
  final bool pressed;

  bool get active => hover || pressed;
}

/// Modern hover / press feedback — glow, shimmer sweep, spring scale, tap ripple + flash.
class V2HeroPressable extends StatefulWidget {
  const V2HeroPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.glowColor = V2Colors.premiumOrange,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.hoverScale = 1.06,
    this.pressScale = 0.93,
  });

  final Widget Function(BuildContext context, V2HeroPointerState state) builder;
  final VoidCallback? onTap;
  final bool enabled;
  final Color glowColor;
  final BorderRadius borderRadius;
  final double hoverScale;
  final double pressScale;

  @override
  State<V2HeroPressable> createState() => _V2HeroPressableState();
}

class _V2HeroPressableState extends State<V2HeroPressable> with TickerProviderStateMixin {
  bool _hover = false;
  bool _pressed = false;

  late final AnimationController _shimmerCtrl;
  late final AnimationController _rippleCtrl;
  late final AnimationController _flashCtrl;

  V2HeroPointerState get _state => V2HeroPointerState(hover: _hover, pressed: _pressed);

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _rippleCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  void _setHover(bool value) {
    if (!widget.enabled) return;
    setState(() => _hover = value);
    if (value) {
      _shimmerCtrl.repeat();
    } else {
      _shimmerCtrl
        ..stop()
        ..reset();
      _pressed = false;
    }
  }

  void _onTapUp() {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
  }

  void _onTap() {
    if (!widget.enabled || widget.onTap == null) return;
    _rippleCtrl.forward(from: 0);
    _flashCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
    widget.onTap!();
  }

  double get _scale {
    if (!widget.enabled) return 1;
    if (_pressed) return widget.pressScale;
    if (_hover) return widget.hoverScale;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled ? (_) => _onTapUp() : null,
        onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.enabled ? _onTap : null,
        child: AnimatedScale(
          scale: _scale,
          duration: Duration(milliseconds: _pressed ? 90 : 320),
          curve: _pressed ? Curves.easeInCubic : Curves.elasticOut,
          child: AnimatedContainer(
            duration: V2.dFast,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: _hover && widget.enabled
                  ? [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                widget.builder(context, _state),
                if (_hover && widget.enabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: widget.borderRadius,
                        child: AnimatedBuilder(
                          animation: _shimmerCtrl,
                          builder: (context, _) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1.5 + _shimmerCtrl.value * 3, 0),
                                  end: Alignment(-0.5 + _shimmerCtrl.value * 3, 0),
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.28),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: AnimatedBuilder(
                        animation: _rippleCtrl,
                        builder: (context, _) {
                          if (_rippleCtrl.value == 0) return const SizedBox.shrink();
                          return CustomPaint(
                            painter: _TapRipplePainter(
                              progress: _rippleCtrl.value,
                              color: widget.glowColor,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 0.35, end: 0).animate(
                          CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut),
                        ),
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TapRipplePainter extends CustomPainter {
  _TapRipplePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.shortestSide * 0.85) * progress;
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1 - progress);
    canvas.drawCircle(center, maxRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _TapRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

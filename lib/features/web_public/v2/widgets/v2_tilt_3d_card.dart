// Magnetic 3D tilt card — pointer-driven perspective + lift (web-first).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../v2_colors.dart';

/// Premium hover card: perspective tilt, dynamic shadow, press spring.
class V2Tilt3DCard extends StatefulWidget {
  const V2Tilt3DCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 18,
    this.maxTilt = 0.14,
    this.hoverLift = 6,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double maxTilt;
  final double hoverLift;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  @override
  State<V2Tilt3DCard> createState() => _V2Tilt3DCardState();
}

class _V2Tilt3DCardState extends State<V2Tilt3DCard> with SingleTickerProviderStateMixin {
  late final AnimationController _spring;
  late Animation<double> _tiltX;
  late Animation<double> _tiltY;
  late Animation<double> _lift;

  double _targetTiltX = 0;
  double _targetTiltY = 0;
  double _targetLift = 0;
  bool _hover = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _tiltX = AlwaysStoppedAnimation(0);
    _tiltY = AlwaysStoppedAnimation(0);
    _lift = AlwaysStoppedAnimation(0);
    _spring.addListener(_onSpringTick);
  }

  void _onSpringTick() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _spring.removeListener(_onSpringTick);
    _spring.dispose();
    super.dispose();
  }

  void _animateToTargets() {
    final beginX = _tiltX.value;
    final beginY = _tiltY.value;
    final beginLift = _lift.value;
    _spring.stop();
    _spring.reset();
    _tiltX = Tween<double>(begin: beginX, end: _targetTiltX).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    );
    _tiltY = Tween<double>(begin: beginY, end: _targetTiltY).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    );
    _lift = Tween<double>(begin: beginLift, end: _targetLift).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    );
    _spring.forward();
  }

  void _onHover(PointerHoverEvent event, Size size) {
    if (_pressed) return;
    final nx = ((event.localPosition.dx / size.width) - 0.5).clamp(-0.5, 0.5) * 2;
    final ny = ((event.localPosition.dy / size.height) - 0.5).clamp(-0.5, 0.5) * 2;
    _targetTiltX = -ny * widget.maxTilt;
    _targetTiltY = nx * widget.maxTilt;
    _targetLift = widget.hoverLift;
    _hover = true;
    _animateToTargets();
  }

  void _resetTilt() {
    _hover = false;
    _pressed = false;
    _targetTiltX = 0;
    _targetTiltY = 0;
    _targetLift = 0;
    _animateToTargets();
  }

  Matrix4 _transformMatrix() {
    final lift = _lift.value;
    final tilt = Matrix4.identity()
      ..setEntry(3, 2, 0.00115)
      ..rotateX(_tiltX.value)
      ..rotateY(_tiltY.value);
    final liftMatrix = Matrix4.translationValues(0, -lift, lift * 0.35);
    return liftMatrix * tilt;
  }

  double get _scale => _pressed ? 0.96 : (_hover ? 1.02 : 1.0);

  List<BoxShadow> _shadows() {
    final tiltY = _tiltY.value / math.max(widget.maxTilt, 0.001);
    final tiltX = _tiltX.value / math.max(widget.maxTilt, 0.001);
    final elevation = _hover || _pressed ? 1.0 : 0.45;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05 + elevation * 0.07),
        blurRadius: 8 + elevation * 10,
        offset: Offset(-tiltY * 6, 4 + elevation * 4 + tiltX * 3),
      ),
      BoxShadow(
        color: V2Colors.plasma.withValues(alpha: _hover ? 0.08 : 0.03),
        blurRadius: _hover ? 22 : 10,
        offset: Offset(tiltY * 4, 10 + elevation * 6),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.maxHeight.isFinite;
        final size = Size(
          constraints.maxWidth,
          boundedHeight ? constraints.maxHeight : 1,
        );

        final card = MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => _resetTilt(),
          onHover: (e) => _onHover(e, size),
          cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
            onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
            onTap: widget.onTap,
            child: Transform(
              alignment: Alignment.center,
              transform: _transformMatrix(),
              child: Transform.scale(
                scale: _scale,
                child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  color: widget.backgroundColor,
                  border: Border.all(
                    color: _hover
                        ? Colors.white.withValues(alpha: 0.95)
                        : V2Colors.borderSubtle,
                    width: 1,
                  ),
                  boxShadow: _shadows(),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius - 1),
                  child: Stack(
                    fit: boundedHeight ? StackFit.expand : StackFit.loose,
                    children: [
                      widget.padding == EdgeInsets.zero
                          ? widget.child
                          : Padding(padding: widget.padding, child: widget.child),
                      if (_hover)
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1 + _tiltY.value * 3, -1 + _tiltX.value * 3),
                                end: Alignment(1 - _tiltY.value * 3, 1 - _tiltX.value * 3),
                                colors: [
                                  Colors.white.withValues(alpha: 0.42),
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.12),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        );

        if (boundedHeight) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: card,
          );
        }
        return SizedBox(width: constraints.maxWidth, child: card);
      },
    );
  }
}

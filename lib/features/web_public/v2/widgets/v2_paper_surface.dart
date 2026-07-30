// Layered Paper UI — floating surface cards with soft 3D elevation.

import 'package:flutter/material.dart';

import '../v2_colors.dart';
import '../v2_tokens.dart';

class V2PaperSurface extends StatefulWidget {
  const V2PaperSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.borderRadiusGeometry,
    this.elevation = V2PaperElevation.mid,
    this.hoverLift = false,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
    this.backgroundColor = V2Colors.paperWhite,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  /// When set, overrides [borderRadius] (e.g. bottom-only rounded corners).
  final BorderRadiusGeometry? borderRadiusGeometry;
  final V2PaperElevation elevation;
  final bool hoverLift;
  final VoidCallback? onTap;
  final Clip clipBehavior;
  final Color backgroundColor;
  final Border? border;

  @override
  State<V2PaperSurface> createState() => _V2PaperSurfaceState();
}

enum V2PaperElevation { low, mid, high, floatBottom }

class _V2PaperSurfaceState extends State<V2PaperSurface> {
  bool _hover = false;

  List<BoxShadow> get _shadows {
    if (_hover && widget.hoverLift) return V2Colors.paperLift();
    switch (widget.elevation) {
      case V2PaperElevation.low:
        return V2Colors.paperLow;
      case V2PaperElevation.mid:
        return V2Colors.paperMid;
      case V2PaperElevation.high:
        return V2Colors.paperHigh;
      case V2PaperElevation.floatBottom:
        return V2Colors.paperFloatBottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadiusGeometry ?? BorderRadius.circular(widget.borderRadius);

    Widget card = AnimatedContainer(
      duration: V2.dMed,
      curve: V2.eOut,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: radius,
        border: widget.border ??
            Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
        boxShadow: _shadows,
      ),
      clipBehavior: widget.clipBehavior,
      child: Stack(
        children: [
          // Subtle glass highlight (top edge)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.9),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: widget.child,
          ),
        ],
      ),
    );

    if (widget.hoverLift || widget.onTap != null) {
      card = MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: widget.hoverLift ? (_) => setState(() => _hover = true) : null,
        onExit: widget.hoverLift ? (_) => setState(() => _hover = false) : null,
        child: GestureDetector(onTap: widget.onTap, child: card),
      );
    }

    return card;
  }
}

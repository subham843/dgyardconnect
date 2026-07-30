// V2 Accent Word — Instrument Serif italic with a hand-drawn underline.
//
// Used inside the hero headline as the editorial "magic word" (Apple
// marketing-page style). The underline draws itself with a one-shot stroke
// animation.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../v2_colors.dart';
import '../v2_text.dart';

class V2AccentWord extends StatefulWidget {
  const V2AccentWord({
    super.key,
    required this.word,
    required this.fontSize,
    this.color,
  });

  final String word;
  final double fontSize;
  final Color? color;

  @override
  State<V2AccentWord> createState() => _V2AccentWordState();
}

class _V2AccentWordState extends State<V2AccentWord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // delay a beat so the headline lands first
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? V2Colors.ember;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _UnderlinePainter(progress: _ctrl.value, color: color),
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.fontSize * 0.08),
            child: Text(
              widget.word,
              style: V2Text.accentItalic(
                size: widget.fontSize,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(2.0, size.height * 0.04)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final y = size.height - paint.strokeWidth * 0.6;
    final startX = 2.0;
    final endX = (size.width - 2) * progress;

    // Slight hand-drawn waviness: 1 quadratic bezier with a small mid bulge.
    final path = Path()
      ..moveTo(startX, y)
      ..quadraticBezierTo(size.width * 0.5, y + 2.5, endX, y);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _UnderlinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}


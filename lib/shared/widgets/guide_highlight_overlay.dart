import 'dart:ui';

import 'package:flutter/material.dart';

enum GuideOverlayAction { back, next, skip }

class GuideHighlightOverlay extends StatelessWidget {
  const GuideHighlightOverlay({
    super.key,
    required this.targetRect,
    required this.title,
    required this.description,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.stepText,
    required this.canBack,
    required this.isLast,
  });

  final Rect targetRect;
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final String stepText;
  final bool canBack;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = targetRect.center;
    final radius = (targetRect.size.longestSide * 0.70) + 18;
    final hole = Rect.fromCircle(center: center, radius: radius);
    final cardTop = (hole.bottom + 18).clamp(90.0, size.height - 230.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CutoutOverlayPainter(
                  holeRect: hole,
                  holeRadius: radius,
                  overlayColor: Colors.black.withValues(alpha: 0.40),
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: hole,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF93C5FD), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.34),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: cardTop,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stepText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (canBack)
                            OutlinedButton(
                              onPressed: onBack,
                              child: const Text('Back'),
                            ),
                          if (canBack) const SizedBox(width: 8),
                          TextButton(
                            onPressed: onSkip,
                            child: const Text('Skip'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: onNext,
                            child: Text(isLast ? 'Finish' : 'Continue'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CutoutOverlayPainter extends CustomPainter {
  _CutoutOverlayPainter({
    required this.holeRect,
    required this.holeRadius,
    required this.overlayColor,
  });

  final Rect holeRect;
  final double holeRadius;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()..addOval(Rect.fromCircle(center: holeRect.center, radius: holeRadius));
    final finalPath = Path.combine(PathOperation.difference, overlayPath, cutout);
    canvas.drawPath(finalPath, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _CutoutOverlayPainter oldDelegate) {
    return oldDelegate.holeRect != holeRect ||
        oldDelegate.holeRadius != holeRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

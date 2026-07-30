import 'package:flutter/material.dart';

/// Lightweight brand marks — no Font Awesome / extra font downloads on web.
abstract final class V2BrandIcons {
  static Widget google({double size = 16}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleMarkPainter(),
        size: Size.square(size),
      ),
    );
  }

  static Widget facebook({double size = 16, Color color = const Color(0xFF1877F2)}) {
    return Icon(Icons.facebook_rounded, size: size, color: color);
  }

  static IconData storePlatformIcon({required bool android}) {
    return android ? Icons.shop_rounded : Icons.phone_iphone_rounded;
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final r = s * 0.18;
    final stroke = s * 0.14;
    final center = Offset(size.width / 2, size.height / 2);

    void arc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: s * 0.34),
        start,
        sweep,
        false,
        paint,
      );
    }

    arc(const Color(0xFF4285F4), -0.45, 1.15);
    arc(const Color(0xFF34A853), 0.70, 1.05);
    arc(const Color(0xFFFBBC05), 2.0, 1.05);
    arc(const Color(0xFFEA4335), 3.25, 1.05);

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy - r),
      Offset(size.width * 0.78, center.dy - r),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

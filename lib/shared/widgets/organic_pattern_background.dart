import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen animated organic blobs (glass-reference style) — use behind content in a [Stack].
///
/// When [tabProgress] is set (typically **0–2** for Connect | Calculate | Shop), blob and
/// base tints lean toward that segment’s palette so the background matches the active tab.
class OrganicPatternBackground extends StatefulWidget {
  const OrganicPatternBackground({super.key, this.tabProgress});

  /// Optional page position in **[0, 2]** (e.g. dealer home sub-tabs). When `null`, uses the neutral default palette.
  final double? tabProgress;

  @override
  State<OrganicPatternBackground> createState() =>
      _OrganicPatternBackgroundState();
}

class _OrganicPatternBackgroundState extends State<OrganicPatternBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: OrganicPatternPainter(
                _controller.value,
                tabProgress: widget.tabProgress,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Segment pastels for dealer **Connect | Calculate | Shop** — same values drive
/// [OrganicPatternPainter] blobs and matching glass tiles (e.g. Estimate / Buy strips).
abstract final class DealerTabSurfaceTints {
  DealerTabSurfaceTints._();

  /// Find Technician — soft sky (blob / base lean).
  static const Color connect = Color(0xFF9EC4FF);

  /// Estimate Cost — mint (matches Calculate tab background).
  static const Color calculate = Color(0xFF8EECC4);

  /// Buy Equipment — warm peach (matches Shop tab background).
  static const Color shop = Color(0xFFFFDCA8);
}

/// Organic liquid blobs: cool gray + whisper blue/lavender, drift / morph / colour breath.
/// No [MaskFilter] on the full canvas.
class OrganicPatternPainter extends CustomPainter {
  OrganicPatternPainter(this.progress, {this.tabProgress});

  final double progress;
  final double? tabProgress;

  /// Soft cool base — matches premium glass mockups (marble-adjacent, lavender lift).
  static const Color kBase = Color(0xFFF2F0FA);

  /// Fluid blobs: light blue, lavender, soft violet (reference: glass hero marketing art).
  static const List<Color> _blobCores = [
    Color(0xFFC8D9FA),
    Color(0xFFD9D2F2),
    Color(0xFFB8C8F5),
    Color(0xFFE0D6F5),
    Color(0xFFC5D4F8),
    Color(0xFFD4C8F0),
  ];

  /// Soft pastels aligned with dealer sub-tabs (Connect | Calculate | Shop).
  static Color _tabTint(double p) {
    final x = p.clamp(0.0, 2.0);
    if (x < 1.0) {
      return Color.lerp(DealerTabSurfaceTints.connect, DealerTabSurfaceTints.calculate, x)!;
    }
    return Color.lerp(DealerTabSurfaceTints.calculate, DealerTabSurfaceTints.shop, x - 1.0)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final m = math.max(w, h);

    final baseColor = tabProgress == null
        ? kBase
        : (Color.lerp(kBase, _tabTint(tabProgress!), 0.085) ?? kBase);
    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);

    final t = progress * 2 * math.pi;
    final breath = 0.88 + 0.12 * math.sin(t * 0.35);

    final specs = <({
      double cx,
      double cy,
      double r,
      int colorI,
      double phase,
      double driftXA,
      double driftYA,
    })>[
      (cx: 0.12, cy: 0.14, r: 0.42, colorI: 0, phase: 0.0, driftXA: 0.07, driftYA: 0.05),
      (cx: 0.88, cy: 0.18, r: 0.38, colorI: 1, phase: 1.2, driftXA: 0.06, driftYA: 0.06),
      (cx: 0.5, cy: 0.38, r: 0.48, colorI: 2, phase: 2.1, driftXA: 0.05, driftYA: 0.04),
      (cx: 0.18, cy: 0.72, r: 0.4, colorI: 3, phase: 0.7, driftXA: 0.055, driftYA: 0.045),
      (cx: 0.82, cy: 0.68, r: 0.36, colorI: 4, phase: 1.8, driftXA: 0.05, driftYA: 0.05),
      (cx: 0.48, cy: 0.88, r: 0.34, colorI: 5, phase: 2.6, driftXA: 0.04, driftYA: 0.035),
    ];

    for (var b = 0; b < specs.length; b++) {
      final s = specs[b];
      final morph = t + s.phase;
      final dx = math.sin(morph * 0.9) * s.driftXA * m +
          math.sin(morph * 0.31 + b) * 0.02 * m;
      final dy = math.cos(morph * 0.75) * s.driftYA * m +
          math.cos(morph * 0.27 + b * 0.7) * 0.018 * m;
      final scale = (1.0 + 0.06 * math.sin(morph * 0.55 + s.phase)) * breath;

      final center = Offset(w * s.cx + dx, h * s.cy + dy);
      final radius = m * s.r * 0.5 * scale;

      final defaultCore = Color.lerp(
        _blobCores[s.colorI % _blobCores.length],
        _blobCores[(s.colorI + 1) % _blobCores.length],
        0.5 + 0.5 * math.sin(t * 0.2 + s.phase),
      )!;
      final tp = tabProgress;
      final core = tp == null
          ? defaultCore
          : (Color.lerp(
                  defaultCore,
                  _tabTint(tp),
                  0.38 + 0.12 * math.sin(t * 0.17 + s.phase + b * 0.4),
                ) ??
                defaultCore);

      final path = _organicBlobPath(
        center: center,
        baseRadius: radius,
        morph: morph,
        asym: 0.08 + b * 0.02,
      );

      final bounds = path.getBounds();
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft +
              Alignment(math.sin(morph) * 0.15, math.cos(morph * 0.8) * 0.12),
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFCFDFF).withValues(alpha: 0.95),
            core.withValues(alpha: 0.72),
            core.withValues(alpha: 0.45),
            core.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.28, 0.55, 1.0],
        ).createShader(bounds);

      canvas.drawPath(path, paint);
    }
  }

  static Path _organicBlobPath({
    required Offset center,
    required double baseRadius,
    required double morph,
    required double asym,
  }) {
    const segments = 56;
    final path = Path();
    for (var i = 0; i <= segments; i++) {
      final ang = (i / segments) * 2 * math.pi;
      final wobble = 1.0 +
          0.16 * math.sin(ang * 3 + morph) +
          0.09 * math.sin(ang * 5 - morph * 0.7) +
          asym * math.sin(ang * 2 + morph * 0.4);
      final squash = 1.0 + 0.06 * math.sin(morph * 0.3);
      final x = center.dx + math.cos(ang) * baseRadius * wobble * squash;
      final y =
          center.dy + math.sin(ang) * baseRadius * wobble * (1.0 / squash);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant OrganicPatternPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tabProgress != tabProgress;
  }
}

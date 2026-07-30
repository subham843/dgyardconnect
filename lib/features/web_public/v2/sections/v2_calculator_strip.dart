// Apple strip–level BOQ / price calculator promo — store section ke turant baad.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../v2_colors.dart';
import '../v2_glass.dart';
import '../v2_tokens.dart';
import '../widgets/v2_section.dart';

class V2CalculatorStrip extends StatelessWidget {
  const V2CalculatorStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final stacked = v.width < V2Breakpoints.lg;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Price Calculator',
          style: V2FontStyles.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: V2Colors.plasma,
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.04, end: 0),
        SizedBox(height: v.r<double>(xs: 10, md: 12)),
        Text(
          'Instant pricing.\nAny product type.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 32, md: 40, lg: 48),
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
            height: 1.06,
            color: V2Colors.inkSaaS,
          ),
        ).animate(delay: 60.ms).fadeIn(duration: 520.ms).slideY(begin: 0.08, end: 0),
        SizedBox(height: v.r<double>(xs: 14, md: 18)),
        Text(
          'Select specifications — CCTV, PC assembly, networking or any admin-published calculator — '
          'and get live catalog pricing with a share-ready quote in minutes.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 15, md: 16, lg: 17),
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: -0.15,
            color: V2Colors.inkMutedSaaS,
          ),
        ).animate(delay: 120.ms).fadeIn(duration: 520.ms),
        SizedBox(height: v.r<double>(xs: 22, md: 28)),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FeatureOrb(
              delay: 180.ms,
              color: V2Colors.premiumOrange,
              icon: _LivePriceGlyph(color: V2Colors.premiumOrange),
              label: 'Live pricing',
              caption: 'Real-time rates',
            ),
            _FeatureOrb(
              delay: 260.ms,
              color: V2Colors.plasma,
              icon: _BlueprintGlyph(color: V2Colors.plasma),
              label: 'Smart kits',
              caption: 'Any product type',
            ),
            _FeatureOrb(
              delay: 340.ms,
              color: V2Colors.aurora,
              icon: _QuoteGlyph(color: V2Colors.aurora),
              label: 'PDF quote',
              caption: 'One-tap export',
            ),
          ],
        ),
        SizedBox(height: v.r<double>(xs: 24, md: 28)),
        _StripCta(
          onTap: () => context.go(RouteNames.publicCalculatorList),
        ).animate(delay: 420.ms).fadeIn(duration: 480.ms).slideY(begin: 0.06, end: 0),
      ],
    );

    final preview = const _LiveQuotePreview();

    return V2Section(
      background: Colors.white,
      borderTop: true,
      borderBottom: true,
      padTopOverride: v.r<double>(xs: 36, md: 44, lg: 52),
      padBottomOverride: v.r<double>(xs: 36, md: 44, lg: 52),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                SizedBox(height: v.r<double>(xs: 32, md: 40)),
                preview,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: copy),
                SizedBox(width: v.r<double>(xs: 28, md: 40, lg: 56)),
                Expanded(flex: 5, child: preview),
              ],
            ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _StripCta extends StatefulWidget {
  const _StripCta({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_StripCta> createState() => _StripCtaState();
}

class _StripCtaState extends State<_StripCta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: _hover
                  ? [V2Colors.plasma, V2Colors.premiumOrange]
                  : [V2Colors.inkSaaS, const Color(0xFF1E293B)],
            ),
            boxShadow: [
              BoxShadow(
                color: V2Colors.plasma.withValues(alpha: _hover ? 0.28 : 0.12),
                blurRadius: _hover ? 22 : 14,
                offset: Offset(0, _hover ? 8 : 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Open Price Calculator',
                style: V2FontStyles.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                offset: _hover ? Offset.zero : const Offset(-0.15, 0),
                child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureOrb extends StatefulWidget {
  const _FeatureOrb({
    required this.delay,
    required this.color,
    required this.icon,
    required this.label,
    required this.caption,
  });

  final Duration delay;
  final Color color;
  final Widget icon;
  final String label;
  final String caption;

  @override
  State<_FeatureOrb> createState() => _FeatureOrbState();
}

class _FeatureOrbState extends State<_FeatureOrb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _hover ? widget.color.withValues(alpha: 0.08) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover ? widget.color.withValues(alpha: 0.35) : V2Colors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 40, height: 40, child: widget.icon),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: V2FontStyles.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: V2Colors.inkSaaS,
                  ),
                ),
                Text(
                  widget.caption,
                  style: V2FontStyles.inter(
                    fontSize: 11.5,
                    color: V2Colors.inkMutedSaaS,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: widget.delay)
        .fadeIn(duration: 480.ms)
        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic);
  }
}

// --- Unique animated glyphs --------------------------------------------------

class _LivePriceGlyph extends StatefulWidget {
  const _LivePriceGlyph({required this.color});
  final Color color;

  @override
  State<_LivePriceGlyph> createState() => _LivePriceGlyphState();
}

class _LivePriceGlyphState extends State<_LivePriceGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36 + _pulse.value * 6,
              height: 36 + _pulse.value * 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.12 + _pulse.value * 0.08),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color,
                    widget.color.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  '₹',
                  style: V2FontStyles.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlueprintGlyph extends StatefulWidget {
  const _BlueprintGlyph({required this.color});
  final Color color;

  @override
  State<_BlueprintGlyph> createState() => _BlueprintGlyphState();
}

class _BlueprintGlyphState extends State<_BlueprintGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _draw;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _draw,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(40, 40),
          painter: _BlueprintPainter(progress: _draw.value, color: widget.color),
        );
      },
    );
  }
}

class _BlueprintPainter extends CustomPainter {
  _BlueprintPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()..color = color.withValues(alpha: 0.12);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 6, size.width - 8, size.height - 10),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, stroke);

    final lines = [
      [Offset(10, 14), Offset(size.width - 10, 14)],
      [Offset(10, 22), Offset(size.width - 18, 22)],
      [Offset(10, 30), Offset(size.width - 26, 30)],
    ];

    for (var i = 0; i < lines.length; i++) {
      final t = ((progress * 3) - i).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final start = lines[i][0];
      final end = lines[i][1];
      final mid = Offset.lerp(start, end, t)!;
      canvas.drawLine(start, mid, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _QuoteGlyph extends StatefulWidget {
  const _QuoteGlyph({required this.color});
  final Color color;

  @override
  State<_QuoteGlyph> createState() => _QuoteGlyphState();
}

class _QuoteGlyphState extends State<_QuoteGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _flip;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final lift = math.sin(_flip.value * math.pi * 2) * 2;
        return Transform.translate(
          offset: Offset(0, lift),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: widget.color.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 14, height: 2, color: widget.color.withValues(alpha: 0.5)),
                    const SizedBox(height: 3),
                    Container(width: 10, height: 2, color: widget.color.withValues(alpha: 0.35)),
                  ],
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Live quote preview card -------------------------------------------------

class _LiveQuotePreview extends StatelessWidget {
  const _LiveQuotePreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: v2BlurLayer(
        sigma: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                const Color(0xFFF8FAFC).withValues(alpha: 0.96),
              ],
            ),
            border: Border.all(color: V2Colors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: V2Colors.plasma.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: V2Colors.emberGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CCTV BOQ — Live Estimate',
                        style: V2FontStyles.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: V2Colors.inkSaaS,
                        ),
                      ),
                    ),
                    _LiveBadge(),
                  ],
                ),
                const SizedBox(height: 18),
                const _PreviewRow(label: 'Coverage area', value: '2,400 sq ft', delay: 200),
                const _PreviewRow(label: 'Cameras', value: '8 × 4MP Dome', delay: 320),
                const _PreviewRow(label: 'Recorder', value: '8-Ch NVR · 4TB', delay: 440),
                const _PreviewRow(label: 'Cabling', value: '300 m Cat-6', delay: 560),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: V2Colors.premiumOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: V2Colors.premiumOrange.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹ xx,xxx',
                          style: V2FontStyles.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: V2Colors.inkSaaS,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: V2Colors.inkSaaS,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Add to cart',
                          style: V2FontStyles.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 640.ms).fadeIn(duration: 480.ms).slideY(begin: 0.04, end: 0),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: 200.ms)
        .fadeIn(duration: 650.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic)
        .shimmer(duration: 1800.ms, delay: 800.ms, color: Colors.white.withValues(alpha: 0.35));
  }
}

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: V2Colors.aurora.withValues(alpha: 0.1 + _blink.value * 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: V2Colors.aurora.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: V2Colors.aurora.withValues(alpha: 0.6 + _blink.value * 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'LIVE',
                style: V2FontStyles.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: V2Colors.aurora,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.delay,
  });

  final String label;
  final String value;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: V2FontStyles.inter(fontSize: 12.5, color: V2Colors.inkMutedSaaS),
            ),
          ),
          Text(
            value,
            style: V2FontStyles.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: V2Colors.inkSaaS,
            ),
          ),
        ],
      ),
    )
        .animate(delay: delay.ms)
        .fadeIn(duration: 420.ms)
        .slideX(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }
}

// D.G.Yard Connect — world-class intro strip (calculator ke baad).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../shared/widgets/organic_pattern_background.dart';
import '../v2_colors.dart';
import '../v2_glass.dart';
import '../v2_tokens.dart';
import '../widgets/v2_section.dart';

class V2ConnectIntro extends StatefulWidget {
  const V2ConnectIntro({super.key});

  @override
  State<V2ConnectIntro> createState() => _V2ConnectIntroState();
}

class _V2ConnectIntroState extends State<V2ConnectIntro> with TickerProviderStateMixin {
  late final AnimationController _organic;
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _organic = AnimationController(vsync: this, duration: const Duration(seconds: 22))
      ..repeat();
    _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
  }

  @override
  void dispose() {
    _organic.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final mobile = v.width < V2Breakpoints.lg;

    if (mobile) {
      return V2Section(
        background: Colors.white,
        borderTop: true,
        borderBottom: true,
        padTopOverride: v.r<double>(xs: 32, md: 40),
        padBottomOverride: v.r<double>(xs: 32, md: 40),
        child: _MobileConnectLayout(v: v),
      ).animate().fadeIn(duration: 500.ms);
    }

    final cardRadius = v.r<double>(xs: 32, md: 32, lg: 36);
    final cardMarginH = v.r<double>(xs: 0, md: 28, lg: 40, xl: 48);

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 6, child: _ConnectCopy(v: v)),
        SizedBox(width: v.r<double>(xs: 24, md: 40, lg: 48)),
        Expanded(
          flex: 5,
          child: _ConnectOrbitVisual(
            orbit: _orbit,
            height: v.r<double>(xs: 380, md: 380, lg: 420),
          ),
        ),
      ],
    );

    return ClipRect(
      child: V2Section(
        background: OrganicPatternPainter.kBase,
        borderTop: true,
        borderBottom: true,
        padTopOverride: v.r<double>(xs: 36, md: 36, lg: 40),
        padBottomOverride: v.r<double>(xs: 36, md: 36, lg: 40),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: cardMarginH),
          child: _ConnectGlassCard(
            radius: cardRadius,
            organic: _organic,
            child: Padding(
              padding: EdgeInsets.all(v.r<double>(xs: 26, md: 26, lg: 32)),
              child: content,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

/// Mobile — clean Apple strip (matches calculator section above).
class _MobileConnectLayout extends StatelessWidget {
  const _MobileConnectLayout({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'D.G.Yard Connect',
          style: V2FontStyles.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: V2Colors.aurora,
          ),
        ).animate().fadeIn(duration: 400.ms),
        SizedBox(height: v.r<double>(xs: 10, md: 12)),
        Text(
          'Hire verified\ntechnicians. Fast.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 28, sm: 32, md: 36),
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.06,
            color: V2Colors.inkSaaS,
          ),
        ).animate(delay: 60.ms).fadeIn(duration: 520.ms).slideY(begin: 0.06, end: 0),
        SizedBox(height: v.r<double>(xs: 12, md: 14)),
        Text(
          'Post jobs, get bids from verified pros, and track work to completion — all in one app.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 15, md: 16),
            height: 1.5,
            letterSpacing: -0.12,
            color: V2Colors.inkMutedSaaS,
          ),
        ).animate(delay: 120.ms).fadeIn(duration: 480.ms),
        SizedBox(height: v.r<double>(xs: 20, md: 24)),
        const _MobileFeatureOrbs(),
        SizedBox(height: v.r<double>(xs: 24, md: 28)),
        const _MobileFlowTimeline(),
        SizedBox(height: v.r<double>(xs: 24, md: 28)),
        _MobilePrimaryCta(onTap: () => context.go(RouteNames.phoneEntry))
            .animate(delay: 280.ms)
            .fadeIn(duration: 480.ms),
        const SizedBox(height: 10),
        _MobileOutlineCta(
          label: 'Become a Technician',
          onTap: () => context.go(RouteNames.registerTechnician),
        ).animate(delay: 320.ms).fadeIn(duration: 480.ms),
        SizedBox(height: v.r<double>(xs: 24, md: 28)),
        const _MobileStatBar(),
      ],
    );
  }
}

class _MobileFeatureOrbs extends StatelessWidget {
  const _MobileFeatureOrbs();

  static const _items = [
    (Icons.verified_user_rounded, 'Verified', V2Colors.aurora),
    (Icons.location_on_rounded, 'Live track', V2Colors.plasma),
    (Icons.payments_rounded, 'Secure pay', V2Colors.premiumOrange),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in _items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: V2Colors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 18, color: item.$3),
                const SizedBox(width: 8),
                Text(
                  item.$2,
                  style: V2FontStyles.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: V2Colors.inkSaaS,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).animate(delay: 160.ms).fadeIn(duration: 480.ms);
  }
}

class _MobileFlowTimeline extends StatelessWidget {
  const _MobileFlowTimeline();

  static const _steps = [
    ('01', 'Post job', 'Scope & location'),
    ('02', 'Get bids', 'Verified techs respond'),
    ('03', 'Done', 'Track, rate & pay'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 2, height: 16, color: V2Colors.borderSubtle),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: V2Colors.auroraSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: V2Colors.aurora.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _steps[i].$1,
                  style: V2FontStyles.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: V2Colors.aurora,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i].$2,
                        style: V2FontStyles.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: V2Colors.inkSaaS,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _steps[i].$3,
                        style: V2FontStyles.inter(
                          fontSize: 13,
                          color: V2Colors.inkMutedSaaS,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ).animate(delay: 200.ms).fadeIn(duration: 500.ms);
  }
}

class _MobilePrimaryCta extends StatelessWidget {
  const _MobilePrimaryCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: V2Colors.inkSaaS,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.engineering_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Find a Technician',
                style: V2FontStyles.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileOutlineCta extends StatelessWidget {
  const _MobileOutlineCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V2Colors.borderStrong),
          ),
          child: Text(
            label,
            style: V2FontStyles.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: V2Colors.inkSaaS,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileStatBar extends StatelessWidget {
  const _MobileStatBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: V2Colors.borderSubtle),
      ),
      child: Row(
        children: [
          const Expanded(
            child: _MobileStatCell(value: '300+', label: 'Technicians'),
          ),
          Container(width: 1, height: 36, color: V2Colors.borderSubtle),
          const Expanded(
            child: _MobileStatCell(value: 'Live', label: 'Tracking'),
          ),
          Container(width: 1, height: 36, color: V2Colors.borderSubtle),
          const Expanded(
            child: _MobileStatCell(value: 'KYC', label: 'Verified'),
          ),
        ],
      ),
    ).animate(delay: 360.ms).fadeIn(duration: 480.ms);
  }
}

class _MobileStatCell extends StatelessWidget {
  const _MobileStatCell({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: V2FontStyles.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: V2Colors.inkSaaS,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: V2FontStyles.inter(
            fontSize: 11,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
      ],
    );
  }
}

/// Frosted glass card — organic animation clipped inside card bounds only.
class _ConnectGlassCard extends StatelessWidget {
  const _ConnectGlassCard({
    required this.radius,
    required this.organic,
    required this.child,
  });

  final double radius;
  final Animation<double> organic;
  final Widget child;

  static const _blurSigma = 26.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: V2Colors.plasma.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: organic,
                builder: (_, _) => CustomPaint(
                  painter: OrganicPatternPainter(
                    organic.value,
                    tabProgress: 0,
                  ),
                ),
              ),
            ),
            v2BlurLayer(
              sigma: _blurSigma,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: Colors.white.withValues(alpha: 0.58),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                    width: 1.25,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.42),
                              Colors.white.withValues(alpha: 0.06),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectCopy extends StatelessWidget {
  const _ConnectCopy({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ConnectBadge()
            .animate()
            .fadeIn(duration: 450.ms)
            .slideX(begin: -0.06, end: 0, curve: Curves.easeOutCubic),
        SizedBox(height: v.r<double>(xs: 16, md: 20)),
        _GradientHeadline(
          fontSize: v.r<double>(xs: 34, md: 42, lg: 50),
        ).animate(delay: 80.ms).fadeIn(duration: 550.ms).slideY(begin: 0.1, end: 0),
        SizedBox(height: v.r<double>(xs: 14, md: 18)),
        Text(
          'India\'s verified marketplace for IT & security professionals. '
          'Dealers post jobs, technicians bid with confidence, and work gets done — tracked, rated, and paid in one ecosystem.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 15, md: 16, lg: 17),
            height: 1.6,
            letterSpacing: -0.12,
            color: V2Colors.inkMutedSaaS,
          ),
        ).animate(delay: 160.ms).fadeIn(duration: 520.ms),
        SizedBox(height: v.r<double>(xs: 24, md: 28)),
        const _FlowRail(),
        SizedBox(height: v.r<double>(xs: 28, md: 32)),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FindTechnicianCta(
              onTap: () => context.go(RouteNames.phoneEntry),
            ).animate(delay: 380.ms).fadeIn(duration: 480.ms).slideY(begin: 0.08, end: 0),
            _OutlineCta(
              label: 'Become a Technician',
              onTap: () => context.go(RouteNames.registerTechnician),
            ).animate(delay: 440.ms).fadeIn(duration: 480.ms),
          ],
        ),
        SizedBox(height: v.r<double>(xs: 28, md: 32)),
        const _StatStrip(),
      ],
    );
  }
}

class _ConnectBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: v2BlurLayer(
        sigma: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: V2Colors.auroraSubtle,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: V2Colors.aurora.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: V2Colors.aurora,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: V2Colors.aurora.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'D.G.Yard Connect',
                style: V2FontStyles.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: V2Colors.inkSaaS,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientHeadline extends StatelessWidget {
  const _GradientHeadline({required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [V2Colors.inkSaaS, V2Colors.inkSaaS, V2Colors.plasma, V2Colors.aurora],
      ).createShader(bounds),
      child: Text(
        'Hire Verified\nTechnicians. Fast.',
        style: V2FontStyles.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -1.6,
          color: V2Colors.inkSaaS,
        ),
      ),
    );
  }
}

class _FlowRail extends StatelessWidget {
  const _FlowRail();

  static const _steps = [
    _FlowStepData('01', 'Post job', 'Describe scope & location'),
    _FlowStepData('02', 'Match', 'Verified techs bid instantly'),
    _FlowStepData('03', 'Done', 'Track, rate & pay securely'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _steps.length; i++)
          _FlowStepCard(data: _steps[i], index: i),
      ],
    );
  }
}

class _FlowStepData {
  const _FlowStepData(this.num, this.title, this.sub);
  final String num;
  final String title;
  final String sub;
}

class _FlowStepCard extends StatefulWidget {
  const _FlowStepCard({required this.data, required this.index});
  final _FlowStepData data;
  final int index;

  @override
  State<_FlowStepCard> createState() => _FlowStepCardState();
}

class _FlowStepCardState extends State<_FlowStepCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: 168,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: _hover ? 0.88 : 0.72),
              Colors.white.withValues(alpha: _hover ? 0.62 : 0.48),
            ],
          ),
          border: Border.all(
            color: _hover
                ? V2Colors.plasma.withValues(alpha: 0.4)
                : V2Colors.borderSubtle,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: V2Colors.plasma.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : V2Colors.shadowXs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.data.num,
              style: V2FontStyles.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: V2Colors.aurora,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.data.title,
              style: V2FontStyles.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: V2Colors.inkSaaS,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.data.sub,
              style: V2FontStyles.inter(
                fontSize: 11.5,
                height: 1.35,
                color: V2Colors.inkMutedSaaS,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (220 + widget.index * 90).ms)
        .fadeIn(duration: 480.ms)
        .slideY(begin: 0.14, end: 0, curve: Curves.easeOutCubic);
  }
}

class _FindTechnicianCta extends StatefulWidget {
  const _FindTechnicianCta({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_FindTechnicianCta> createState() => _FindTechnicianCtaState();
}

class _FindTechnicianCtaState extends State<_FindTechnicianCta>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _sheen;

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _sheen,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment(-1 + _sheen.value * 2, 0),
                  end: Alignment(1 + _sheen.value * 2, 0),
                  colors: [
                    V2Colors.aurora,
                    V2Colors.plasma,
                    V2Colors.premiumOrange,
                    V2Colors.aurora,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: V2Colors.aurora.withValues(alpha: _hover ? 0.45 : 0.22),
                    blurRadius: _hover ? 28 : 16,
                    offset: Offset(0, _hover ? 10 : 6),
                  ),
                ],
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.symmetric(
                  horizontal: _hover ? 26 : 22,
                  vertical: _hover ? 15 : 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _hover ? V2Colors.plasma : Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.engineering_rounded,
                      size: 18,
                      color: _hover ? Colors.white : V2Colors.aurora,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Find a Technician',
                      style: V2FontStyles.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _hover ? Colors.white : V2Colors.inkSaaS,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _hover ? Colors.white : V2Colors.inkMutedSaaS,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OutlineCta extends StatefulWidget {
  const _OutlineCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_OutlineCta> createState() => _OutlineCtaState();
}

class _OutlineCtaState extends State<_OutlineCta> {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _hover ? V2Colors.plasma : V2Colors.borderStrong,
            ),
            color: _hover ? V2Colors.plasmaSubtle : Colors.white.withValues(alpha: 0.85),
          ),
          child: Text(
            widget.label,
            style: V2FontStyles.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: V2Colors.inkSaaS,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip();

  static const _stats = [
    ('300+', 'Verified technicians'),
    ('Live', 'Job tracking & chat'),
    ('KYC', 'Background verified'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        for (var i = 0; i < _stats.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _stats[i].$1,
                style: V2FontStyles.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: V2Colors.inkSaaS,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _stats[i].$2,
                style: V2FontStyles.inter(
                  fontSize: 12.5,
                  color: V2Colors.inkMutedSaaS,
                ),
              ),
            ],
          )
              .animate(delay: (500 + i * 80).ms)
              .fadeIn(duration: 420.ms)
              .slideX(begin: 0.06, end: 0),
      ],
    );
  }
}

// --- Orbit visual -----------------------------------------------------------

class _ConnectOrbitVisual extends StatelessWidget {
  const _ConnectOrbitVisual({required this.orbit, required this.height});
  final Animation<double> orbit;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final cx = w / 2;
          final cy = h / 2;
          final orbitR = math.min(w, h) * 0.38;

          Offset nodePos(double angle) {
            return Offset(
              cx + math.cos(angle) * orbitR - 52,
              cy + math.sin(angle) * orbitR - 28,
            );
          }

          return AnimatedBuilder(
            animation: orbit,
            builder: (context, _) {
              final phase = orbit.value;
              final base = phase * math.pi * 2;

              final dealer = nodePos(base);
              final tech = nodePos(base + 2.1);
              final verified = nodePos(base + 4.2);

              return CustomPaint(
                painter: _ConnectNetworkPainter(phase: phase),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(left: dealer.dx, top: dealer.dy, child: const _OrbitNodeChip(
                      label: 'Dealer',
                      icon: Icons.storefront_rounded,
                      color: V2Colors.plasma,
                    )),
                    Positioned(left: tech.dx, top: tech.dy, child: const _OrbitNodeChip(
                      label: 'Technician',
                      icon: Icons.handyman_rounded,
                      color: V2Colors.aurora,
                    )),
                    Positioned(left: verified.dx, top: verified.dy, child: const _OrbitNodeChip(
                      label: 'Verified',
                      icon: Icons.verified_rounded,
                      color: V2Colors.premiumOrange,
                    )),
                    _HubCard(),
                  ],
                ),
              );
            },
          );
        },
      ),
    )
        .animate(delay: 200.ms)
        .fadeIn(duration: 700.ms)
        .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }
}

class _OrbitNodeChip extends StatelessWidget {
  const _OrbitNodeChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: v2BlurLayer(
        sigma: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: V2FontStyles.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: V2Colors.inkSaaS,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: v2BlurLayer(
        sigma: 20,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.95),
            border: Border.all(color: V2Colors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: V2Colors.plasma.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [V2Colors.plasma, V2Colors.aurora.withValues(alpha: 0.85)],
                  ),
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect Hub',
                style: V2FontStyles.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: V2Colors.inkSaaS,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Jobs · Bids · Payouts',
                textAlign: TextAlign.center,
                style: V2FontStyles.inter(
                  fontSize: 11.5,
                  color: V2Colors.inkMutedSaaS,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Painters ---------------------------------------------------------------

class _ConnectNetworkPainter extends CustomPainter {
  _ConnectNetworkPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.38;

    final nodes = List.generate(3, (i) {
      final a = phase * math.pi * 2 + i * 2.1;
      return Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
    });

    final linePaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < nodes.length; i++) {
      linePaint.shader = LinearGradient(
        colors: [
          V2Colors.plasma.withValues(alpha: 0.55),
          V2Colors.aurora.withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromPoints(center, nodes[i]));
      canvas.drawLine(center, nodes[i], linePaint);

      final pulse = (phase + i * 0.33) % 1.0;
      final pulsePos = Offset.lerp(center, nodes[i], pulse)!;
      canvas.drawCircle(
        pulsePos,
        3.5,
        Paint()..color = V2Colors.aurora.withValues(alpha: 0.85),
      );
    }

    canvas.drawCircle(
      center,
      36,
      Paint()
        ..color = V2Colors.plasma.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectNetworkPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

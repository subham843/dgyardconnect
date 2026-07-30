// Digital Marketing + Software / Web / App — cinematic tech showcase.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';

enum _ServiceKind { marketing, software, web, app }

class V2DigitalServices extends StatefulWidget {
  const V2DigitalServices({super.key});

  @override
  State<V2DigitalServices> createState() => _V2DigitalServicesState();
}

class _V2DigitalServicesState extends State<V2DigitalServices>
    with TickerProviderStateMixin {
  late final AnimationController _bg;
  late final AnimationController _border;
  late final AnimationController _scene;

  Offset _spotlight = Offset.zero;
  bool _hasSpotlight = false;

  static const _services = [
    _ServiceData(
      kind: _ServiceKind.marketing,
      title: 'Digital Marketing',
      subtitle: 'SEO, paid media, social & funnels engineered for ROI.',
      color: Color(0xFFEC4899),
      accent: Color(0xFFF472B6),
      tags: ['SEO', 'Meta Ads', 'Analytics'],
      metric: '+284%',
      metricLabel: 'avg. lead lift',
    ),
    _ServiceData(
      kind: _ServiceKind.software,
      title: 'Software Development',
      subtitle: 'ERP, CRM & automation — cloud-native, API-first architecture.',
      color: Color(0xFF6366F1),
      accent: Color(0xFF818CF8),
      tags: ['Cloud', 'APIs', 'Integrations'],
      metric: '99.9%',
      metricLabel: 'uptime SLA',
    ),
    _ServiceData(
      kind: _ServiceKind.web,
      title: 'Web Development',
      subtitle: 'Flutter & React experiences — blazing fast, pixel-perfect.',
      color: Color(0xFF0EA5E9),
      accent: Color(0xFF38BDF8),
      tags: ['Flutter Web', 'E‑commerce', 'CMS'],
      metric: '<1.2s',
      metricLabel: 'LCP target',
    ),
    _ServiceData(
      kind: _ServiceKind.app,
      title: 'App Development',
      subtitle: 'Native-feel Android & iOS apps for your brand ecosystem.',
      color: Color(0xFF10B981),
      accent: Color(0xFF34D399),
      tags: ['Android', 'iOS', 'Cross‑platform'],
      metric: '4.8★',
      metricLabel: 'store rating',
    ),
  ];

  static const _marqueeTags = [
    'Flutter', 'React', 'Node.js', 'AWS', 'Firebase', 'SEO', 'Meta Ads',
    'PostgreSQL', 'Supabase', 'REST APIs', 'GraphQL', 'CI/CD', 'Figma',
    'Kotlin', 'Swift', 'Dart', 'TypeScript', 'Docker', 'Analytics',
  ];

  @override
  void initState() {
    super.initState();
    _bg = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
    _border = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _scene = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _bg.dispose();
    _border.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.lg;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: V2Colors.saasBg,
        border: Border(top: BorderSide(color: V2Colors.border)),
      ),
      child: RepaintBoundary(
        child: ClipRect(
          child: MouseRegion(
            onHover: (e) => setState(() {
              _spotlight = e.localPosition;
              _hasSpotlight = true;
            }),
            onExit: (_) => setState(() => _hasSpotlight = false),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _bg,
                    builder: (_, _) => CustomPaint(
                      painter: _TechCanvasPainter(phase: _bg.value),
                      size: Size.infinite,
                    ),
                  ),
                ),
                if (_hasSpotlight)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(
                              (_spotlight.dx / v.width) * 2 - 1,
                              (_spotlight.dy / 400) * 2 - 1,
                            ),
                            radius: 0.55,
                            colors: [
                              V2Colors.plasma.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    v.gutter,
                    v.r<double>(xs: 48, md: 56, lg: 72),
                    v.gutter,
                    v.r<double>(xs: 48, md: 56, lg: 72),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionHeader(
                            v: v,
                            onExplore: () => context.go(RouteNames.publicServices),
                          ),
                          SizedBox(height: v.r<double>(xs: 28, md: 36)),
                          _TechMarquee(tags: _marqueeTags, phase: _bg.value),
                          SizedBox(height: v.r<double>(xs: 32, md: 44, lg: 52)),
                          AnimatedBuilder(
                            animation: Listenable.merge([_border, _scene]),
                            builder: (context, _) {
                              if (wide) {
                                return _DesktopBento(
                                  services: _services,
                                  borderPhase: _border.value,
                                  scenePhase: _scene.value,
                                  onTap: () => context.go(RouteNames.publicServices),
                                );
                              }
                              return _MobileStack(
                                services: _services,
                                borderPhase: _border.value,
                                scenePhase: _scene.value,
                                onTap: () => context.go(RouteNames.publicServices),
                              );
                            },
                          ),
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
    ).animate().fadeIn(duration: 600.ms);
  }
}

// --- Data -------------------------------------------------------------------

class _ServiceData {
  const _ServiceData({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.accent,
    required this.tags,
    required this.metric,
    required this.metricLabel,
  });

  final _ServiceKind kind;
  final String title;
  final String subtitle;
  final Color color;
  final Color accent;
  final List<String> tags;
  final String metric;
  final String metricLabel;
}

// --- Header -----------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.v, required this.onExplore});
  final V2Responsive v;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final wide = v.width >= V2Breakpoints.md;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF12182A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: V2Colors.plasma.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: V2Colors.aurora,
              boxShadow: [
                BoxShadow(
                  color: V2Colors.aurora.withValues(alpha: 0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'DIGITAL STUDIO',
            style: V2FontStyles.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
    ).animate().fadeIn(duration: 450.ms);

    final headline = ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          const Color(0xFFE2E8F0),
          V2Colors.plasmaSoft,
          V2Colors.auroraSoft,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(bounds),
      child: Text(
        'Engineered for\ngrowth at scale.',
        style: V2FontStyles.inter(
          fontSize: v.r<double>(xs: 32, md: 40, lg: 48),
          fontWeight: FontWeight.w800,
          height: 1.04,
          letterSpacing: -1.6,
          color: Colors.white,
        ),
      ),
    ).animate(delay: 80.ms).fadeIn(duration: 550.ms).slideY(begin: 0.1, end: 0);

    final sub = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Text(
        'From performance marketing to production-grade software — we build the digital infrastructure your business runs on.',
        style: V2FontStyles.inter(
          fontSize: v.r<double>(xs: 15, md: 16),
          height: 1.6,
          color: Colors.white.withValues(alpha: 0.62),
        ),
      ),
    ).animate(delay: 160.ms).fadeIn(duration: 500.ms);

    final cta = _GlowCta(onTap: onExplore).animate(delay: 240.ms).fadeIn(duration: 480.ms);

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [badge, const SizedBox(height: 18), headline, const SizedBox(height: 14), sub],
            ),
          ),
          const SizedBox(width: 32),
          cta,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge,
        const SizedBox(height: 18),
        headline,
        const SizedBox(height: 14),
        sub,
        const SizedBox(height: 22),
        cta,
      ],
    );
  }
}

class _GlowCta extends StatefulWidget {
  const _GlowCta({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_GlowCta> createState() => _GlowCtaState();
}

class _GlowCtaState extends State<_GlowCta> {
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
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: _hover
                  ? [V2Colors.plasma, V2Colors.plasmaSoft]
                  : [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.08)],
            ),
            border: Border.all(
              color: _hover ? V2Colors.plasmaSoft : Colors.white.withValues(alpha: 0.22),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: V2Colors.plasma.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Explore all services',
                style: V2FontStyles.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Marquee ----------------------------------------------------------------

class _TechMarquee extends StatelessWidget {
  const _TechMarquee({required this.tags, required this.phase});
  final List<String> tags;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final doubled = [...tags, ...tags];
    final offset = (phase * 1200) % 600;

    return ClipRect(
      child: SizedBox(
        height: 36,
        child: Stack(
          children: [
            Positioned(
              left: -offset,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  for (final tag in doubled)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _MarqueeChip(label: tag),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF030712),
                        Colors.transparent,
                        Colors.transparent,
                        const Color(0xFF030712),
                      ],
                      stops: const [0.0, 0.08, 0.92, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 500.ms);
  }
}

class _MarqueeChip extends StatelessWidget {
  const _MarqueeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: V2FontStyles.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.55),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// --- Layouts ------------------------------------------------------------------

class _DesktopBento extends StatelessWidget {
  const _DesktopBento({
    required this.services,
    required this.borderPhase,
    required this.scenePhase,
    required this.onTap,
  });

  final List<_ServiceData> services;
  final double borderPhase;
  final double scenePhase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const gap = 18.0;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 58,
                child: _HoloServiceCard(
                  data: services[0],
                  index: 0,
                  borderPhase: borderPhase,
                  scenePhase: scenePhase,
                  tall: true,
                  onTap: onTap,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                flex: 42,
                child: Column(
                  children: [
                    Expanded(
                      child: _HoloServiceCard(
                        data: services[1],
                        index: 1,
                        borderPhase: borderPhase,
                        scenePhase: scenePhase,
                        onTap: onTap,
                      ),
                    ),
                    const SizedBox(height: gap),
                    Expanded(
                      child: _HoloServiceCard(
                        data: services[2],
                        index: 2,
                        borderPhase: borderPhase,
                        scenePhase: scenePhase,
                        onTap: onTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: gap),
        SizedBox(
          height: 240,
          child: _HoloServiceCard(
            data: services[3],
            index: 3,
            borderPhase: borderPhase,
            scenePhase: scenePhase,
            wide: true,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _MobileStack extends StatelessWidget {
  const _MobileStack({
    required this.services,
    required this.borderPhase,
    required this.scenePhase,
    required this.onTap,
  });

  final List<_ServiceData> services;
  final double borderPhase;
  final double scenePhase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < services.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _HoloServiceCard(
            data: services[i],
            index: i,
            borderPhase: borderPhase,
            scenePhase: scenePhase,
            onTap: onTap,
          ),
        ],
      ],
    );
  }
}

// --- Holographic card -------------------------------------------------------

class _HoloServiceCard extends StatefulWidget {
  const _HoloServiceCard({
    required this.data,
    required this.index,
    required this.borderPhase,
    required this.scenePhase,
    required this.onTap,
    this.tall = false,
    this.wide = false,
  });

  final _ServiceData data;
  final int index;
  final double borderPhase;
  final double scenePhase;
  final VoidCallback onTap;
  final bool tall;
  final bool wide;

  @override
  State<_HoloServiceCard> createState() => _HoloServiceCardState();
}

class _HoloServiceCardState extends State<_HoloServiceCard> {
  bool _hover = false;
  Offset _tilt = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final visualH = widget.tall ? 180.0 : (widget.wide ? 120.0 : 110.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _tilt = Offset.zero;
      }),
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(e.position);
        final nx = (local.dx / box.size.width - 0.5) * 2;
        final ny = (local.dy / box.size.height - 0.5) * 2;
        setState(() => _tilt = Offset(nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0)));
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(-_tilt.dy * 0.06)
            ..rotateY(_tilt.dx * 0.06)
            ..translateByDouble(0.0, _hover ? -6.0 : 0.0, 0.0, 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: d.color.withValues(alpha: _hover ? 0.35 : 0.12),
                  blurRadius: _hover ? 40 : 20,
                  offset: Offset(0, _hover ? 16 : 8),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _HoloBorderPainter(
                phase: widget.borderPhase + widget.index * 0.15,
                color: d.color,
                accent: d.accent,
                hover: _hover,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1E).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CardGridPainter(
                              color: d.color,
                              phase: widget.scenePhase,
                            ),
                          ),
                        ),
                        if (_hover)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(_tilt.dx, _tilt.dy),
                                  radius: 0.85,
                                  colors: [
                                    d.color.withValues(alpha: 0.18),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: widget.wide
                              ? _WideCardBody(
                                  data: d,
                                  visualH: visualH,
                                  scenePhase: widget.scenePhase,
                                  hover: _hover,
                                )
                              : _CardBody(
                                  data: d,
                                  visualH: visualH,
                                  scenePhase: widget.scenePhase,
                                  hover: _hover,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    )
        .animate(delay: (180 + widget.index * 110).ms)
        .fadeIn(duration: 580.ms)
        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic);
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.data,
    required this.visualH,
    required this.scenePhase,
    required this.hover,
  });

  final _ServiceData data;
  final double visualH;
  final double scenePhase;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: visualH,
          child: _ServiceScene(kind: data.kind, color: data.color, phase: scenePhase),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: V2FontStyles.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: V2FontStyles.inter(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ),
            ),
            _MetricBadge(data: data, hover: hover),
          ],
        ),
        const SizedBox(height: 14),
        _TagRow(tags: data.tags, color: data.color),
      ],
    );
  }
}

class _WideCardBody extends StatelessWidget {
  const _WideCardBody({
    required this.data,
    required this.visualH,
    required this.scenePhase,
    required this.hover,
  });

  final _ServiceData data;
  final double visualH;
  final double scenePhase;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: V2FontStyles.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.subtitle,
                style: V2FontStyles.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 16),
              _TagRow(tags: data.tags, color: data.color),
              const Spacer(),
              _MetricBadge(data: data, hover: hover),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: SizedBox(
            height: visualH + 40,
            child: _ServiceScene(kind: data.kind, color: data.color, phase: scenePhase),
          ),
        ),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.data, required this.hover});
  final _ServiceData data;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: hover ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withValues(alpha: hover ? 0.5 : 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            data.metric,
            style: V2FontStyles.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: data.accent,
            ),
          ),
          Text(
            data.metricLabel,
            style: V2FontStyles.inter(
              fontSize: 9.5,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags, required this.color});
  final List<String> tags;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Text(
              tag,
              style: V2FontStyles.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.92),
              ),
            ),
          ),
      ],
    );
  }
}

// --- Service scene visuals --------------------------------------------------

class _ServiceScene extends StatelessWidget {
  const _ServiceScene({required this.kind, required this.color, required this.phase});
  final _ServiceKind kind;
  final Color color;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: switch (kind) {
          _ServiceKind.marketing => _MarketingScenePainter(color: color, phase: phase),
          _ServiceKind.software => _SoftwareScenePainter(color: color, phase: phase),
          _ServiceKind.web => _WebScenePainter(color: color, phase: phase),
          _ServiceKind.app => _AppScenePainter(color: color, phase: phase),
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MarketingScenePainter extends CustomPainter {
  _MarketingScenePainter({required this.color, required this.phase});
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.06));

    final bars = 7;
    final barW = (size.width - 32) / bars;
    for (var i = 0; i < bars; i++) {
      final h = size.height * (0.25 + 0.55 * math.sin((phase + i * 0.12) * math.pi * 2).abs());
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(16 + i * barW, size.height - 16 - h, barW * 0.55, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [color.withValues(alpha: 0.35), color],
          ).createShader(rect.outerRect),
      );
    }

    final path = Path();
    for (var i = 0; i <= 20; i++) {
      final t = i / 20;
      final x = 16 + t * (size.width - 32);
      final y = size.height * 0.35 - math.sin((t + phase) * math.pi * 2) * 18;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < 3; i++) {
      final r = 28 + i * 22 + math.sin((phase + i * 0.3) * math.pi * 2) * 6;
      canvas.drawCircle(
        Offset(size.width * 0.78, size.height * 0.28),
        r,
        Paint()
          ..color = color.withValues(alpha: 0.06 - i * 0.015)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarketingScenePainter old) =>
      old.phase != phase || old.color != color;
}

class _SoftwareScenePainter extends CustomPainter {
  _SoftwareScenePainter({required this.color, required this.phase});
  final Color color;
  final double phase;

  static const _lines = [
    'import { deploy } from "@dgyard/cloud";',
    'const stack = await deploy({',
    '  runtime: "node20", scale: "auto",',
    '  regions: ["ap-south-1", "eu-west-1"],',
    '});',
    'console.log(stack.status); // ✓ live',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFF050810),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, 28),
        const Radius.circular(12),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(14 + i * 14.0, 14),
        4,
        Paint()..color = [const Color(0xFFFF5F57), const Color(0xFFFEBC2E), const Color(0xFF28C840)][i],
      );
    }

    final mono = TextPainter(textDirection: TextDirection.ltr);
    final visibleLines = (phase * _lines.length * 1.2).floor() % (_lines.length + 1);

    for (var i = 0; i < _lines.length; i++) {
      if (i >= visibleLines) break;
      final alpha = i == visibleLines - 1 ? 0.45 + (phase % 0.4) : 0.85;
      mono.text = TextSpan(
        text: _lines[i],
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          color: i == _lines.length - 1
              ? V2Colors.aurora.withValues(alpha: alpha)
              : color.withValues(alpha: alpha),
        ),
      );
      mono.layout(maxWidth: size.width - 20);
      mono.paint(canvas, Offset(12, 38 + i * 16.0));
    }

    if (visibleLines < _lines.length + 1) {
      final blink = (phase * 4).floor() % 2 == 0;
      if (blink) {
        canvas.drawRect(
          Rect.fromLTWH(12, 38 + visibleLines.clamp(0, _lines.length) * 16.0, 7, 12),
          Paint()..color = color.withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SoftwareScenePainter old) =>
      old.phase != phase || old.color != color;
}

class _WebScenePainter extends CustomPainter {
  _WebScenePainter({required this.color, required this.phase});
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(10),
    );
    canvas.drawRRect(frame, Paint()..color = Colors.white.withValues(alpha: 0.04));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawRect(
      Rect.fromLTWH(8, 8, size.width - 16, 22),
      Paint()..color = color.withValues(alpha: 0.15),
    );

    final progress = (math.sin(phase * math.pi * 2) * 0.5 + 0.5);
    final contentY = 38.0;

    for (var i = 0; i < 3; i++) {
      final w = size.width * (0.35 + i * 0.12) * progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(20, contentY + i * 22, w, 10),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.08 + i * 0.04),
      );
    }

    final loadW = (size.width - 48) * progress;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, size.height - 36, loadW, 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = color,
    );

    canvas.drawCircle(
      Offset(size.width - 28, size.height - 38),
      6,
      Paint()..color = color.withValues(alpha: 0.25 + progress * 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _WebScenePainter old) =>
      old.phase != phase || old.color != color;
}

class _AppScenePainter extends CustomPainter {
  _AppScenePainter({required this.color, required this.phase});
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 72,
        height: 120,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(phone, Paint()..color = const Color(0xFF050810));
    canvas.drawRRect(
      phone,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, size.height / 2 - 42), width: 24, height: 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final bounce = math.sin((phase + row + col * 0.2) * math.pi * 2) * 3;
        final cx = size.width / 2 - 22 + col * 22;
        final cy = size.height / 2 - 10 + row * 26 + bounce;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: 16, height: 16),
            const Radius.circular(5),
          ),
          Paint()..color = Color.lerp(color, V2Colors.plasma, (row + col) / 5)!,
        );
      }
    }

    final notifAlpha = 0.4 + math.sin(phase * math.pi * 4) * 0.3;
    canvas.drawCircle(
      Offset(size.width / 2 + 28, size.height / 2 - 48),
      8,
      Paint()..color = V2Colors.ember.withValues(alpha: notifAlpha),
    );
  }

  @override
  bool shouldRepaint(covariant _AppScenePainter old) =>
      old.phase != phase || old.color != color;
}

// --- Background + card painters ---------------------------------------------

class _TechCanvasPainter extends CustomPainter {
  _TechCanvasPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF030712));

    _drawGrid(canvas, size);
    _drawDataStreams(canvas, size);
    _drawNeonBlobs(canvas, size);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
        stops: const [0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, vignette);

    _drawScanlines(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const spacing = 48.0;
    final drift = (phase * spacing * 2) % spacing;

    for (var y = size.height * 0.55 + drift; y < size.height; y += spacing * 0.65) {
      final t = (y - size.height * 0.55) / (size.height * 0.45);
      paint.color = Colors.white.withValues(alpha: 0.02 + t * 0.06);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (var x = -spacing; x < size.width + spacing; x += spacing) {
      final cx = x + math.sin(phase * math.pi * 2 + x * 0.01) * 8;
      canvas.drawLine(
        Offset(cx, size.height * 0.55),
        Offset(size.width / 2 + (cx - size.width / 2) * 0.15, size.height),
        paint..color = Colors.white.withValues(alpha: 0.035),
      );
    }
  }

  void _drawDataStreams(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (var i = 0; i < 28; i++) {
      final baseX = rng.nextDouble() * size.width;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final y = ((phase * size.height * speed + rng.nextDouble() * size.height) % size.height);
      final alpha = 0.08 + rng.nextDouble() * 0.18;
      final colors = [
        V2Colors.plasma,
        V2Colors.aurora,
        const Color(0xFFEC4899),
        const Color(0xFF0EA5E9),
      ];
      canvas.drawCircle(
        Offset(baseX + math.sin(phase * math.pi * 2 + i) * 12, y),
        1.2 + rng.nextDouble() * 1.5,
        Paint()..color = colors[i % colors.length].withValues(alpha: alpha),
      );
    }
  }

  void _drawNeonBlobs(Canvas canvas, Size size) {
    final blobs = [
      (const Color(0xFF6366F1), 0.0, Alignment(-0.7, -0.5)),
      (const Color(0xFFEC4899), 0.25, Alignment(0.8, -0.3)),
      (V2Colors.aurora, 0.5, Alignment(-0.5, 0.6)),
      (const Color(0xFF0EA5E9), 0.75, Alignment(0.6, 0.5)),
    ];

    for (final (color, offset, align) in blobs) {
      final t = (phase + offset) * math.pi * 2;
      final cx = size.width * (align.x * 0.5 + 0.5) + math.sin(t) * 40;
      final cy = size.height * (align.y * 0.5 + 0.5) + math.cos(t * 0.85) * 30;
      final radius = size.shortestSide * (0.28 + 0.04 * math.sin(t * 1.4));

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.06),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
      );
    }
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.015);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TechCanvasPainter old) => old.phase != phase;
}

class _HoloBorderPainter extends CustomPainter {
  _HoloBorderPainter({
    required this.phase,
    required this.color,
    required this.accent,
    required this.hover,
  });

  final double phase;
  final Color color;
  final Color accent;
  final bool hover;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    final start = phase * math.pi * 2;

    final sweep = SweepGradient(
      startAngle: start,
      endAngle: start + math.pi * 2,
      colors: [
        color.withValues(alpha: hover ? 0.9 : 0.45),
        accent.withValues(alpha: hover ? 0.7 : 0.3),
        Colors.white.withValues(alpha: hover ? 0.35 : 0.12),
        color.withValues(alpha: hover ? 0.9 : 0.45),
      ],
    );

    canvas.drawRRect(
      r,
      Paint()
        ..shader = sweep.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hover ? 2.0 : 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _HoloBorderPainter old) =>
      old.phase != phase || old.hover != hover || old.color != color;
}

class _CardGridPainter extends CustomPainter {
  _CardGridPainter({required this.color, required this.phase});
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const step = 24.0;
    final drift = phase * step;

    for (var x = -step + drift % step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = drift % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardGridPainter old) =>
      old.phase != phase || old.color != color;
}

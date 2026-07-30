// D.G.Yard Connect App — Apple strip promo (Digital Services ke baad).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../core/brand/public_brand_scope.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../widgets/v2_hero_download_block.dart';
import '../widgets/v2_section.dart';

class V2ConnectAppStrip extends StatefulWidget {
  const V2ConnectAppStrip({super.key});

  @override
  State<V2ConnectAppStrip> createState() => _V2ConnectAppStripState();
}

class _V2ConnectAppStripState extends State<V2ConnectAppStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phone;

  @override
  void initState() {
    super.initState();
    _phone = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final stacked = v.width < V2Breakpoints.lg;
    final brand = PublicBrandScope.contentOf(context);

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'D.G.Yard Connect App',
          style: V2FontStyles.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: V2Colors.aurora,
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.04, end: 0),
        SizedBox(height: v.r<double>(xs: 10, md: 12)),
        Text(
          'Your business.\nOne powerful app.',
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
          brand.appDownloadDescription,
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
          children: const [
            _AppFeatureOrb(
              delay: Duration(milliseconds: 180),
              color: V2Colors.plasma,
              icon: Icons.handyman_rounded,
              label: 'Jobs & bids',
              caption: 'Verified technicians',
            ),
            _AppFeatureOrb(
              delay: Duration(milliseconds: 260),
              color: V2Colors.aurora,
              icon: Icons.location_on_rounded,
              label: 'Live tracking',
              caption: 'Real-time updates',
            ),
            _AppFeatureOrb(
              delay: Duration(milliseconds: 340),
              color: V2Colors.premiumOrange,
              icon: Icons.storefront_rounded,
              label: 'IT shop',
              caption: 'Buy equipment',
            ),
          ],
        ),
        SizedBox(height: v.r<double>(xs: 24, md: 28)),
        V2HeroDownloadBlock(
          links: brand.heroCta1StoreButtons,
          alignStart: true,
          animateDelay: 420.ms,
        ),
        SizedBox(height: v.r<double>(xs: 16, md: 18)),
        _WebFallbackLink(
          onTap: () => context.go(RouteNames.phoneEntry),
        ).animate(delay: 500.ms).fadeIn(duration: 480.ms),
      ],
    );

    final preview = _ConnectPhonePreview(tick: _phone);

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
                Center(child: preview),
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

class _WebFallbackLink extends StatefulWidget {
  const _WebFallbackLink({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_WebFallbackLink> createState() => _WebFallbackLinkState();
}

class _WebFallbackLinkState extends State<_WebFallbackLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Use on web',
              style: V2FontStyles.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _hover ? V2Colors.plasma : V2Colors.inkMutedSaaS,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: _hover ? V2Colors.plasma : V2Colors.inkMutedSaaS,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppFeatureOrb extends StatefulWidget {
  const _AppFeatureOrb({
    required this.delay,
    required this.color,
    required this.icon,
    required this.label,
    required this.caption,
  });

  final Duration delay;
  final Color color;
  final IconData icon;
  final String label;
  final String caption;

  @override
  State<_AppFeatureOrb> createState() => _AppFeatureOrbState();
}

class _AppFeatureOrbState extends State<_AppFeatureOrb> {
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 20, color: widget.color),
            ),
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

class _ConnectPhonePreview extends StatelessWidget {
  const _ConnectPhonePreview({required this.tick});
  final Animation<double> tick;

  @override
  Widget build(BuildContext context) {
    final pad = V2Responsive(context).r<double>(xs: 12, md: 24);
    return AnimatedBuilder(
      animation: tick,
      builder: (context, _) {
        final phase = tick.value;
        final floatY = math.sin(phase * math.pi * 2) * 6;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFEEF2FF),
                  ],
                ),
                border: Border.all(color: V2Colors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: V2Colors.plasma.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
                    final phoneW = math.min(240.0, maxW);
                    final scale = phoneW / 240.0;
                    return Align(
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.topCenter,
                        child: _PhoneFrame(phase: phase),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    )
        .animate(delay: 160.ms)
        .fadeIn(duration: 620.ms)
        .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.phase});
  final double phase;

  static const _tabs = ['Connect', 'Calculate', 'Shop'];

  @override
  Widget build(BuildContext context) {
    final active = (phase * 3).floor() % 3;
    final tabProgress = (phase * 3) % 1.0;

    return Container(
      width: 240,
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 72,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'D.G.Yard',
                    style: V2FontStyles.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  _NotifDot(phase: phase),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _TabContent(active: active, progress: tabProgress),
              ),
            ),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _TabIcon(
                      label: _tabs[i],
                      active: i == active,
                      color: switch (i) {
                        0 => V2Colors.plasma,
                        1 => V2Colors.aurora,
                        _ => V2Colors.premiumOrange,
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifDot extends StatelessWidget {
  const _NotifDot({required this.phase});
  final double phase;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.5 + math.sin(phase * math.pi * 4) * 0.5;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications_none_rounded, color: Colors.white.withValues(alpha: 0.7), size: 22),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: V2Colors.ember.withValues(alpha: pulse),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: V2Colors.ember.withValues(alpha: pulse * 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.label, required this.active, required this.color});
  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          switch (label) {
            'Connect' => Icons.hub_rounded,
            'Calculate' => Icons.calculate_rounded,
            _ => Icons.shopping_bag_rounded,
          },
          size: 18,
          color: active ? color : Colors.white.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: V2FontStyles.inter(
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? color : Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.active, required this.progress});
  final int active;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (active) {
        0 => _ConnectTabCards(key: const ValueKey(0), progress: progress),
        1 => _CalculateTabCards(key: const ValueKey(1), progress: progress),
        _ => _ShopTabCards(key: const ValueKey(2), progress: progress),
      },
    );
  }
}

class _ConnectTabCards extends StatelessWidget {
  const _ConnectTabCards({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('connect'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MiniCard(
          title: 'New job posted',
          subtitle: 'CCTV install · Jaipur',
          color: V2Colors.plasma,
          progress: progress,
        ),
        const SizedBox(height: 8),
        _MiniCard(
          title: '3 bids received',
          subtitle: 'Verified technicians',
          color: V2Colors.aurora,
          progress: (progress + 0.3) % 1.0,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [V2Colors.plasma, V2Colors.plasmaSoft],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.engineering_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Find a Technician',
                style: V2FontStyles.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalculateTabCards extends StatelessWidget {
  const _CalculateTabCards({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('calc'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BOQ Estimate',
          style: V2FontStyles.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ((progress + i * 0.2) % 1.0).clamp(0.15, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: V2Colors.aurora.withValues(alpha: 0.85),
              ),
            ),
          ),
        const Spacer(),
        Text(
          '₹ xx,xxx',
          style: V2FontStyles.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: V2Colors.aurora,
          ),
        ),
        Text(
          'Live quote ready',
          style: V2FontStyles.inter(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _ShopTabCards extends StatelessWidget {
  const _ShopTabCards({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('shop'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
                  height: 72,
                  decoration: BoxDecoration(
                    color: V2Colors.premiumOrange.withValues(alpha: 0.15 + i * 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: V2Colors.premiumOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    i == 0 ? Icons.videocam_rounded : Icons.router_rounded,
                    color: V2Colors.premiumOrange,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _MiniCard(
          title: 'Dome Camera 4MP',
          subtitle: '₹ x,xxx · In stock',
          color: V2Colors.premiumOrange,
          progress: progress,
        ),
        const Spacer(),
        Text(
          'Buy IT Products',
          textAlign: TextAlign.center,
          style: V2FontStyles.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: V2FontStyles.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: V2FontStyles.inter(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.2, 1.0),
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

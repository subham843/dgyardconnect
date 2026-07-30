// Bento-style service cards — layered paper UI below hero.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../widgets/v2_paper_surface.dart';

class V2BentoServices extends StatelessWidget {
  const V2BentoServices({super.key});

  static const _services = [
    _BentoItem(
      title: 'CCTV & Video Surveillance',
      subtitle: 'IP cameras, NVR, installation & AMC',
      icon: Icons.videocam_rounded,
      color: Color(0xFF3B82F6),
      route: RouteNames.publicStore,
      wide: true,
    ),
    _BentoItem(
      title: 'Biometrics & Access',
      subtitle: 'Attendance, door access, visitor management',
      icon: Icons.fingerprint_rounded,
      color: Color(0xFFF59E0B),
      route: RouteNames.publicStore,
    ),
    _BentoItem(
      title: 'IT Infrastructure',
      subtitle: 'Laptops, servers, UPS & enterprise hardware',
      icon: Icons.dns_rounded,
      color: Color(0xFF6366F1),
      route: RouteNames.publicStore,
    ),
    _BentoItem(
      title: 'Networking',
      subtitle: 'Switches, routers, structured cabling',
      icon: Icons.router_rounded,
      color: Color(0xFF10B981),
      route: RouteNames.publicStore,
    ),
    _BentoItem(
      title: 'Fire Alarm Systems',
      subtitle: 'Detection, panels, compliance & maintenance',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFEF4444),
      route: RouteNames.publicServices,
    ),
    _BentoItem(
      title: 'Software & Automation',
      subtitle: 'Custom apps, integrations & smart building',
      icon: Icons.code_rounded,
      color: Color(0xFF8B5CF6),
      route: RouteNames.publicServices,
      wide: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(v.gutter, 8, v.gutter, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete digital infrastructure',
                style: V2FontStyles.inter(
                  fontSize: v.r<double>(xs: 24, md: 28, lg: 32),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: V2Colors.inkSaaS,
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 8),
              Text(
                'Everything you need — supply, install, integrate and support.',
                style: V2FontStyles.inter(
                  fontSize: 16,
                  color: V2Colors.inkMutedSaaS,
                  height: 1.5,
                ),
              ).animate(delay: 80.ms).fadeIn(duration: 500.ms),
              SizedBox(height: v.r<double>(xs: 24, md: 32, lg: 40)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= V2Breakpoints.lg;
                  if (!wide) {
                    return Column(
                      children: [
                        for (var i = 0; i < _services.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _BentoCard(item: _services[i], index: i),
                          ),
                      ],
                    );
                  }
                  return _DesktopBentoGrid(items: _services);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopBentoGrid extends StatelessWidget {
  const _DesktopBentoGrid({required this.items});
  final List<_BentoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _BentoCard(item: items[0], index: 0, tall: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _BentoCard(item: items[1], index: 1),
                  const SizedBox(height: 16),
                  _BentoCard(item: items[2], index: 2),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _BentoCard(item: items[3], index: 3),
                  const SizedBox(height: 16),
                  _BentoCard(item: items[4], index: 4),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BentoCard(item: items[5], index: 5, wide: true),
      ],
    );
  }
}

class _BentoItem {
  const _BentoItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.wide = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool wide;
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.item,
    required this.index,
    this.tall = false,
    this.wide = false,
  });

  final _BentoItem item;
  final int index;
  final bool tall;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return V2PaperSurface(
      borderRadius: 22,
      elevation: V2PaperElevation.low,
      hoverLift: true,
      onTap: () => context.go(item.route),
      padding: EdgeInsets.all(wide ? 28 : 24),
      child: SizedBox(
        width: double.infinity,
        height: tall ? 220 : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: tall ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            SizedBox(height: tall ? 24 : 16),
            Text(
              item.title,
              style: V2FontStyles.inter(
                fontSize: wide ? 20 : 17,
                fontWeight: FontWeight.w600,
                color: V2Colors.inkSaaS,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.subtitle,
              style: V2FontStyles.inter(
                fontSize: 14,
                color: V2Colors.inkMutedSaaS,
                height: 1.45,
              ),
            ),
            if (wide) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Learn more',
                    style: V2FontStyles.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: V2Colors.premiumOrange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: V2Colors.premiumOrange,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    )
        .animate(delay: (100 + index * 70).ms)
        .fadeIn(duration: 550.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

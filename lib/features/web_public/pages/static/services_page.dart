// Services Page — Apple-style public services experience.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/route_names.dart';
import '../../core/brand/public_brand_scope.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_glass.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final _scroll = ScrollController();

  static const _services = [
    _ServiceItem(
      title: 'CCTV & Security Systems',
      eyebrow: 'Surveillance, access, fire safety',
      description:
          'CCTV cameras, NVR/DVR, biometric attendance, access control, video door phones and fire alarm systems.',
      icon: Icons.security_rounded,
      color: Color(0xFF2563EB),
      points: ['CCTV installation', 'Biometric access', 'Fire alarm setup'],
    ),
    _ServiceItem(
      title: 'Networking & IT Infrastructure',
      eyebrow: 'Wired, wireless, office IT',
      description:
          'LAN cabling, Wi-Fi coverage, routers, switches, racks, UPS, computers and complete network execution.',
      icon: Icons.dns_rounded,
      color: Color(0xFF10B981),
      points: ['LAN/Wi-Fi design', 'Rack & cabling', 'Routers and switches'],
    ),
    _ServiceItem(
      title: 'Software, Web & App Development',
      eyebrow: 'Websites, apps, dashboards',
      description:
          'Business websites, ecommerce stores, mobile apps, admin dashboards, CRM tools and workflow automation.',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF8B5CF6),
      points: ['Website development', 'Mobile apps', 'Admin dashboards'],
      wide: true,
    ),
    _ServiceItem(
      title: 'Digital Marketing',
      eyebrow: 'Ads, SEO, social media',
      description:
          'Google Ads, Meta Ads, social media creatives, local SEO, landing pages and lead generation campaigns.',
      icon: Icons.campaign_rounded,
      color: Color(0xFFEF4444),
      points: ['Google/Meta ads', 'SEO and local listing', 'Lead generation'],
    ),
    _ServiceItem(
      title: 'Home Automation',
      eyebrow: 'Smart home, IoT, control',
      description:
          'Smart lighting, switches, locks, curtains, sensors, CCTV integration and mobile app control.',
      icon: Icons.home_max_rounded,
      color: Color(0xFF0EA5E9),
      points: [
        'Smart lighting',
        'Smart locks/sensors',
        'App and voice control',
      ],
    ),
    _ServiceItem(
      title: 'AMC & Support',
      eyebrow: 'Maintenance, SLA, audits',
      description:
          'Preventive maintenance, fast technician response and lifecycle support for every site.',
      icon: Icons.support_agent_rounded,
      color: Color(0xFFF59E0B),
      points: ['AMC plans', 'Fast technician help', 'Warranty support'],
    ),
    _ServiceItem(
      title: 'BOQ & Project Planning',
      eyebrow: 'Survey, costing, execution',
      description:
          'From site visit to BOQ, quotation and deployment tracking with clear technical guidance.',
      icon: Icons.calculate_rounded,
      color: Color(0xFFEF4444),
      points: ['Site survey', 'BOQ and quotation', 'Execution planning'],
    ),
  ];

  static const _steps = [
    ('01', 'Discover', 'Site survey, requirements and product fitment.'),
    ('02', 'Design', 'BOQ, architecture, timeline and transparent costing.'),
    ('03', 'Deploy', 'Procurement, installation, configuration and handover.'),
    ('04', 'Support', 'AMC, warranty, upgrades and technician assistance.'),
  ];

  static const _highlightServices = [
    _HighlightService(
      eyebrow: 'Digital Marketing',
      title: 'Grow your brand with performance-focused digital marketing.',
      description:
          'We help local and growing businesses become visible online with clear campaigns, better content and measurable lead generation. The focus is simple: more relevant visitors, more inquiries and stronger brand trust.',
      icon: Icons.campaign_rounded,
      color: Color(0xFFEF4444),
      bullets: [
        'Google Ads, Meta Ads and lead generation campaign setup',
        'Social media creatives, content planning and page management',
        'SEO basics, Google Business Profile and local visibility',
        'Landing pages, tracking and monthly performance reporting',
      ],
      chips: ['Ads', 'SEO', 'Social Media', 'Leads'],
    ),
    _HighlightService(
      eyebrow: 'Software, Web & App Development',
      title:
          'Build modern software, websites and mobile apps for your business.',
      description:
          'We design and develop practical digital products such as business websites, ecommerce stores, admin panels, booking systems, field apps and workflow automation tools. Every build is planned around your daily operations.',
      icon: Icons.code_rounded,
      color: Color(0xFF8B5CF6),
      bullets: [
        'Business websites, ecommerce stores and customer portals',
        'Android, iOS and Flutter apps for customers or internal teams',
        'Admin dashboards, CRM tools and custom workflow systems',
        'API integrations, payment flows, reports and automation',
      ],
      chips: ['Websites', 'Mobile Apps', 'Dashboards', 'Automation'],
      dark: true,
    ),
    _HighlightService(
      eyebrow: 'Home Automation',
      title:
          'Make homes, offices and buildings smarter, safer and easier to manage.',
      description:
          'We plan and install automation systems that connect lighting, security, cameras, locks, sensors and smart controls into one simple experience. You get comfort, control and better energy usage.',
      icon: Icons.home_max_rounded,
      color: Color(0xFF10B981),
      bullets: [
        'Smart lighting, curtains, switches and scene control',
        'Video door phones, smart locks, sensors and security alerts',
        'CCTV, Wi-Fi, access control and smart device integration',
        'Mobile app control, voice control and maintenance support',
      ],
      chips: ['Smart Home', 'Security', 'Lighting', 'IoT'],
    ),
    _HighlightService(
      eyebrow: 'Networking Services',
      title:
          'Plan, build and execute wired and wireless networks of every size.',
      description:
          'We handle complete networking work for homes, offices, shops, schools, warehouses and large sites. From small Wi-Fi setup to enterprise-grade wired and wireless network design, our team plans the layout, selects the right devices and completes clean execution.',
      icon: Icons.hub_rounded,
      color: Color(0xFF2563EB),
      bullets: [
        'LAN, structured cabling, rack setup, patch panels and switch installation',
        'Wi-Fi planning, router setup, access points and wireless coverage design',
        'Small office, large campus, warehouse and multi-floor network execution',
        'Network security, CCTV network, internet failover and maintenance support',
      ],
      chips: ['LAN', 'Wi-Fi', 'Cabling', 'Network Design'],
      dark: true,
    ),
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _HeroSection(
                  onPrimary: () => context.go(RouteNames.phoneEntry),
                ),
                _ServicesBento(services: _services),
                const _HighlightedServicesSection(services: _highlightServices),
                const _ProcessSection(),
                _FinalCta(onTap: () => context.go(RouteNames.phoneEntry)),
                const V2Footer(),
                SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onPrimary});

  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.lg;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        v.gutter,
        v.r<double>(xs: 128, md: 148, lg: 162),
        v.gutter,
        v.r<double>(xs: 56, md: 72, lg: 88),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F7)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _HeroCopy(onPrimary: onPrimary)),
                    const SizedBox(width: 42),
                    const Expanded(child: _HeroVisual()),
                  ],
                )
              : Column(
                  children: [
                    _HeroCopy(onPrimary: onPrimary),
                    const SizedBox(height: 34),
                    const _HeroVisual(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onPrimary});

  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Column(
      crossAxisAlignment: v.isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        const _GlassPill(label: 'DG Yard Connect Services'),
        const SizedBox(height: 22),
        Text(
          'Services for security, networking, software, marketing and automation.',
          textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 36, sm: 42, md: 54, lg: 64),
            height: 0.96,
            letterSpacing: -3,
            fontWeight: FontWeight.w800,
            color: V2Colors.inkSaaS,
          ),
        ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'DG Yard Connect provides end-to-end services: CCTV and security systems, wired and wireless networking, websites and apps, digital marketing, home automation, BOQ planning and AMC support.',
            textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
            style: V2FontStyles.inter(
              fontSize: v.r<double>(xs: 16, md: 18),
              height: 1.6,
              color: V2Colors.inkMutedSaaS,
              fontWeight: FontWeight.w500,
            ),
          ).animate(delay: 90.ms).fadeIn(duration: 520.ms),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          alignment: v.isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: const [
            _HeroServiceChip('CCTV & Security', Icons.videocam_rounded),
            _HeroServiceChip('Networking', Icons.hub_rounded),
            _HeroServiceChip('Web & Apps', Icons.code_rounded),
            _HeroServiceChip('Digital Marketing', Icons.campaign_rounded),
            _HeroServiceChip('Home Automation', Icons.home_max_rounded),
          ],
        ).animate(delay: 130.ms).fadeIn(duration: 520.ms),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: v.isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _HeroButton(
              label: 'Book a consultation',
              icon: Icons.arrow_forward_rounded,
              primary: true,
              onTap: onPrimary,
            ),
            _HeroButton(
              label: 'Open calculator',
              icon: Icons.calculate_rounded,
              onTap: () => context.go(RouteNames.publicCalculatorList),
            ),
          ],
        ).animate(delay: 160.ms).fadeIn(duration: 520.ms),
      ],
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: v2BlurLayer(
            sigma: 18,
            child: Container(
              height: v.r<double>(xs: 420, md: 470, lg: 520),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                boxShadow: V2Colors.paperHigh,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -46,
                    top: -36,
                    child: _GlowOrb(
                      color: V2Colors.plasma.withValues(alpha: 0.20),
                    ),
                  ),
                  Positioned(
                    left: -42,
                    bottom: -46,
                    child: _GlowOrb(
                      color: V2Colors.aurora.withValues(alpha: 0.18),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _StatusDot(),
                          const SizedBox(width: 10),
                          Text(
                            'Live service command',
                            style: V2FontStyles.inter(
                              fontWeight: FontWeight.w700,
                              color: V2Colors.inkSaaS,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.more_horiz_rounded),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.35,
                          children: const [
                            _SignalTile(
                              'CCTV & Security',
                              'Cameras, access, fire alarm',
                              Icons.videocam_rounded,
                            ),
                            _SignalTile(
                              'Networking',
                              'LAN, Wi-Fi, racks, switches',
                              Icons.hub_rounded,
                            ),
                            _SignalTile(
                              'Web, App & Software',
                              'Sites, apps, dashboards',
                              Icons.code_rounded,
                            ),
                            _SignalTile(
                              'Marketing & Automation',
                              'Ads, SEO, smart controls',
                              Icons.auto_awesome_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _InsightStrip(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: 180.ms)
        .fadeIn(duration: 650.ms)
        .slideX(begin: 0.08, end: 0);
  }
}

class _ServicesBento extends StatelessWidget {
  const _ServicesBento({required this.services});

  final List<_ServiceItem> services;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(v.gutter, 34, v.gutter, v.sectionPadY),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(
                eyebrow: 'What we do',
                title: 'Choose the exact service you need.',
                subtitle:
                    'Each card below explains the service in simple words, so you can quickly understand what DG Yard Connect can plan, supply, install and support for you.',
              ),
              const SizedBox(height: 30),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 1120
                      ? 3
                      : constraints.maxWidth >= 720
                      ? 2
                      : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: cols == 1 ? 0.84 : 0.88,
                    ),
                    itemCount: services.length,
                    itemBuilder: (context, i) =>
                        _ServiceCard(item: services[i], index: i),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedServicesSection extends StatelessWidget {
  const _HighlightedServicesSection({required this.services});

  final List<_HighlightService> services;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        v.gutter,
        0,
        v.gutter,
        v.r<double>(xs: 64, md: 84, lg: 104),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                eyebrow: 'Highlighted services',
                title: 'Digital growth, custom software and smart automation.',
                subtitle:
                    'These are our specialist service areas. Each one is designed to be easy to understand, easy to buy and easy to execute with DG Yard Connect.',
              ),
              const SizedBox(height: 30),
              for (var i = 0; i < services.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == services.length - 1 ? 0 : 18,
                  ),
                  child: _HighlightServiceCard(service: services[i], index: i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightServiceCard extends StatelessWidget {
  const _HighlightServiceCard({required this.service, required this.index});

  final _HighlightService service;
  final int index;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.lg;
    final bg = service.dark ? V2Colors.inkSaaS : Colors.white;
    final fg = service.dark ? Colors.white : V2Colors.inkSaaS;
    final muted = service.dark
        ? Colors.white.withValues(alpha: 0.68)
        : V2Colors.inkMutedSaaS;

    final visual = _HighlightVisual(service: service);
    final copy = _HighlightCopy(service: service, fg: fg, muted: muted);

    return ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: v2BlurLayer(
            sigma: 16,
            child: Container(
              padding: EdgeInsets.all(v.r<double>(xs: 22, md: 30, lg: 38)),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: service.dark ? 0.96 : 0.82),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: service.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.88),
                ),
                boxShadow: service.dark
                    ? V2Colors.paperHigh
                    : V2Colors.paperMid,
              ),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 6, child: index.isOdd ? visual : copy),
                        const SizedBox(width: 34),
                        Expanded(flex: 5, child: index.isOdd ? copy : visual),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [visual, const SizedBox(height: 24), copy],
                    ),
            ),
          ),
        )
        .animate(delay: (120 + index * 90).ms)
        .fadeIn(duration: 560.ms)
        .slideY(begin: 0.06, end: 0);
  }
}

class _HighlightCopy extends StatelessWidget {
  const _HighlightCopy({
    required this.service,
    required this.fg,
    required this.muted,
  });

  final _HighlightService service;
  final Color fg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          service.eyebrow.toUpperCase(),
          style: V2FontStyles.inter(
            fontSize: 12,
            letterSpacing: 1.3,
            color: service.color,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          service.title,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 27, md: 34, lg: 42),
            height: 1.05,
            letterSpacing: -1.4,
            color: fg,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          service.description,
          style: V2FontStyles.inter(
            fontSize: 16,
            height: 1.65,
            color: muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        Column(
          children: [
            for (final bullet in service.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: service.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: service.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bullet,
                        style: V2FontStyles.inter(
                          color: muted,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ServiceActionButton(
              label: 'Book consultation',
              icon: Icons.calendar_month_rounded,
              color: service.color,
              darkSurface: service.dark,
              primary: true,
              onTap: () => context.go(RouteNames.phoneEntry),
            ),
            _ServiceActionButton(
              label: 'WhatsApp quick chat',
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              darkSurface: service.dark,
              onTap: () => _openWhatsAppChat(context, service.eyebrow),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _openWhatsAppChat(BuildContext context, String serviceName) async {
  final phone = _digitsOnly(PublicBrandScope.contentOf(context).contactPhone);
  if (phone.isEmpty) {
    context.go(RouteNames.phoneEntry);
    return;
  }

  final normalized = phone.length == 10 ? '91$phone' : phone;
  final message = Uri.encodeComponent(
    'Hi DG Yard Connect, I want to discuss $serviceName service.',
  );
  final uri = Uri.parse('https://wa.me/$normalized?text=$message');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      context.go(RouteNames.phoneEntry);
    }
  }
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

class _HighlightVisual extends StatelessWidget {
  const _HighlightVisual({required this.service});

  final _HighlightService service;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return SizedBox(
      height: v.r<double>(xs: 280, md: 310, lg: 330),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              service.color.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: service.dark ? 0.06 : 0.72),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: service.dark ? 0.12 : 0.74),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              bottom: -28,
              child: Icon(
                service.icon,
                size: 180,
                color: service.color.withValues(alpha: 0.12),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: service.color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: service.color.withValues(alpha: 0.26),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(service.icon, color: Colors.white, size: 30),
                ),
                const Spacer(),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final chip in service.chips)
                      _ServiceChip(
                        label: chip,
                        color: service.color,
                        dark: service.dark,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.label,
    required this.color,
    required this.dark,
  });

  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: V2FontStyles.inter(
          color: dark ? Colors.white.withValues(alpha: 0.86) : V2Colors.inkSaaS,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProcessSection extends StatelessWidget {
  const _ProcessSection();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: v.sectionPadY,
        horizontal: v.gutter,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                eyebrow: 'Execution',
                title: 'A smoother way to purchase, deploy and maintain.',
                subtitle:
                    'Clear steps, fast feedback and service ownership from planning to after-sales support.',
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth >= 900;
                  if (!horizontal) {
                    return Column(
                      children: [
                        for (
                          var i = 0;
                          i < _ServicesPageState._steps.length;
                          i++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _StepCard(
                              step: _ServicesPageState._steps[i],
                              index: i,
                            ),
                          ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (var i = 0; i < _ServicesPageState._steps.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i != 3 ? 14 : 0),
                            child: _StepCard(
                              step: _ServicesPageState._steps[i],
                              index: i,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: v.gutter,
        vertical: v.sectionPadY,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: Container(
            padding: EdgeInsets.all(v.r<double>(xs: 28, md: 44, lg: 56)),
            decoration: BoxDecoration(
              color: V2Colors.inkSaaS,
              borderRadius: BorderRadius.circular(36),
              boxShadow: V2Colors.paperHigh,
            ),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to upgrade your site?',
                        style: V2FontStyles.inter(
                          fontSize: v.r<double>(xs: 28, md: 38, lg: 46),
                          height: 1.05,
                          letterSpacing: -1.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Talk to DG Yard Connect for a clean BOQ, best-fit products and professional execution.',
                        style: V2FontStyles.inter(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.55,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeroButton(
                  label: 'Start now',
                  icon: Icons.arrow_forward_rounded,
                  primary: true,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: V2FontStyles.inter(
            fontSize: 12,
            letterSpacing: 1.4,
            color: V2Colors.premiumOrangeDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            title,
            style: V2FontStyles.inter(
              fontSize: v.r<double>(xs: 28, md: 38, lg: 48),
              height: 1.04,
              letterSpacing: -1.6,
              color: V2Colors.inkSaaS,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            subtitle,
            style: V2FontStyles.inter(
              fontSize: 16,
              height: 1.6,
              color: V2Colors.inkMutedSaaS,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.06, end: 0);
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({required this.item, required this.index});

  final _ServiceItem item;
  final int index;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: V2.dMed,
        curve: V2.eOut,
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _hover
                ? item.color.withValues(alpha: 0.26)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: _hover ? V2Colors.paperHigh : V2Colors.paperLow,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -24,
              child: Icon(
                item.icon,
                size: 112,
                color: item.color.withValues(alpha: 0.08),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: item.color, size: 27),
                ),
                const SizedBox(height: 18),
                Text(
                  item.eyebrow,
                  style: V2FontStyles.inter(
                    fontSize: 12,
                    color: V2Colors.inkMutedSaaS,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: V2FontStyles.inter(
                    fontSize: 22,
                    height: 1.12,
                    letterSpacing: -0.5,
                    color: V2Colors.inkSaaS,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: V2FontStyles.inter(
                    height: 1.45,
                    color: V2Colors.inkMutedSaaS,
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  children: [
                    for (final point in item.points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: item.color,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                point,
                                style: V2FontStyles.inter(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: V2Colors.inkSaaS,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ).animate(delay: (80 + widget.index * 70).ms).fadeIn(duration: 520.ms),
    );
  }
}

class _ServiceActionButton extends StatefulWidget {
  const _ServiceActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.darkSurface,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool darkSurface;
  final bool primary;

  @override
  State<_ServiceActionButton> createState() => _ServiceActionButtonState();
}

class _ServiceActionButtonState extends State<_ServiceActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.primary
        ? widget.color
        : widget.darkSurface
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white;
    final border = widget.primary
        ? widget.color
        : widget.darkSurface
        ? Colors.white.withValues(alpha: 0.14)
        : V2Colors.borderSubtle;
    final fg = widget.primary
        ? Colors.white
        : widget.darkSurface
        ? Colors.white.withValues(alpha: 0.9)
        : V2Colors.inkSaaS;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.d,
          curve: V2.eOut,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(color: border),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 17, color: fg),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.index});

  final (String, String, String) step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: V2Colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.$1,
            style: V2FontStyles.inter(
              color: V2Colors.premiumOrangeDeep,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            step.$2,
            style: V2FontStyles.inter(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: V2Colors.inkSaaS,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.$3,
            style: V2FontStyles.inter(
              color: V2Colors.inkMutedSaaS,
              height: 1.45,
            ),
          ),
        ],
      ),
    ).animate(delay: (100 + index * 80).ms).fadeIn(duration: 480.ms);
  }
}

class _HeroButton extends StatefulWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.primary ? V2Colors.inkSaaS : Colors.white;
    final fg = widget.primary ? Colors.white : V2Colors.inkSaaS;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.d,
          curve: V2.eOut,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(
              color: widget.primary ? V2Colors.inkSaaS : V2Colors.border,
            ),
            boxShadow: _hover ? V2Colors.paperMid : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Icon(widget.icon, color: fg, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(V2.rFull),
      child: v2BlurLayer(
        sigma: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Text(
            label,
            style: V2FontStyles.inter(
              fontSize: 12,
              color: V2Colors.inkMutedSaaS,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroServiceChip extends StatelessWidget {
  const _HeroServiceChip(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: V2Colors.borderSubtle),
        boxShadow: V2Colors.paperLow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: V2Colors.premiumOrangeDeep),
          const SizedBox(width: 7),
          Text(
            label,
            style: V2FontStyles.inter(
              color: V2Colors.inkSaaS,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: V2Colors.inkSaaS),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: V2FontStyles.inter(
              fontWeight: FontWeight.w800,
              color: V2Colors.inkSaaS,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: V2FontStyles.inter(
              fontSize: 12,
              color: V2Colors.inkMutedSaaS,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: V2Colors.inkSaaS,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: V2Colors.aurora.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_graph_rounded, color: V2Colors.aurora),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fast project clarity',
                  style: V2FontStyles.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'BOQ, purchase and service in one flow',
                  style: V2FontStyles.inter(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: V2Colors.aurora,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: V2Colors.aurora.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 3,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.icon,
    required this.color,
    required this.points,
    this.wide = false,
  });

  final String title;
  final String eyebrow;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> points;
  final bool wide;
}

class _HighlightService {
  const _HighlightService({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bullets,
    required this.chips,
    this.dark = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> bullets;
  final List<String> chips;
  final bool dark;
}
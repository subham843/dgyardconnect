// About Page — Apple-style company story for public web.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../core/brand/public_brand_scope.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_glass.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _scroll = ScrollController();

  static const _stats = [
    ('Security', 'CCTV, access control and fire alarm solutions'),
    ('IT & Network', 'Wired, wireless and office infrastructure'),
    ('Software', 'Web, app, dashboards and automation systems'),
  ];

  static const _values = [
    _ValueData(
      'Clarity first',
      'We explain product, BOQ, installation and support decisions in simple language.',
      Icons.lightbulb_rounded,
      V2Colors.ember,
    ),
    _ValueData(
      'Execution ownership',
      'From planning to after-sales, we keep the project moving with practical engineering.',
      Icons.verified_rounded,
      V2Colors.aurora,
    ),
    _ValueData(
      'Digital trust',
      'We connect technology, people and workflows so customers can make confident decisions.',
      Icons.handshake_rounded,
      V2Colors.plasma,
    ),
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final content = PublicBrandScope.contentOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _AboutHero(
                  company: content.companyName,
                  tagline: content.tagline,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    v.gutter,
                    0,
                    v.gutter,
                    v.sectionPadY,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: V2.maxContentWidth,
                      ),
                      child: Column(
                        children: const [
                          _PromiseSection(),
                          SizedBox(height: 28),
                          _StatsStrip(),
                          SizedBox(height: 72),
                          _ValuesSection(),
                          SizedBox(height: 72),
                          _JourneySection(),
                        ],
                      ),
                    ),
                  ),
                ),
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

class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.company, required this.tagline});

  final String company;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.lg;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        v.gutter,
        v.r<double>(xs: 128, md: 148, lg: 166),
        v.gutter,
        v.r<double>(xs: 58, md: 76, lg: 96),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F5F7)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _HeroCopy(company: company, tagline: tagline),
                    ),
                    const SizedBox(width: 46),
                    const Expanded(child: _HeroStoryCard()),
                  ],
                )
              : Column(
                  children: [
                    _HeroCopy(company: company, tagline: tagline),
                    const SizedBox(height: 34),
                    const _HeroStoryCard(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.company, required this.tagline});

  final String company;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Column(
      crossAxisAlignment: v.isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        const _GlassPill(label: 'About DG Yard Connect'),
        const SizedBox(height: 22),
        Text(
          'Building a smarter way to buy, plan and execute technology projects.',
          textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 38, sm: 44, md: 58, lg: 70),
            height: 0.96,
            letterSpacing: -3,
            color: V2Colors.inkSaaS,
            fontWeight: FontWeight.w800,
          ),
        ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Text(
            '$company brings shop products, BOQ calculators, services and technician connect into one practical platform. $tagline',
            textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
            style: V2FontStyles.inter(
              fontSize: v.r<double>(xs: 16, md: 18),
              height: 1.62,
              color: V2Colors.inkMutedSaaS,
              fontWeight: FontWeight.w500,
            ),
          ),
        ).animate(delay: 90.ms).fadeIn(duration: 520.ms),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: v.isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _HeroButton(
              label: 'Explore services',
              icon: Icons.arrow_forward_rounded,
              primary: true,
              onTap: () => context.go(RouteNames.publicServices),
            ),
            _HeroButton(
              label: 'Contact us',
              icon: Icons.support_agent_rounded,
              onTap: () => context.go(RouteNames.supportHome),
            ),
          ],
        ).animate(delay: 150.ms).fadeIn(duration: 520.ms),
      ],
    );
  }
}

class _HeroStoryCard extends StatelessWidget {
  const _HeroStoryCard();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: v2BlurLayer(
        sigma: 18,
        child: Container(
          height: v.r<double>(xs: 430, md: 480, lg: 530),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: V2Colors.paperHigh,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -44,
                top: -42,
                child: _GlowOrb(color: V2Colors.plasma.withValues(alpha: 0.18)),
              ),
              Positioned(
                left: -48,
                bottom: -54,
                child: _GlowOrb(color: V2Colors.aurora.withValues(alpha: 0.16)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: V2Colors.emberSubtle,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: V2Colors.emberDeep,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Connected platform',
                        style: V2FontStyles.inter(
                          color: V2Colors.inkSaaS,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _StoryTile(
                    'Shop',
                    'Products and brands for real projects',
                    Icons.storefront_rounded,
                  ),
                  const SizedBox(height: 12),
                  const _StoryTile(
                    'Calculator',
                    'BOQ planning before purchase',
                    Icons.calculate_rounded,
                  ),
                  const SizedBox(height: 12),
                  const _StoryTile(
                    'Connect',
                    'Technician and service support',
                    Icons.engineering_rounded,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: V2Colors.inkSaaS,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Our purpose is simple: make complex technology projects easier to understand, purchase and execute.',
                      style: V2FontStyles.inter(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: 160.ms).fadeIn(duration: 620.ms).slideX(begin: 0.08, end: 0);
  }
}

class _PromiseSection extends StatelessWidget {
  const _PromiseSection();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(v.r<double>(xs: 28, md: 42, lg: 56)),
      decoration: BoxDecoration(
        color: V2Colors.inkSaaS,
        borderRadius: BorderRadius.circular(36),
        boxShadow: V2Colors.paperHigh,
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 26,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              'We are not just a shop. We are a project partner for security, IT, networking, software and smart automation.',
              style: V2FontStyles.inter(
                fontSize: v.r<double>(xs: 28, md: 38, lg: 48),
                height: 1.06,
                letterSpacing: -1.8,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _DarkMetric(label: 'One platform', value: 'Shop + BOQ + Service'),
        ],
      ),
    ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.06, end: 0);
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 820;
        final cards = [
          for (var i = 0; i < _AboutPageState._stats.length; i++)
            _StatCard(
              title: _AboutPageState._stats[i].$1,
              text: _AboutPageState._stats[i].$2,
              index: i,
            ),
        ];
        if (!horizontal) {
          return Column(
            children: [
              for (final card in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: card,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == cards.length - 1 ? 0 : 16,
                  ),
                  child: cards[i],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ValuesSection extends StatelessWidget {
  const _ValuesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          eyebrow: 'Values',
          title: 'The principles behind every project.',
          subtitle:
              'A good technology partner should make decisions clear, execution reliable and support easy to reach.',
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 640
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: cols == 1 ? 1.35 : 1.05,
              ),
              itemCount: _AboutPageState._values.length,
              itemBuilder: (context, i) =>
                  _ValueCard(data: _AboutPageState._values[i], index: i),
            );
          },
        ),
      ],
    );
  }
}

class _JourneySection extends StatelessWidget {
  const _JourneySection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: V2Colors.paperMid,
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 20,
        alignment: WrapAlignment.spaceBetween,
        children: const [
          _JourneyItem(
            '01',
            'Understand',
            'Site need, product fitment and project goals.',
          ),
          _JourneyItem(
            '02',
            'Plan',
            'BOQ, pricing direction and execution approach.',
          ),
          _JourneyItem(
            '03',
            'Deliver',
            'Products, service support and technician connect.',
          ),
        ],
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile(this.title, this.text, this.icon);

  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: V2Colors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: V2Colors.emberDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: V2FontStyles.inter(
                    color: V2Colors.inkSaaS,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  text,
                  style: V2FontStyles.inter(
                    color: V2Colors.inkMutedSaaS,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.text,
    required this.index,
  });

  final String title;
  final String text;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: V2Colors.paperLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '0${index + 1}',
            style: V2FontStyles.inter(
              color: V2Colors.emberDeep,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: V2FontStyles.inter(
              color: V2Colors.inkSaaS,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: V2FontStyles.inter(
              color: V2Colors.inkMutedSaaS,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate(delay: (90 + index * 70).ms).fadeIn(duration: 480.ms);
  }
}

class _ValueCard extends StatefulWidget {
  const _ValueCard({required this.data, required this.index});

  final _ValueData data;
  final int index;

  @override
  State<_ValueCard> createState() => _ValueCardState();
}

class _ValueCardState extends State<_ValueCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: V2.dMed,
        curve: V2.eOut,
        transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _hover
                ? data.color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: _hover ? V2Colors.paperHigh : V2Colors.paperLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: data.color, size: 34),
            const Spacer(),
            Text(
              data.title,
              style: V2FontStyles.inter(
                color: V2Colors.inkSaaS,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: V2FontStyles.inter(
                color: V2Colors.inkMutedSaaS,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ).animate(delay: (90 + widget.index * 70).ms).fadeIn(duration: 520.ms),
    );
  }
}

class _JourneyItem extends StatelessWidget {
  const _JourneyItem(this.step, this.title, this.text);

  final String step;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: V2FontStyles.inter(
              color: V2Colors.emberDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: V2FontStyles.inter(
              color: V2Colors.inkSaaS,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: V2FontStyles.inter(
              color: V2Colors.inkMutedSaaS,
              height: 1.45,
            ),
          ),
        ],
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
            color: V2Colors.emberDeep,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 30, md: 40, lg: 48),
            height: 1.04,
            letterSpacing: -1.6,
            color: V2Colors.inkSaaS,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Text(
            subtitle,
            style: V2FontStyles.inter(
              color: V2Colors.inkMutedSaaS,
              height: 1.58,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.06, end: 0);
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

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: V2FontStyles.inter(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: V2FontStyles.inter(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
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

class _ValueData {
  const _ValueData(this.title, this.text, this.icon, this.color);

  final String title;
  final String text;
  final IconData icon;
  final Color color;
}
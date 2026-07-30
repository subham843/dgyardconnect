// V2 Footer — Apple editorial style.
//
// Light surface after dark Final CTA. Editorial labels, app strip, link grid.
// No BackdropFilter (CanvasKit-safe).

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../core/brand/public_brand_content.dart';
import '../../core/brand/public_brand_navigation.dart';
import '../../core/brand/public_brand_scope.dart';
import '../../shared/widgets/public_brand_logo.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import 'v2_hero_download_block.dart';
import 'v2_section.dart';

class V2Footer extends StatefulWidget {
  const V2Footer({super.key});

  static const background = Color(0xFFF5F5F7);

  @override
  State<V2Footer> createState() => _V2FooterState();
}

class _V2FooterState extends State<V2Footer> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final content = PublicBrandScope.contentOf(context);
    final mobile = v.isMobile;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        V2Section(
          background: V2Footer.background,
          borderTop: false,
          padTopOverride: v.r<double>(xs: 36, md: 56, lg: 64),
          padBottomOverride: v.r<double>(xs: 32, md: 32, lg: 36),
          child: mobile
              ? _MobileFooterLayout(content: content, v: v, pulse: _pulse)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FooterHeader(v: v, pulse: _pulse),
                    SizedBox(height: v.r<double>(xs: 28, md: 32, lg: 36)),
                    _AppPromoCard(content: content, v: v, pulse: _pulse),
                    SizedBox(height: v.r<double>(xs: 36, md: 40, lg: 48)),
                    _MainGrid(content: content, v: v),
                    SizedBox(height: v.r<double>(xs: 32, md: 36, lg: 40)),
                    _AccentDivider(pulse: _pulse),
                    SizedBox(height: v.r<double>(xs: 20, md: 24)),
                    _BottomBar(content: content, v: v),
                  ],
                ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: v.r<double>(xs: 40, md: 64, lg: 72),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    V2Colors.bgDark,
                    V2Colors.bgDark.withValues(alpha: 0.55),
                    V2Footer.background.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 520.ms, curve: Curves.easeOut);
  }
}

/// Mobile-only footer — compact Apple site-map style (no duplicate hero copy).
class _MobileFooterLayout extends StatelessWidget {
  const _MobileFooterLayout({
    required this.content,
    required this.v,
    required this.pulse,
  });

  final PublicBrandContent content;
  final V2Responsive v;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PublicBrandLogo(size: 28, showName: true),
        const SizedBox(height: 12),
        Text(
          content.footerDescription,
          style: V2FontStyles.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
        const SizedBox(height: 24),
        _MobileAppCard(content: content, pulse: pulse),
        const SizedBox(height: 20),
        _MobileNavCard(),
        if (content.contactEmail.isNotEmpty || content.contactPhone.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MobileContactBlock(content: content),
        ],
        const SizedBox(height: 20),
        const Divider(height: 1, color: V2Colors.hairline),
        const SizedBox(height: 16),
        _BottomBar(content: content, v: v, centered: true),
      ],
    );
  }
}

class _MobileAppCard extends StatelessWidget {
  const _MobileAppCard({required this.content, required this.pulse});
  final PublicBrandContent content;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: V2Colors.hairline),
        boxShadow: V2Colors.paperLow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditorialLabel(text: 'Get the app', color: V2Colors.aurora, pulse: pulse),
            const SizedBox(height: 10),
            Text(
              content.appDownloadTitle,
              style: V2FontStyles.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.2,
                color: V2Colors.inkSaaS,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content.appDownloadDescription,
              style: V2FontStyles.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: V2Colors.inkMutedSaaS,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            V2HeroDownloadBlock(
              links: content.heroCta1StoreButtons,
              alignStart: false,
              flat: true,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: V2Colors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  child: _LinkGroupColumn(
                    group: _MainGrid._explore,
                    dense: true,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: _LinkGroupColumn(
                    group: _MainGrid._company,
                    dense: true,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: V2Colors.hairline),
            ),
            _MobileLegalRow(),
          ],
        ),
      ),
    );
  }
}

class _MobileLegalRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: V2Colors.inkMutedSaaS,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'Legal',
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: V2Colors.inkMutedSaaS,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < _MainGrid._legal.links.length; i++) ...[
              if (i > 0)
                Text(
                  '·',
                  style: V2FontStyles.inter(fontSize: 13, color: V2Colors.fgFaint),
                ),
              _FooterLink(
                label: _MainGrid._legal.links[i].label,
                href: _MainGrid._legal.links[i].href,
                touchTarget: true,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _MobileContactBlock extends StatelessWidget {
  const _MobileContactBlock({required this.content});
  final PublicBrandContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (content.contactEmail.isNotEmpty)
          _MobileContactTile(
            icon: Icons.mail_outline_rounded,
            text: content.contactEmail,
            onTap: () => navigateBrandUrl(context, 'mailto:${content.contactEmail}'),
          ),
        if (content.contactEmail.isNotEmpty && content.contactPhone.isNotEmpty)
          const SizedBox(height: 8),
        if (content.contactPhone.isNotEmpty)
          _MobileContactTile(
            icon: Icons.phone_outlined,
            text: content.contactPhone,
            onTap: () => navigateBrandUrl(context, 'tel:${content.contactPhone}'),
          ),
      ],
    );
  }
}

class _MobileContactTile extends StatelessWidget {
  const _MobileContactTile({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V2Colors.hairline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: V2Colors.plasma),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: V2FontStyles.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: V2Colors.inkSaaS,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: V2Colors.fgFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterHeader extends StatelessWidget {
  const _FooterHeader({required this.v, required this.pulse});
  final V2Responsive v;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditorialLabel(
          text: 'Stay connected',
          color: V2Colors.ember,
          pulse: pulse,
        ),
        SizedBox(height: v.r<double>(xs: 12, md: 14)),
        Text(
          'Your install ecosystem,\nin one place.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 28, md: 32, lg: 36),
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
            height: 1.08,
            color: V2Colors.inkSaaS,
          ),
        ).animate().fadeIn(duration: 480.ms).slideY(begin: 0.06, end: 0),
        SizedBox(height: v.r<double>(xs: 10, md: 12)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Shop, calculate, hire technicians, and manage projects — all from D.G.Yard.',
            style: V2FontStyles.inter(
              fontSize: v.r<double>(xs: 15, md: 16),
              fontWeight: FontWeight.w400,
              height: 1.55,
              letterSpacing: -0.12,
              color: V2Colors.inkMutedSaaS,
            ),
          ),
        ).animate(delay: 80.ms).fadeIn(duration: 460.ms),
      ],
    );
  }
}

class _EditorialLabel extends StatelessWidget {
  const _EditorialLabel({
    required this.text,
    required this.color,
    required this.pulse,
  });

  final String text;
  final Color color;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            return Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25 + pulse.value * 0.35),
                    blurRadius: 6 + pulse.value * 4,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: V2FontStyles.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AppPromoCard extends StatelessWidget {
  const _AppPromoCard({
    required this.content,
    required this.v,
    required this.pulse,
  });
  final PublicBrandContent content;
  final V2Responsive v;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(v.r<double>(xs: 20, md: 22, lg: 24)),
        border: Border.all(color: V2Colors.hairline),
        boxShadow: V2Colors.paperLow,
      ),
      child: Padding(
        padding: EdgeInsets.all(v.r<double>(xs: 20, md: 24, lg: 28)),
        child: v.isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _AppPromoCopy(content: content, v: v, pulse: pulse)),
                  SizedBox(width: v.r<double>(xs: 24, md: 32, lg: 40)),
                  SizedBox(
                    width: v.r<double>(xs: 280, md: 300, lg: 320),
                    child: V2HeroDownloadBlock(
                      links: content.heroCta1StoreButtons,
                      alignStart: true,
                      flat: true,
                      compact: true,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AppPromoCopy(content: content, v: v, pulse: pulse),
                  SizedBox(height: v.r<double>(xs: 18, md: 20)),
                  V2HeroDownloadBlock(
                    links: content.heroCta1StoreButtons,
                    alignStart: true,
                    flat: true,
                    compact: true,
                  ),
                ],
              ),
      ),
    ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }
}

class _AppPromoCopy extends StatelessWidget {
  const _AppPromoCopy({
    required this.content,
    required this.v,
    required this.pulse,
  });
  final PublicBrandContent content;
  final V2Responsive v;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditorialLabel(
          text: 'Get the app',
          color: V2Colors.aurora,
          pulse: pulse,
        ),
        SizedBox(height: v.r<double>(xs: 10, md: 12)),
        Text(
          content.appDownloadTitle,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 20, md: 22, lg: 24),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.15,
            color: V2Colors.inkSaaS,
          ),
        ),
        SizedBox(height: v.r<double>(xs: 8, md: 10)),
        Text(
          content.appDownloadDescription,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 14, md: 15),
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
      ],
    );
  }
}

class _MainGrid extends StatelessWidget {
  const _MainGrid({required this.content, required this.v});
  final PublicBrandContent content;
  final V2Responsive v;

  static const _explore = _LinkGroup(
    label: 'Explore',
    accent: V2Colors.ember,
    links: [
      _FooterLinkData('Store', RouteNames.publicStore),
      _FooterLinkData('Calculator', RouteNames.publicCalculatorList),
      _FooterLinkData('Services', RouteNames.publicServices),
    ],
  );

  static const _company = _LinkGroup(
    label: 'Company',
    accent: V2Colors.plasma,
    links: [
      _FooterLinkData('About', RouteNames.publicAbout),
      _FooterLinkData('Contact', RouteNames.publicContact),
    ],
  );

  static const _legal = _LinkGroup(
    label: 'Legal',
    accent: V2Colors.inkMutedSaaS,
    links: [
      _FooterLinkData('Privacy Policy', RouteNames.webPrivacyPolicy),
      _FooterLinkData('Data deletion', RouteNames.webDataDeletion),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final brandCol = _BrandColumn(content: content, v: v);
    final groups = [_explore, _company, _legal];

    if (v.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: brandCol),
          const SizedBox(width: 40),
          Expanded(flex: 2, child: _LinkGroupColumn(group: groups[0])),
          Expanded(flex: 2, child: _LinkGroupColumn(group: groups[1])),
          Expanded(flex: 2, child: _LinkGroupColumn(group: groups[2])),
        ],
      );
    }

    if (v.isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          brandCol,
          SizedBox(height: v.r<double>(xs: 28, md: 32)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _LinkGroupColumn(group: groups[0])),
              Expanded(child: _LinkGroupColumn(group: groups[1])),
              Expanded(child: _LinkGroupColumn(group: groups[2])),
            ],
          ),
        ],
      );
    }

    // xs/sm use [_MobileFooterLayout] — this branch is unused.
    return const SizedBox.shrink();
  }
}

class _BrandColumn extends StatelessWidget {
  const _BrandColumn({required this.content, required this.v});
  final PublicBrandContent content;
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PublicBrandLogo(size: 30, showName: true),
        SizedBox(height: v.r<double>(xs: 16, md: 18)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            content.footerDescription,
            style: V2FontStyles.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.55,
              color: V2Colors.inkMutedSaaS,
            ),
          ),
        ),
        if (content.contactEmail.isNotEmpty || content.contactPhone.isNotEmpty) ...[
          SizedBox(height: v.r<double>(xs: 16, md: 18)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (content.contactEmail.isNotEmpty)
                _ContactChip(
                  icon: Icons.mail_outline_rounded,
                  text: content.contactEmail,
                  onTap: () => navigateBrandUrl(context, 'mailto:${content.contactEmail}'),
                ),
              if (content.contactPhone.isNotEmpty)
                _ContactChip(
                  icon: Icons.phone_outlined,
                  text: content.contactPhone,
                  onTap: () => navigateBrandUrl(context, 'tel:${content.contactPhone}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ContactChip extends StatefulWidget {
  const _ContactChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  State<_ContactChip> createState() => _ContactChipState();
}

class _ContactChipState extends State<_ContactChip> {
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
          duration: V2.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? Colors.white : V2Footer.background,
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(
              color: _hover ? V2Colors.borderStrong : V2Colors.hairline,
            ),
            boxShadow: _hover ? V2Colors.paperLow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: V2Colors.inkMutedSaaS),
              const SizedBox(width: 6),
              Text(
                widget.text,
                style: V2FontStyles.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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

class _FooterLinkData {
  const _FooterLinkData(this.label, this.href);
  final String label;
  final String href;
}

class _LinkGroup {
  const _LinkGroup({
    required this.label,
    required this.accent,
    required this.links,
  });

  final String label;
  final Color accent;
  final List<_FooterLinkData> links;
}

class _LinkGroupColumn extends StatelessWidget {
  const _LinkGroupColumn({required this.group, this.dense = false});
  final _LinkGroup group;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: group.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              group.label,
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: group.accent,
              ),
            ),
          ],
        ),
        SizedBox(height: dense ? 10 : 14),
        for (final link in group.links) ...[
          _FooterLink(label: link.label, href: link.href, touchTarget: dense),
          SizedBox(height: dense ? 4 : 6),
        ],
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink({
    required this.label,
    required this.href,
    this.touchTarget = false,
  });
  final String label;
  final String href;
  final bool touchTarget;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => navigateBrandUrl(context, widget.href),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.touchTarget ? 6 : 3),
          child: AnimatedDefaultTextStyle(
            duration: V2.dFast,
            style: V2FontStyles.inter(
              fontSize: widget.touchTarget ? 15 : 14,
              fontWeight: FontWeight.w400,
              color: _hover ? V2Colors.inkSaaS : V2Colors.inkMutedSaaS,
              decoration: _hover ? TextDecoration.underline : TextDecoration.none,
              decorationColor: V2Colors.plasma,
              height: 1.4,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _AccentDivider extends StatelessWidget {
  const _AccentDivider({required this.pulse});
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                V2Colors.ember.withValues(alpha: 0.0),
                V2Colors.ember.withValues(alpha: 0.35 + pulse.value * 0.25),
                V2Colors.plasma.withValues(alpha: 0.45 + pulse.value * 0.2),
                V2Colors.aurora.withValues(alpha: 0.35 + pulse.value * 0.25),
                V2Colors.aurora.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.content,
    required this.v,
    this.centered = false,
  });
  final PublicBrandContent content;
  final V2Responsive v;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final copyright = Text(
      centered ? '© ${DateTime.now().year} ${content.companyName}' : '© ${DateTime.now().year} ${content.companyName}. All rights reserved.',
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: V2FontStyles.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: V2Colors.inkMutedSaaS,
      ),
    );
    final socials = _SocialRow(content: content, centered: centered);

    if (v.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: copyright),
          socials,
        ],
      );
    }

    if (centered) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          socials,
          if (content.socialLinks.isNotEmpty) const SizedBox(height: 12),
          copyright,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        socials,
        const SizedBox(height: 12),
        copyright,
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.content, this.centered = false});
  final PublicBrandContent content;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final links = content.socialLinks;
    if (links.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final link in links)
          _SocialPill(label: link.label, url: link.url),
      ],
    );
  }
}

class _SocialPill extends StatefulWidget {
  const _SocialPill({required this.label, required this.url});
  final String label;
  final String url;

  @override
  State<_SocialPill> createState() => _SocialPillState();
}

class _SocialPillState extends State<_SocialPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => navigateBrandUrl(context, widget.url),
        child: AnimatedContainer(
          duration: V2.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? Colors.white : V2Footer.background,
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(
              color: _hover ? V2Colors.borderStrong : V2Colors.hairline,
            ),
          ),
          child: Text(
            widget.label,
            style: V2FontStyles.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _hover ? V2Colors.plasma : V2Colors.inkMutedSaaS,
            ),
          ),
        ),
      ),
    );
  }
}

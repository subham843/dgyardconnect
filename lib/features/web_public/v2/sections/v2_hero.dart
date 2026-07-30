// V2 Hero — next-gen aurora command center.

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../shared/models/hero_accent_config.dart';
import '../../../../shared/models/hero_cta_app_link.dart';
import '../../../../shared/widgets/brand_kit_provider.dart';
import '../../core/brand/public_brand_content.dart';
import '../../core/brand/public_brand_navigation.dart';
import '../v2_colors.dart';
import '../v2_fonts.dart';
import '../v2_text.dart';
import '../v2_perf.dart';
import '../v2_tokens.dart';
import '../v2_navbar_layout.dart';
import '../widgets/v2_navbar.dart';
import '../widgets/v2_button.dart';

class V2Hero extends StatelessWidget {
  const V2Hero({
    super.key,
    this.scrollController,
    this.showNavbar = false,
    this.extendsUnderNav = false,
  });

  final ScrollController? scrollController;
  final bool showNavbar;
  final bool extendsUnderNav;

  @override
  Widget build(BuildContext context) {
    final kit = BrandKitProvider.of(context);
    final content = PublicBrandContent(kit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showNavbar)
          V2Navbar(embedded: true, scrollController: scrollController),
        _NextGenHero(
          content: content,
          scrollController: scrollController,
          extendsUnderNav: extendsUnderNav,
        ),
      ],
    );
  }
}

class _NextGenHero extends StatefulWidget {
  const _NextGenHero({
    required this.content,
    this.scrollController,
    required this.extendsUnderNav,
  });

  final PublicBrandContent content;
  final ScrollController? scrollController;
  final bool extendsUnderNav;

  @override
  State<_NextGenHero> createState() => _NextGenHeroState();
}

class _NextGenHeroState extends State<_NextGenHero> {
  double _scroll = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  void _onScroll() {
    // Parallax setState is costly on CanvasKit — skip on web.
    if (kIsWeb) return;
    final next = widget.scrollController?.offset ?? 0;
    if ((next - _scroll).abs() > 1 && mounted) setState(() => _scroll = next);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final isDesktop = v.width >= V2Breakpoints.lg;
    final navH = widget.extendsUnderNav
        ? 0.0
        : V2NavbarLayout.totalHeight(context, isDesktop: isDesktop, floating: true);
    final topPad = navH + v.r<double>(xs: 22, md: 30, lg: 40);
    final bottomPad = v.r<double>(xs: 38, md: 48, lg: 60);
    final visualShift = (_scroll / 18).clamp(0.0, 34.0);

    return ColoredBox(
      color: const Color(0xFF070A12),
      child: Stack(
        children: [
          const Positioned.fill(child: _HeroAtmosphere()),
          Padding(
            padding: EdgeInsets.fromLTRB(v.gutter, topPad, v.gutter, bottomPad),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1060;
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroCopy(content: widget.content, centered: true),
                          SizedBox(height: v.r<double>(xs: 26, md: 34)),
                          Transform.translate(
                            offset: Offset(0, -visualShift * 0.25),
                            child: _CommandVisual(content: widget.content),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          flex: 11,
                          child: _HeroCopy(content: widget.content),
                        ),
                        const SizedBox(width: 42),
                        Expanded(
                          flex: 10,
                          child: Transform.translate(
                            offset: Offset(0, -visualShift),
                            child: _CommandVisual(content: widget.content),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAtmosphere extends StatelessWidget {
  const _HeroAtmosphere();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.76, -0.48),
                radius: 1.18,
                colors: [
                  V2Colors.plasma.withValues(alpha: 0.32),
                  const Color(0xFF121827).withValues(alpha: 0.84),
                  const Color(0xFF070A12),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: _BlurOrb(
            size: 390,
            color: V2Colors.ember.withValues(alpha: 0.32),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -90,
          child: _BlurOrb(
            size: 430,
            color: V2Colors.aurora.withValues(alpha: 0.24),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(
              line: Colors.white.withValues(alpha: 0.055),
              glow: V2Colors.plasma.withValues(alpha: 0.13),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    if (kIsWeb) return orb;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
      child: orb,
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.line, required this.glow});

  final Color line;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = line
      ..strokeWidth = 1;
    const step = 44.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.82)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.62,
        size.width * 0.58,
        size.height * 0.94,
        size.width * 0.94,
        size.height * 0.34,
      );
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        colors: [Colors.transparent, glow, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.glow != glow;
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.content, this.centered = false});

  final PublicBrandContent content;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final align = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    final headlineSize = v.r<double>(xs: 34, sm: 40, md: 48, lg: 54, xl: 60);

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LiveBadge(text: content.heroBadgeText).v2Animate(
          (w) => w.animate().fadeIn(duration: 450.ms).slideY(begin: 0.18, end: 0),
        ),
        SizedBox(height: v.r<double>(xs: 18, md: 24)),
        ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 690),
              child: _AuroraHeadline(
                content: content,
                fontSize: headlineSize,
                textAlign: textAlign,
              ),
            ).v2Animate(
              (w) => w
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 520.ms)
                  .slideY(begin: 0.08, end: 0),
            ),
        SizedBox(height: v.r<double>(xs: 14, md: 18)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            content.heroSubheadline,
            textAlign: textAlign,
            style: V2Text.bodyLg(
              context,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ).v2Animate((w) => w.animate(delay: 160.ms).fadeIn(duration: 480.ms)),
        SizedBox(height: v.r<double>(xs: 20, md: 26)),
        _HeroActions(content: content, centered: centered).v2Animate(
          (w) => w
              .animate(delay: 240.ms)
              .fadeIn(duration: 480.ms)
              .slideY(begin: 0.12, end: 0),
        ),
        SizedBox(height: v.r<double>(xs: 18, md: 22)),
        _SignalMetrics(content: content, centered: centered).v2Animate(
          (w) => w
              .animate(delay: 320.ms)
              .fadeIn(duration: 480.ms)
              .slideY(begin: 0.08, end: 0),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: V2Colors.aurora,
              boxShadow: [
                BoxShadow(
                  color: V2Colors.aurora.withValues(alpha: 0.65),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text.toUpperCase(),
            style: V2Text.micro(color: Colors.white.withValues(alpha: 0.84)),
          ),
        ],
      ),
    );
  }
}

class _AuroraHeadline extends StatelessWidget {
  const _AuroraHeadline({
    required this.content,
    required this.fontSize,
    required this.textAlign,
  });

  final PublicBrandContent content;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final (prefix, accent) = splitHeroHeadline(
      headline: content.heroHeadline,
      accentWord: content.kit.publicWeb.heroAccentWord,
    );
    final base = V2FontStyles.display(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.02,
      letterSpacing: -0.032 * fontSize,
      color: Colors.white,
    );

    if (accent.isEmpty) {
      return Text(content.heroHeadline, textAlign: textAlign, style: base);
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: base,
        children: [
          if (prefix.trim().isNotEmpty) TextSpan(text: '${prefix.trim()} '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _GradientText(
              accent,
              style: _accentStyle(base),
              colors: [
                Color.lerp(content.heroAccentColor, Colors.white, 0.18)!,
                V2Colors.emberSoft,
                V2Colors.plasmaSoft,
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _accentStyle(TextStyle base) {
    var style = base.copyWith(
      fontWeight: content.heroAccentFontWeight.fontWeight,
      fontStyle: content.heroAccentFontStyle,
    );

    return switch (content.heroAccentFontFamily) {
      HeroAccentFontFamily.display =>
        style.copyWith(fontFamily: V2Fonts.display),
      HeroAccentFontFamily.serif => style.copyWith(
          fontFamily: V2Fonts.accent,
          fontStyle: FontStyle.italic,
        ),
      HeroAccentFontFamily.rounded =>
        style.copyWith(fontFamily: V2Fonts.display),
      HeroAccentFontFamily.mono => style.copyWith(fontFamily: V2Fonts.ui),
      HeroAccentFontFamily.inherit => style,
    };
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.style, required this.colors});

  final String text;
  final TextStyle style;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return v2GradientText(text: text, style: style, colors: colors);
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({required this.content, required this.centered});

  final PublicBrandContent content;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final primaryIsCalculator = _isCalculatorCta(content.heroShopLabel);
    final secondaryIsShop = _isShopCta(content.heroCta2Label);

    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        V2Button(
          label: content.heroShopLabel,
          size: V2BtnSize.lg,
          icon: primaryIsCalculator
              ? Icons.calculate_rounded
              : Icons.storefront_rounded,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () {
            if (primaryIsCalculator) {
              context.go(RouteNames.publicCalculatorList);
              return;
            }
            navigateBrandUrl(context, content.heroShopUrl);
          },
        ),
        _GlassAction(
          label: content.heroCta2Label,
          icon: secondaryIsShop
              ? Icons.storefront_rounded
              : Icons.calculate_rounded,
          onTap: () {
            if (secondaryIsShop) {
              navigateBrandUrl(context, content.heroShopUrl);
              return;
            }
            context.go(RouteNames.publicCalculatorList);
          },
        ),
        _StoreLinks(links: content.heroCta1StoreButtons),
      ],
    );
  }

  bool _isCalculatorCta(String label) {
    final text = label.toLowerCase();
    return text.contains('calc') ||
        text.contains('price') ||
        text.contains('boq') ||
        text.contains('estimate');
  }

  bool _isShopCta(String label) {
    final text = label.toLowerCase();
    return text.contains('shop') ||
        text.contains('store') ||
        text.contains('product');
  }
}

class _GlassAction extends StatefulWidget {
  const _GlassAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassAction> createState() => _GlassActionState();
}

class _GlassActionState extends State<_GlassAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.d,
          curve: V2.eOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hover ? 0.16 : 0.09),
            borderRadius: BorderRadius.circular(V2.rLg),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hover ? 0.3 : 0.17),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: Colors.white.withValues(alpha: 0.9),
                size: 19,
              ),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreLinks extends StatelessWidget {
  const _StoreLinks({required this.links});

  final List<HeroCtaAppLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Download app',
            style: V2Text.smallStrong(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(width: 10),
          for (var i = 0; i < links.length; i++) ...[
            _StoreChip(link: links[i]),
            if (i < links.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StoreChip extends StatefulWidget {
  const _StoreChip({required this.link});

  final HeroCtaAppLink link;

  @override
  State<_StoreChip> createState() => _StoreChipState();
}

class _StoreChipState extends State<_StoreChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.link.hasUrl;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: enabled
            ? () => navigateBrandUrl(context, widget.link.url!)
            : null,
        child: AnimatedContainer(
          duration: V2.d,
          curve: V2.eOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: _hover && enabled ? 0.18 : 0.1,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StoreLogo(link: widget.link),
              const SizedBox(width: 7),
              Text(
                widget.link.label,
                style: V2FontStyles.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreLogo extends StatelessWidget {
  const _StoreLogo({required this.link});

  final HeroCtaAppLink link;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      link.platform == HeroCtaAppPlatform.ios
          ? Icons.apple
          : Icons.play_arrow_rounded,
      color: Colors.white.withValues(alpha: link.hasUrl ? 0.9 : 0.55),
      size: 19,
    );

    final iconUrl = link.iconUrl?.trim();
    if (iconUrl == null || iconUrl.isEmpty) return fallback;

    return Image.network(
      iconUrl,
      width: 19,
      height: 19,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _SignalMetrics extends StatelessWidget {
  const _SignalMetrics({required this.content, required this.centered});

  final PublicBrandContent content;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final items = [
      (content.statProducts, 'Products'),
      (content.statBrands, 'Brands'),
      (content.statDealers, 'Dealers'),
      (content.statProjects, 'Projects'),
    ];

    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items) _SignalMetric(value: item.$1, label: item.$2),
      ],
    );
  }
}

class _SignalMetric extends StatelessWidget {
  const _SignalMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: V2Text.price(context, color: Colors.white),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: V2Text.smallStrong(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandVisual extends StatelessWidget {
  const _CommandVisual({required this.content});

  final PublicBrandContent content;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final compact = v.width < V2Breakpoints.md;
    final height = v.r<double>(xs: 460, sm: 490, md: 520, lg: 550);

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _HologramShell(content: content)),
          Positioned(
            top: compact ? 20 : 32,
            right: compact ? 10 : -12,
            child:
                _FloatingCard(
                      width: compact ? 168 : 198,
                      title: 'IT Shop Catalog',
                      value: content.statProducts,
                      icon: Icons.storefront_rounded,
                      color: V2Colors.aurora,
                    ).v2Animate(
                      (w) => w
                          .animate(delay: 480.ms)
                          .fadeIn(duration: 420.ms)
                          .slideX(begin: 0.12, end: 0),
                    ),
          ),
          Positioned(
            left: compact ? 4 : -24,
            bottom: compact ? 54 : 82,
            child:
                _FloatingCard(
                      width: compact ? 184 : 220,
                      title: 'Technicians Nearby',
                      value: content.statTechnicians,
                      icon: Icons.engineering_rounded,
                      color: V2Colors.ember,
                    ).v2Animate(
                      (w) => w
                          .animate(delay: 560.ms)
                          .fadeIn(duration: 420.ms)
                          .slideX(begin: -0.12, end: 0),
                    ),
          ),
        ],
      ),
    );
  }
}

class _HologramShell extends StatelessWidget {
  const _HologramShell({required this.content});

  final PublicBrandContent content;

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.045),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: V2Colors.plasma.withValues(alpha: 0.28),
                blurRadius: 80,
                offset: const Offset(0, 34),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 42,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF111827),
                          const Color(0xFF0F172A),
                          V2Colors.plasma.withValues(alpha: 0.24),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.02),
                            Colors.black.withValues(alpha: 0.38),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(child: _ConsoleOverlay()),
                  Positioned(
                    left: 22,
                    right: 22,
                    top: 22,
                    child: _ConsoleTopBar(company: content.companyShortName),
                  ),
                  Positioned.fill(
                    top: 78,
                    bottom: 108,
                    left: 22,
                    right: 22,
                    child: _ProductSuiteBoard(content: content),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 22,
                    child: _InsightPanel(content: content),
                  ),
                ],
              ),
            ),
          ),
        ).v2Animate(
          (w) => w
              .animate(delay: 280.ms)
              .fadeIn(duration: 540.ms)
              .scale(
                begin: const Offset(0.96, 0.96),
                end: const Offset(1, 1),
                curve: V2.eOut,
              ),
        );
  }
}

class _ProductSuiteBoard extends StatelessWidget {
  const _ProductSuiteBoard({required this.content});

  final PublicBrandContent content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 420;
        final cards = [
          _SuiteFeature(
            eyebrow: 'DG Yard IT Shop',
            title: 'Buy CCTV, IT & security products',
            meta: '${content.statProducts} products',
            icon: Icons.shopping_bag_rounded,
            color: V2Colors.aurora,
          ),
          _SuiteFeature(
            eyebrow: 'BOQ Price Calculator',
            title: 'Create project BOQ with instant pricing',
            meta: 'Fast estimates',
            icon: Icons.calculate_rounded,
            color: V2Colors.ember,
          ),
          _SuiteFeature(
            eyebrow: 'DG Yard Connect',
            title: 'Find verified technicians nearby',
            meta: '${content.statTechnicians} technicians',
            icon: Icons.location_searching_rounded,
            color: V2Colors.plasmaSoft,
          ),
        ];

        if (tight) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(
                  child: _SuiteFeatureCard(feature: cards[i], index: i),
                ),
                if (i < cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _SuiteFeatureCard(feature: cards[0], index: 0),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SuiteFeatureCard(feature: cards[1], index: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _SuiteFeatureCard(feature: cards[2], index: 2, wide: true),
            ),
          ],
        );
      },
    );
  }
}

class _SuiteFeature {
  const _SuiteFeature({
    required this.eyebrow,
    required this.title,
    required this.meta,
    required this.icon,
    required this.color,
  });

  final String eyebrow;
  final String title;
  final String meta;
  final IconData icon;
  final Color color;
}

class _SuiteFeatureCard extends StatelessWidget {
  const _SuiteFeatureCard({
    required this.feature,
    required this.index,
    this.wide = false,
  });

  final _SuiteFeature feature;
  final int index;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
              padding: EdgeInsets.all(wide ? 15 : 13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12 + index * 0.01),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: feature.color.withValues(alpha: 0.16),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -18,
                    bottom: -20,
                    child: Icon(
                      feature.icon,
                      size: wide ? 96 : 70,
                      color: feature.color.withValues(alpha: 0.12),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final veryTight = constraints.maxHeight < 132;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _MiniIcon(
                                icon: feature.icon,
                                color: feature.color,
                                size: veryTight ? 30 : 34,
                                iconSize: veryTight ? 16 : 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature.eyebrow,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V2FontStyles.inter(
                                    fontSize: veryTight ? 9.5 : 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.45,
                                    color: feature.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            feature.title,
                            maxLines: veryTight ? 2 : (wide ? 2 : 3),
                            overflow: TextOverflow.ellipsis,
                            style: V2FontStyles.inter(
                              fontSize: veryTight ? 15.5 : (wide ? 21 : 17),
                              height: 1.04,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.45,
                              color: Colors.white,
                            ),
                          ),
                          if (!veryTight)
                            _SuiteMetaPill(
                              text: feature.meta,
                              color: feature.color,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ).v2Animate(
              (w) => w
                  .animate(delay: (360 + index * 80).ms)
                  .fadeIn(duration: 420.ms)
                  .slideY(begin: 0.08, end: 0),
            );
  }
}

class _SuiteMetaPill extends StatelessWidget {
  const _SuiteMetaPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: V2FontStyles.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _ConsoleOverlay extends StatelessWidget {
  const _ConsoleOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ConsolePainter(
        line: Colors.white.withValues(alpha: 0.11),
        accent: V2Colors.aurora.withValues(alpha: 0.46),
        ember: V2Colors.ember.withValues(alpha: 0.58),
      ),
    );
  }
}

class _ConsolePainter extends CustomPainter {
  const _ConsolePainter({
    required this.line,
    required this.accent,
    required this.ember,
  });

  final Color line;
  final Color accent;
  final Color ember;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = line;

    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.22 + i * 0.12);
      canvas.drawLine(
        Offset(size.width * 0.08, y),
        Offset(size.width * 0.92, y),
        paint,
      );
    }

    final route = Path()
      ..moveTo(size.width * 0.16, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.32,
        size.width * 0.84,
        size.height * 0.5,
      );
    canvas.drawPath(
      route,
      paint
        ..color = accent
        ..strokeWidth = 2.4,
    );

    final dot = Paint()..style = PaintingStyle.fill;
    for (final point in [
      Offset(size.width * 0.16, size.height * 0.62),
      Offset(size.width * 0.46, size.height * 0.42),
      Offset(size.width * 0.84, size.height * 0.5),
    ]) {
      canvas.drawCircle(
        point,
        6,
        dot..color = Colors.white.withValues(alpha: 0.94),
      );
      canvas.drawCircle(point, 12, dot..color = accent.withValues(alpha: 0.22));
    }

    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.29),
      36,
      paint
        ..color = ember
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ConsolePainter oldDelegate) => false;
}

class _ConsoleTopBar extends StatelessWidget {
  const _ConsoleTopBar({required this.company});

  final String company;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const _WindowDots(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$company Product Suite',
              overflow: TextOverflow.ellipsis,
              style: V2Text.smallStrong(color: Colors.white.withValues(alpha: 0.86)),
            ),
          ),
          Icon(
            Icons.auto_awesome_rounded,
            color: V2Colors.emberSoft,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _WindowDots extends StatelessWidget {
  const _WindowDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in const [
          Color(0xFFFF5F57),
          Color(0xFFFFBD2E),
          Color(0xFF28C840),
        ])
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
      ],
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.content});

  final PublicBrandContent content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF020617).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MiniIcon(
                    icon: Icons.hub_rounded,
                    color: V2Colors.aurora,
                    size: 34,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'IT Shop se product select karo, BOQ Calculator se pricing banao, Connect se technician find karo.',
                      style: V2FontStyles.inter(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      value: content.statTechnicians,
                      label: 'Technicians',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      value: content.statProjects,
                      label: 'BOQs / Projects',
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.icon,
    required this.color,
    this.size = 38,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: V2FontStyles.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: V2FontStyles.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.54),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
            children: [
              _MiniIcon(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: V2FontStyles.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2FontStyles.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.56),
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

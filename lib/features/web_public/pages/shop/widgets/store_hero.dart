// Dynamic admin-driven hero banner slider + active-offers strip.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';

import '../../../core/brand/public_brand_navigation.dart';
import '../../../v2/v2_colors.dart';
import '../../../v2/v2_tokens.dart';
import '../../../v2/v2_text.dart';
import '../../../data/models/public_store_models.dart';
import 'store_atoms.dart';

class StoreHeroSlider extends StatefulWidget {
  const StoreHeroSlider({
    super.key,
    required this.banners,
    required this.onBrowse,
  });

  final List<PublicBanner> banners;
  final VoidCallback onBrowse;

  @override
  State<StoreHeroSlider> createState() => _StoreHeroSliderState();
}

class _StoreHeroSliderState extends State<StoreHeroSlider> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_controller.hasClients) return;
        _index = (_index + 1) % widget.banners.length;
        _controller.animateToPage(
          _index,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final height = v.r(xs: 460.0, md: 540.0, lg: 620.0);

    if (widget.banners.isEmpty) {
      return _FallbackHero(height: height, onBrowse: widget.onBrowse);
    }

    final isMobile = v.isMobile;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.banners.length,
            itemBuilder: (context, i) =>
                _BannerSlide(banner: widget.banners[i], isMobile: isMobile),
          ),
          if (widget.banners.length > 1)
            Positioned(
              bottom: V2.s6,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.banners.length, (i) {
                  final active = i == _index;
                  return GestureDetector(
                    onTap: () => _controller.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 28 : 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: active
                            ? V2Colors.ember
                            : V2Colors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(V2.rFull),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner, required this.isMobile});

  final PublicBanner banner;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final imageUrl = isMobile
        ? (banner.mobileImageUrl ?? banner.imageUrl)
        : banner.imageUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        StoreImage(
          url: imageUrl,
          fallbackIcon: Icons.image_outlined,
          backgroundColor: V2Colors.ink,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xE60A0E27), Color(0x800A0E27), Color(0x1A0A0E27)],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? V2.s6 : V2.s24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (banner.subtitle != null && banner.subtitle!.isNotEmpty)
                    StorePill(
                          label: banner.subtitle!.toUpperCase(),
                          color: V2Colors.ember,
                        )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideX(begin: -0.1, end: 0),
                  const SizedBox(height: V2.s4),
                  ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Text(
                          banner.title,
                          style:
                              (isMobile
                                      ? V2Text.h2(context)
                                      : V2Text.h1(context))
                                  .copyWith(
                                    color: V2Colors.surface,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 100.ms)
                      .slideY(begin: 0.15, end: 0),
                  if (banner.description != null &&
                      banner.description!.isNotEmpty) ...[
                    const SizedBox(height: V2.s4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        banner.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.bodyLg(context).copyWith(
                          color: V2Colors.surface.withValues(alpha: 0.85),
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                  ],
                  if (banner.ctaText != null && banner.ctaText!.isNotEmpty) ...[
                    const SizedBox(height: V2.s8),
                    _HeroCta(
                          label: banner.ctaText!,
                          onTap: () {
                            final url = banner.ctaUrl;
                            if (url != null && url.isNotEmpty) {
                              navigateBrandUrl(context, url);
                            }
                          },
                        )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 300.ms)
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1, 1),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCta extends StatefulWidget {
  const _HeroCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_HeroCta> createState() => _HeroCtaState();
}

class _HeroCtaState extends State<_HeroCta> {
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
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
          decoration: BoxDecoration(
            gradient: V2Colors.emberGradient,
            borderRadius: BorderRadius.circular(V2.rFull),
            boxShadow: [
              BoxShadow(
                color: V2Colors.ember.withValues(alpha: _hover ? 0.55 : 0.3),
                blurRadius: _hover ? 30 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: V2Text.btn().copyWith(color: V2Colors.surface),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: EdgeInsets.only(left: _hover ? 12 : 8),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: V2Colors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium fallback when admin has not published store banners yet.
class _FallbackHero extends StatelessWidget {
  const _FallbackHero({required this.height, required this.onBrowse});

  final double height;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Container(
      height: height,
      decoration: const BoxDecoration(gradient: V2Colors.heroGradient),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: v.r(xs: V2.s6, lg: V2.s24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StorePill(
                    label: 'ENTERPRISE-GRADE TECHNOLOGY',
                    color: V2Colors.ember,
                  ),
                  const SizedBox(height: V2.s4),
                  ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Text(
                          'Security & IT, engineered for the modern enterprise.',
                          style: v
                              .r(xs: V2Text.h2(context), lg: V2Text.h1(context))
                              .copyWith(
                                color: V2Colors.surface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 700.ms)
                      .slideY(begin: 0.15, end: 0),
                  const SizedBox(height: V2.s4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Text(
                      'Browse a curated catalog of CCTV, networking, and infrastructure from the brands you trust.',
                      style: V2Text.bodyLg(context).copyWith(
                        color: V2Colors.surface.withValues(alpha: 0.82),
                      ),
                    ),
                  ).animate().fadeIn(duration: 700.ms, delay: 150.ms),
                  const SizedBox(height: V2.s8),
                  _HeroCta(label: 'Browse the store', onTap: onBrowse)
                      .animate()
                      .fadeIn(duration: 700.ms, delay: 300.ms)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = V2Colors.surface.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const spacing = 44.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Horizontal strip of active admin offers (festival, flash, brand, category…).
class StoreOffersStrip extends StatelessWidget {
  const StoreOffersStrip({
    super.key,
    required this.offers,
    required this.onOfferTap,
  });

  final List<PublicOffer> offers;
  final void Function(PublicOffer offer) onOfferTap;

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        itemCount: offers.length,
        separatorBuilder: (_, _) => const SizedBox(width: V2.s4),
        itemBuilder: (context, i) =>
            _OfferCard(offer: offers[i], onTap: () => onOfferTap(offers[i])),
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  const _OfferCard({required this.offer, required this.onTap});
  final PublicOffer offer;
  final VoidCallback onTap;

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final accent = o.accentColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 320,
          transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
          padding: const EdgeInsets.all(V2.s6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [V2Colors.ink, accent.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(V2.r2xl),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: _hover ? 0.4 : 0.2),
                blurRadius: _hover ? 26 : 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StorePill(
                    label: o.isFlash ? 'FLASH SALE' : o.offerType.toUpperCase(),
                    color: V2Colors.surface.withValues(alpha: 0.22),
                  ),
                  const Spacer(),
                  if (o.isFlash)
                    const Icon(
                      Icons.bolt_rounded,
                      color: V2Colors.surface,
                      size: 20,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                o.headlineDiscount,
                style: V2Text.h3(context).copyWith(
                  color: V2Colors.surface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                o.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: V2Text.bodyEmph().copyWith(
                  color: V2Colors.surface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: V2.s2),
              Row(
                children: [
                  Text(
                    'Shop offer',
                    style: V2Text.smallStrong().copyWith(
                      color: V2Colors.surface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: V2Colors.surface,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
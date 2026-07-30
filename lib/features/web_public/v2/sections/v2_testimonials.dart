// Testimonials — editorial quote carousel, Apple-style voices section.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import '../../v2/v2_font_styles.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/supabase/public_rest_client.dart';
import '../../data/models/public_cms_item.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../widgets/v2_section.dart';

class V2Testimonials extends StatefulWidget {
  const V2Testimonials({super.key});

  @override
  State<V2Testimonials> createState() => _V2TestimonialsState();
}

class _V2TestimonialsState extends State<V2Testimonials> {
  final _page = PageController(viewportFraction: 0.92);
  List<_TestimonialItem> _items = const [];
  bool _loading = true;
  int _index = 0;
  bool _hover = false;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _page.addListener(_onPage);
    _load();
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.removeListener(_onPage);
    _page.dispose();
    super.dispose();
  }

  void _startAuto() {
    _auto?.cancel();
    if (_items.length < 2 || _hover) return;
    _auto = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_page.hasClients || _hover) return;
      final next = (_index + 1) % _items.length;
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onHover(bool hover) {
    setState(() => _hover = hover);
    if (hover) {
      _auto?.cancel();
    } else {
      _startAuto();
    }
  }

  void _onPage() {
    if (!_page.hasClients) return;
    final i = _page.page?.round() ?? 0;
    if (i != _index) setState(() => _index = i);
  }

  Future<void> _load() async {
    try {
      final rows = await PublicRestClient.select(
        'public_cms_content',
        order: 'sort_order,created_at',
        eq: {'content_type': 'testimonial', 'is_active': 'true'},
      );
      final items = rows.map(PublicCmsItem.fromRow).map(_TestimonialItem.fromCms).toList();
      if (!mounted) return;
      setState(() {
        _items = items.isNotEmpty ? items : _TestimonialItem.fallback;
        _loading = false;
      });
      _startAuto();
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = _TestimonialItem.fallback;
          _loading = false;
        });
        _startAuto();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) return const SizedBox.shrink();

    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.md;

    return V2Section(
      background: Colors.white,
      borderTop: true,
      padTopOverride: v.r<double>(xs: 32, md: 40, lg: 44),
      padBottomOverride: v.r<double>(xs: 36, md: 44, lg: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(v: v),
          SizedBox(height: v.r<double>(xs: 24, md: 32)),
          if (_loading)
            _Skeleton(v: v)
          else ...[
            MouseRegion(
              onEnter: (_) => _onHover(true),
              onExit: (_) => _onHover(false),
              child: SizedBox(
                height: v.r<double>(xs: 280, md: 260, lg: 248),
                child: PageView.builder(
                  controller: _page,
                  itemCount: _items.length,
                  padEnds: false,
                  itemBuilder: (context, i) {
                    final active = i == _index;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: i < _items.length - 1 ? 14 : 0,
                        left: i == 0 ? 0 : 2,
                      ),
                      child: _QuoteCard(
                        item: _items[i],
                        active: active,
                        wide: wide,
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: v.r<double>(xs: 18, md: 22)),
            Center(
              child: SmoothPageIndicator(
                controller: _page,
                count: _items.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  expansionFactor: 3.2,
                  spacing: 8,
                  activeDotColor: V2Colors.plasma,
                  dotColor: V2Colors.borderStrong,
                ),
                onDotClicked: (i) => _page.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
            if (!_hover && _items.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    'Auto-advances · hover to pause',
                    style: V2FontStyles.inter(
                      fontSize: 11,
                      color: V2Colors.inkMutedSaaS,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _TestimonialItem {
  const _TestimonialItem({
    required this.quote,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.rating = 5,
  });

  final String quote;
  final String name;
  final String role;
  final String? avatarUrl;
  final int rating;

  factory _TestimonialItem.fromCms(PublicCmsItem item) {
    return _TestimonialItem(
      quote: item.description?.trim().isNotEmpty == true
          ? item.description!.trim()
          : (item.subtitle ?? ''),
      name: item.title?.trim().isNotEmpty == true ? item.title!.trim() : 'Client',
      role: item.subtitle?.trim().isNotEmpty == true
          ? item.subtitle!.trim()
          : (item.metaString('role') ?? item.metaString('company') ?? ''),
      avatarUrl: item.imageUrl,
      rating: item.rating,
    );
  }

  static const fallback = [
    _TestimonialItem(
      quote:
          'D.G.Yard delivered our entire CCTV upgrade on schedule — clear quotes, '
          'genuine products, and professional installation support throughout.',
      name: 'Rahul Sharma',
      role: 'Facility Manager · Pune',
      rating: 5,
    ),
    _TestimonialItem(
      quote:
          'From BOQ to final handover, the team kept everything transparent. '
          'Our campus security rollout was smoother than any vendor we tried before.',
      name: 'Priya Mehta',
      role: 'IT Head · Ahmedabad',
      rating: 5,
    ),
    _TestimonialItem(
      quote:
          'We source cameras, networking, and access control from one place — '
          'fast dispatch, fair pricing, and warranty support that actually responds.',
      name: 'Arun Krishnan',
      role: 'Operations Lead · Bengaluru',
      rating: 5,
    ),
  ];
}

class _Header extends StatelessWidget {
  const _Header({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: V2Colors.plasma, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'Clients',
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: V2Colors.plasma,
              ),
            ),
          ],
        ),
        SizedBox(height: v.r<double>(xs: 8, md: 10)),
        Text(
          'What our clients say.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 32, md: 40, lg: 44),
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.04,
            color: V2Colors.inkSaaS,
          ),
        ),
        SizedBox(height: v.r<double>(xs: 8, md: 10)),
        Text(
          'Feedback from businesses and project teams who rely on D.G.Yard every day.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 14, md: 15),
            height: 1.45,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.item,
    required this.active,
    required this.wide,
  });

  final _TestimonialItem item;
  final bool active;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scale = active ? 1.0 : 0.97;
    final opacity = active ? 1.0 : 0.72;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                V2Colors.plasma.withValues(alpha: 0.05),
                Colors.white,
                V2Colors.aurora.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: active ? V2Colors.plasma.withValues(alpha: 0.28) : V2Colors.borderSubtle,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: V2Colors.plasma.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(wide ? 28 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 28,
                      color: V2Colors.plasma.withValues(alpha: 0.55),
                    ),
                    const Spacer(),
                    _StarRow(rating: item.rating),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.quote,
                      style: V2FontStyles.inter(
                        fontSize: wide ? 18 : 16,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        letterSpacing: -0.25,
                        color: V2Colors.inkSaaS,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Avatar(name: item.name, url: item.avatarUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: V2FontStyles.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: V2Colors.inkSaaS,
                            ),
                          ),
                          Text(
                            item.role,
                            style: V2FontStyles.inter(
                              fontSize: 12,
                              color: V2Colors.inkMutedSaaS,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: i < rating ? V2Colors.ember : V2Colors.borderStrong,
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            V2Colors.plasma.withValues(alpha: 0.18),
            V2Colors.aurora.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(color: V2Colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              memCacheWidth: 128,
              errorWidget: (_, _, _) => _Initial(name: name),
            )
          : _Initial(name: name),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final init = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Center(
      child: Text(
        init,
        style: V2FontStyles.inter(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: V2Colors.plasma,
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: v.r<double>(xs: 280, md: 260),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: V2Colors.borderSubtle),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1400.ms, color: V2Colors.bgSubtle);
  }
}

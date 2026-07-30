// Trusted Brands — compact partner rail (products section ke baad).

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/supabase/public_rest_client.dart';
import '../../../../shared/widgets/brand_logo_canvas.dart';
import '../../data/models/public_brand.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../widgets/v2_section.dart';
import '../widgets/v2_tilt_3d_card.dart';

class V2TrustedBrands extends StatefulWidget {
  const V2TrustedBrands({super.key});

  @override
  State<V2TrustedBrands> createState() => _V2TrustedBrandsState();
}

class _V2TrustedBrandsState extends State<V2TrustedBrands> {
  List<PublicBrand> _brands = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await PublicRestClient.select(
        'brands',
        order: 'display_order,name',
        eq: {'is_active': 'true'},
      );
      if (!mounted) return;
      setState(() {
        _brands = rows.map(PublicBrand.fromRow).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<PublicBrand> _pick(List<PublicBrand> all) {
    final featured = all.where((b) => b.isFeaturedOnHomepage).toList();
    if (featured.length >= 4) return featured.take(8).toList(growable: false);
    final ids = featured.map((b) => b.id).toSet();
    final rest = all
        .where((b) => !ids.contains(b.id))
        .take(8 - featured.length);
    return [...featured, ...rest].take(8).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _brands.isEmpty) return const SizedBox.shrink();

    final v = V2Responsive(context);
    final brands = _pick(_brands);

    return V2Section(
      background: Colors.white,
      borderTop: true,
      padTopOverride: v.r<double>(xs: 28, md: 32, lg: 36),
      padBottomOverride: v.r<double>(xs: 28, md: 32, lg: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(v: v),
          SizedBox(height: v.r<double>(xs: 20, md: 24)),
          if (_loading)
            _RailSkeleton(v: v)
          else if (brands.isNotEmpty)
            _BrandRail(v: v, brands: brands),
        ],
      ),
    ).animate().fadeIn(duration: 480.ms);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Partners',
          style: V2FontStyles.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: V2Colors.plasma,
          ),
        ),
        SizedBox(height: v.r<double>(xs: 6, md: 8)),
        Text(
          'Trusted brands.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 28, md: 34, lg: 38),
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            height: 1.05,
            color: V2Colors.inkSaaS,
          ),
        ),
        SizedBox(height: v.r<double>(xs: 8, md: 10)),
        Text(
          'Authorized dealer — genuine products, full warranty.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 14, md: 15),
            height: 1.45,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
        const SizedBox(height: 10),
        _HeaderLink(
          label: 'Shop by brand',
          onTap: () => context.go(RouteNames.publicStore),
        ),
      ],
    );
  }
}

class _BrandRail extends StatefulWidget {
  const _BrandRail({required this.v, required this.brands});
  final V2Responsive v;
  final List<PublicBrand> brands;

  @override
  State<_BrandRail> createState() => _BrandRailState();
}

class _BrandRailState extends State<_BrandRail> {
  final _ctrl = ScrollController();
  bool _back = false;
  bool _forward = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _sync() {
    if (!_ctrl.hasClients) return;
    final pos = _ctrl.position;
    final back = pos.pixels > 4;
    final forward = pos.pixels < pos.maxScrollExtent - 4;
    if (back != _back || forward != _forward) {
      setState(() {
        _back = back;
        _forward = forward;
      });
    }
  }

  void _scroll(double delta) {
    if (!_ctrl.hasClients) return;
    final target = (_ctrl.offset + delta).clamp(
      0.0,
      _ctrl.position.maxScrollExtent,
    );
    _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final cardW = v.r<double>(xs: 132, sm: 140, md: 148);
    final cardH = v.r<double>(xs: 112, md: 120);

    return SizedBox(
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView.separated(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: _back ? 40 : 0,
              right: _forward ? 40 : 0,
            ),
            itemCount: widget.brands.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: v.r<double>(xs: 10, md: 12)),
            itemBuilder: (context, i) => SizedBox(
              width: cardW,
              height: cardH,
              child: _BrandTile(brand: widget.brands[i], index: i),
            ),
          ),
          if (_back)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _RailNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _scroll(-160),
                ),
              ),
            ),
          if (_forward)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _RailNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _scroll(160),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.brand, required this.index});
  final PublicBrand brand;
  final int index;

  @override
  Widget build(BuildContext context) {
    return V2Tilt3DCard(
          borderRadius: 14,
          maxTilt: 0.07,
          hoverLift: 3,
          backgroundColor: const Color(0xFFF5F5F7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => context.go(RouteNames.publicStore),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: BrandLogoCanvas(
                    width: 100,
                    height: 40,
                    logoUrl: brand.logoUrl,
                    mimeType: brand.logoMimeType,
                    layout: brand.logoLayout,
                    fallbackLabel: brand.name,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: V2FontStyles.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: V2Colors.inkMutedSaaS,
                ),
              ),
            ],
          ),
        )
        .animate(delay: (40 + index * 40).ms)
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.03, end: 0);
  }
}

class _HeaderLink extends StatefulWidget {
  const _HeaderLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_HeaderLink> createState() => _HeaderLinkState();
}

class _HeaderLinkState extends State<_HeaderLink> {
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
              widget.label,
              style: V2FontStyles.inter(
                fontSize: 13,
                color: V2Colors.plasma,
                decoration: _hover
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: V2Colors.plasma,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.north_east_rounded, size: 12, color: V2Colors.plasma),
          ],
        ),
      ),
    );
  }
}

class _RailNavButton extends StatelessWidget {
  const _RailNavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 20, color: V2Colors.inkSaaS),
        ),
      ),
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    final h = v.r<double>(xs: 112, md: 120);
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) =>
            Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: V2Colors.borderSubtle),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1400.ms, color: V2Colors.bgSubtle),
      ),
    );
  }
}

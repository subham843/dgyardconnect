// Deal of the Day + Newly Launched — Apple editorial product rails.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../data/models/public_store_models.dart';
import '../../data/repositories/public_store_repository.dart';
import '../../pages/shop/widgets/store_atoms.dart';
import '../../pages/shop/widgets/store_product_image.dart';
import '../../state/public_cart.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../widgets/v2_section.dart';
import '../widgets/v2_tilt_3d_card.dart';

class V2ProductsShowcase extends StatefulWidget {
  const V2ProductsShowcase({super.key});

  static const background = Color(0xFFF5F5F7);

  @override
  State<V2ProductsShowcase> createState() => _V2ProductsShowcaseState();
}

class _V2ProductsShowcaseState extends State<V2ProductsShowcase> {
  final _repo = PublicStoreRepository();
  final _dealCtrl = ScrollController();
  final _newCtrl = ScrollController();

  List<PublicProduct> _dealOfDay = const [];
  List<PublicProduct> _newlyLaunched = const [];
  bool _loading = true;
  bool _dealBack = false;
  bool _dealForward = false;
  bool _newBack = false;
  bool _newForward = false;

  @override
  void initState() {
    super.initState();
    _dealCtrl.addListener(() => _syncRail(_dealCtrl, isDeal: true));
    _newCtrl.addListener(() => _syncRail(_newCtrl, isDeal: false));
    _load();
  }

  @override
  void dispose() {
    _dealCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final catalog = await _repo.loadCatalog();
      final all = catalog.products;
      final deals = _pickDealOfDay(all);
      final dealIds = deals.map((p) => p.id).toSet();
      final newest = _pickNewlyLaunched(all, excludeIds: dealIds);

      if (!mounted) return;
      setState(() {
        _dealOfDay = deals;
        _newlyLaunched = newest;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncRail(_dealCtrl, isDeal: true);
        _syncRail(_newCtrl, isDeal: false);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Highest discount first; only products with an active price cut.
  static List<PublicProduct> _pickDealOfDay(List<PublicProduct> all) {
    final pool = all
        .where((p) => p.hasDiscount && p.discountPercent > 0)
        .toList();
    pool.sort((a, b) {
      final cmp = b.discountPercent.compareTo(a.discountPercent);
      if (cmp != 0) return cmp;
      final saveA = (a.mrp ?? 0) - (a.price ?? 0);
      final saveB = (b.mrp ?? 0) - (b.price ?? 0);
      if (saveA != saveB) return saveB.compareTo(saveA);
      final dA = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final dB = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return dB.compareTo(dA);
    });
    return pool.take(10).toList(growable: false);
  }

  static List<PublicProduct> _pickNewlyLaunched(
    List<PublicProduct> all, {
    required Set<String> excludeIds,
  }) {
    final now = DateTime.now();
    final pool = all.where((p) => !excludeIds.contains(p.id)).toList();
    pool.sort((a, b) {
      final dA = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final dB = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return dB.compareTo(dA);
    });

    final recent = pool.where((p) {
      final created = p.createdAt;
      if (created == null) return false;
      return now.difference(created).inDays <= 90;
    }).toList();

    final source = recent.length >= 4 ? recent : pool;
    return source.take(10).toList(growable: false);
  }

  void _syncRail(ScrollController ctrl, {required bool isDeal}) {
    if (!ctrl.hasClients) return;
    final pos = ctrl.position;
    final back = pos.pixels > 4;
    final forward = pos.pixels < pos.maxScrollExtent - 4;
    if (isDeal) {
      if (back != _dealBack || forward != _dealForward) {
        setState(() {
          _dealBack = back;
          _dealForward = forward;
        });
      }
    } else {
      if (back != _newBack || forward != _newForward) {
        setState(() {
          _newBack = back;
          _newForward = forward;
        });
      }
    }
  }

  void _scrollRail(ScrollController ctrl, double delta) {
    if (!ctrl.hasClients) return;
    final target = (ctrl.offset + delta).clamp(
      0.0,
      ctrl.position.maxScrollExtent,
    );
    ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _dealOfDay.isEmpty && _newlyLaunched.isEmpty) {
      return const SizedBox.shrink();
    }

    final v = V2Responsive(context);

    return V2Section(
      background: V2ProductsShowcase.background,
      padTopOverride: v.r<double>(xs: 42, md: 52, lg: 62),
      padBottomOverride: v.r<double>(xs: 42, md: 52, lg: 62),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(v: v),
          SizedBox(height: v.r<double>(xs: 26, md: 32)),
          if (_loading) ...[
            _RailSkeleton(v: v),
            SizedBox(height: v.r<double>(xs: 28, md: 32)),
            _RailSkeleton(v: v),
          ] else ...[
            if (_dealOfDay.isNotEmpty) ...[
              _EditorialRailHeader(
                eyebrow: 'Today · Best value',
                eyebrowColor: V2Colors.ember,
                title: 'Offers worth a closer look.',
                subtitle:
                    'Special prices on practical gear for homes, offices and project sites.',
              ),
              SizedBox(height: v.r<double>(xs: 14, md: 18)),
              _ProductRail(
                v: v,
                products: _dealOfDay,
                controller: _dealCtrl,
                canScrollBack: _dealBack,
                canScrollForward: _dealForward,
                onBack: () => _scrollRail(_dealCtrl, -240),
                onForward: () => _scrollRail(_dealCtrl, 240),
                badge: _ProductBadge.deal,
              ),
            ],
            if (_dealOfDay.isNotEmpty && _newlyLaunched.isNotEmpty)
              SizedBox(height: v.r<double>(xs: 40, md: 48)),
            if (_newlyLaunched.isNotEmpty) ...[
              _EditorialRailHeader(
                eyebrow: 'Just in',
                eyebrowColor: V2Colors.aurora,
                title: 'Fresh arrivals for your next setup.',
                subtitle:
                    'New CCTV, networking and security products added to the DG Yard Store.',
              ),
              SizedBox(height: v.r<double>(xs: 18, md: 22)),
              _ProductRail(
                v: v,
                products: _newlyLaunched,
                controller: _newCtrl,
                canScrollBack: _newBack,
                canScrollForward: _newForward,
                onBack: () => _scrollRail(_newCtrl, -240),
                onForward: () => _scrollRail(_newCtrl, 240),
                badge: _ProductBadge.newLaunch,
              ),
            ],
          ],
        ],
      ),
    ).animate().fadeIn(duration: 520.ms);
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
        RichText(
          text: TextSpan(
            style: V2FontStyles.inter(
              fontSize: v.r<double>(xs: 34, md: 44, lg: 52),
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
              height: 1.02,
              color: V2Colors.inkSaaS,
            ),
            children: [
              const TextSpan(text: 'The latest. '),
              TextSpan(
                text: 'Take a look at what is ready now.',
                style: TextStyle(color: V2Colors.inkMutedSaaS),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 450.ms),
        SizedBox(height: v.r<double>(xs: 10, md: 12)),
        Text(
          'Curated product shelves for security, IT infrastructure and smart project buying.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 15, md: 16),
            height: 1.5,
            color: V2Colors.inkMutedSaaS,
          ),
        ).animate(delay: 80.ms).fadeIn(duration: 480.ms),
        const SizedBox(height: 12),
        _HeaderLink(
          label: 'Browse the full store',
          onTap: () => context.go(RouteNames.publicStore),
        ).animate(delay: 120.ms).fadeIn(duration: 450.ms),
      ],
    );
  }
}

class _EditorialRailHeader extends StatelessWidget {
  const _EditorialRailHeader({
    required this.eyebrow,
    required this.eyebrowColor,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final Color eyebrowColor;
  final String title;
  final String subtitle;

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
              decoration: BoxDecoration(
                color: eyebrowColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              eyebrow,
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: eyebrowColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: V2FontStyles.inter(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.08,
            color: V2Colors.inkSaaS,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: V2FontStyles.inter(
            fontSize: 14,
            height: 1.45,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
      ],
    );
  }
}

class _EditorialTag extends StatelessWidget {
  const _EditorialTag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: V2FontStyles.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
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
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: V2Colors.plasma,
                decoration: _hover
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: V2Colors.plasma,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.north_east_rounded, size: 13, color: V2Colors.plasma),
          ],
        ),
      ),
    );
  }
}

enum _ProductBadge { deal, newLaunch }

class _ProductRail extends StatelessWidget {
  const _ProductRail({
    required this.v,
    required this.products,
    required this.controller,
    required this.canScrollBack,
    required this.canScrollForward,
    required this.onBack,
    required this.onForward,
    required this.badge,
  });

  final V2Responsive v;
  final List<PublicProduct> products;
  final ScrollController controller;
  final bool canScrollBack;
  final bool canScrollForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final _ProductBadge badge;

  @override
  Widget build(BuildContext context) {
    final tileWidth = v.r<double>(xs: 184, sm: 196, md: 214, lg: 232);
    final railHeight = v.r<double>(xs: 292, md: 304, lg: 318);

    return SizedBox(
      height: railHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: canScrollBack ? 44 : 0,
              right: canScrollForward ? 44 : 0,
            ),
            itemCount: products.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: v.r<double>(xs: 12, md: 14)),
            itemBuilder: (context, index) {
              return _ProductTile(
                product: products[index],
                width: tileWidth,
                badge: badge,
                index: index,
              );
            },
          ),
          if (canScrollBack)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _RailNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onBack,
                ),
              ),
            ),
          if (canScrollForward)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _RailNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onForward,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatefulWidget {
  const _ProductTile({
    required this.product,
    required this.width,
    required this.badge,
    required this.index,
  });

  final PublicProduct product;
  final double width;
  final _ProductBadge badge;
  final int index;

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return SizedBox(
          width: widget.width,
          child: V2Tilt3DCard(
            borderRadius: 20,
            maxTilt: 0.08,
            hoverLift: 4,
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
            onTap: () => context.go('/product/${p.slug}'),
            child: MouseRegion(
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(19),
                          ),
                          child: StoreProductImage(
                            product: p,
                            slotId: 'store_grid',
                            fit: BoxFit.cover,
                            backgroundColor: const Color(0xFFF5F5F7),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _EditorialTag(
                            label: switch (widget.badge) {
                              _ProductBadge.deal when p.hasDiscount =>
                                '${p.discountPercent}% off',
                              _ProductBadge.deal => 'On offer',
                              _ProductBadge.newLaunch => 'Just in',
                            },
                            color: switch (widget.badge) {
                              _ProductBadge.deal => V2Colors.emberDeep,
                              _ProductBadge.newLaunch => V2Colors.aurora,
                            },
                            background: switch (widget.badge) {
                              _ProductBadge.deal => V2Colors.emberSubtle,
                              _ProductBadge.newLaunch => V2Colors.auroraSubtle,
                            },
                          ),
                        ),
                        if (_hover)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _QuickAddButton(product: p),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((p.brandName ?? '').isNotEmpty)
                          Text(
                            p.brandName!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V2FontStyles.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: V2Colors.inkMutedSaaS,
                            ),
                          ),
                        if ((p.brandName ?? '').isNotEmpty)
                          const SizedBox(height: 3),
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: V2FontStyles.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: -0.25,
                            color: V2Colors.inkSaaS,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              p.price != null
                                  ? formatINR(p.price)
                                  : 'Request quote',
                              style: V2FontStyles.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: p.price != null
                                    ? V2Colors.inkSaaS
                                    : V2Colors.plasma,
                              ),
                            ),
                            if (p.hasDiscount && p.mrp != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                formatINR(p.mrp),
                                style: V2FontStyles.inter(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: V2Colors.inkMutedSaaS,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: (60 + widget.index * 50).ms)
        .fadeIn(duration: 450.ms)
        .slideX(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.product});
  final PublicProduct product;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: V2Colors.inkSaaS,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          PublicCart.instance.addProduct(product);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${product.name}" to cart'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.add_shopping_cart_rounded,
            size: 16,
            color: Colors.white,
          ),
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
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: V2Colors.inkSaaS),
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
    final w = v.r<double>(xs: 168, md: 196);
    return SizedBox(
      height: v.r<double>(xs: 268, md: 280),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) =>
            Container(
                  width: w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: V2Colors.borderSubtle),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1400.ms, color: V2Colors.bgSubtle),
      ),
    );
  }
}

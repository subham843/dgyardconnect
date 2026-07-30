// Category landing — products for one category, or Coming Soon when empty.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/seo/public_seo_registry.dart';
import '../../../../core/seo/web_seo_binder.dart';
import '../../../../core/seo/web_seo_meta.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/v2_text.dart';
import '../../data/models/public_store_models.dart';
import '../../data/repositories/public_store_repository.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';
import '../../v2/widgets/v2_page_container.dart';
import 'widgets/placed_store_image.dart';
import 'widgets/public_image_slots.dart';
import 'widgets/store_filters.dart';
import 'widgets/store_product_card.dart';

class StoreCategoryPage extends StatefulWidget {
  const StoreCategoryPage({super.key, required this.categorySlug});

  final String categorySlug;

  @override
  State<StoreCategoryPage> createState() => _StoreCategoryPageState();
}

class _StoreCategoryPageState extends State<StoreCategoryPage> {
  final _repo = PublicStoreRepository();
  final _scroll = ScrollController();

  PublicCategory? _category;
  List<PublicProduct> _products = const [];
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final catalog = await _repo.loadCatalog();
      if (!mounted) return;
      final category = catalog.categories
          .where((c) => c.slug == widget.categorySlug)
          .firstOrNull;
      if (category == null) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      final engine = StoreQueryEngine(catalog);
      final products = engine.apply(StoreFilters(categoryId: category.id));
      setState(() {
        _category = category;
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openProduct(PublicProduct p) => context.go('/product/${p.slug}');

  WebSeoMeta _seoMeta() {
    final path = RouteNames.publicStoreCategory(widget.categorySlug);
    if (!_loading && _notFound) {
      return PublicSeoRegistry.softNotFound(
        title: 'Category not found',
        path: path,
      );
    }
    if (_category != null) {
      return PublicSeoRegistry.storeCategory(
        widget.categorySlug,
        name: _category!.name,
        description: _category!.safeDescription,
        image: _category!.imageUrl,
      );
    }
    return PublicSeoRegistry.store();
  }

  @override
  Widget build(BuildContext context) {
    return WebSeoScope(
      meta: _seoMeta(),
      child: Scaffold(
      backgroundColor: V2Colors.surface,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_notFound)
            _buildNotFound(context)
          else
            SingleChildScrollView(
              controller: _scroll,
              child: _products.isEmpty
                  ? _buildComingSoon(context)
                  : _buildProducts(context),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: V2Responsive(context).r(xs: 16, lg: 24)),
        Expanded(
          child: Center(
            child: _StatusPanel(
              icon: Icons.category_outlined,
              title: 'Category not found',
              subtitle: 'This category may have been removed or renamed.',
              primaryLabel: 'Back to shop home',
              onPrimary: () => context.go(RouteNames.publicStore),
              secondaryLabel: 'Go to homepage',
              onSecondary: () => context.go(RouteNames.publicHome),
            ),
          ),
        ),
        const V2Footer(),
        SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
      ],
    );
  }

  Widget _buildComingSoon(BuildContext context) {
    final c = _category!;
    final v = V2Responsive(context);

    return Column(
      children: [
        _categoryHero(c, v, productCount: 0),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: v.r(xs: V2.s6, lg: V2.s12),
            vertical: V2.s24,
          ),
          child: _StatusPanel(
            icon: Icons.hourglass_top_rounded,
            title: 'Coming soon',
            subtitle:
                '${c.name} products are on the way. Check back shortly or explore other categories in our store.',
            primaryLabel: 'Back to shop home',
            onPrimary: () => context.go(RouteNames.publicStore),
            secondaryLabel: 'Browse all categories',
            onSecondary: () => context.go(RouteNames.publicStore),
          ),
        ),
        const V2Footer(),
        SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
      ],
    );
  }

  Widget _buildProducts(BuildContext context) {
    final c = _category!;
    final v = V2Responsive(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _categoryHero(c, v, productCount: _products.length),
        V2PageContainer(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              v.r(xs: V2.s6, lg: V2.s8),
              V2.s8,
              v.r(xs: V2.s6, lg: V2.s8),
              V2.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _breadcrumb(c),
                const SizedBox(height: V2.s4),
                Text(
                  '${_products.length} ${_products.length == 1 ? 'product' : 'products'}',
                  style: V2Text.body().copyWith(color: V2Colors.fgMuted),
                ),
                const SizedBox(height: V2.s8),
                _productGrid(_products),
              ],
            ),
          ),
        ),
        const V2Footer(),
        SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
      ],
    );
  }

  Widget _categoryHero(PublicCategory c, V2Responsive v, {required int productCount}) {
    final height = v.r(xs: 220.0, md: 280.0, lg: 320.0);
    return SizedBox(
      height: height + v.r(xs: 72, lg: 88),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: v.r(xs: 72, lg: 88),
            left: 0,
            right: 0,
            height: height,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(V2.r2xl)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlacedStoreImage(
                    slotId: 'category_banner',
                    preset: PublicStoreImagePreset.category,
                    fallbackUrl: c.imageUrl,
                    sourceUrl: c.imageEditorSourceUrl,
                    placements: c.imagePlacements,
                    sourceW: c.imageSourceW,
                    sourceH: c.imageSourceH,
                    fallbackIcon: Icons.category_outlined,
                    backgroundColor: V2Colors.ink,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: v.r(xs: V2.s6, lg: V2.s12),
                    right: v.r(xs: V2.s6, lg: V2.s12),
                    bottom: V2.s8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: v.r(
                            xs: V2Text.h3(context),
                            lg: V2Text.h2(context),
                          ).copyWith(
                            color: V2Colors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: V2.s2),
                        Text(
                          c.safeDescription,
                          style: V2Text.bodyLg(context).copyWith(
                            color: V2Colors.surface.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: V2.s2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: V2.s4,
                            vertical: V2.s1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(V2.rFull),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            productCount == 0
                                ? 'Coming soon'
                                : '$productCount ${productCount == 1 ? 'product' : 'products'}',
                            style: V2Text.smallStrong().copyWith(color: V2Colors.surface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumb(PublicCategory c) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Crumb('Home', () => context.go(RouteNames.publicHome)),
        const _CrumbSep(),
        _Crumb('Store', () => context.go(RouteNames.publicStore)),
        const _CrumbSep(),
        _Crumb(c.name, null, isLast: true),
      ],
    );
  }

  Widget _productGrid(List<PublicProduct> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 280).floor().clamp(1, 4);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: V2.s6,
            mainAxisSpacing: V2.s6,
            childAspectRatio: 0.62,
          ),
          itemCount: products.length,
          itemBuilder: (context, i) => StoreProductCard(
            product: products[i],
            onTap: () => _openProduct(products[i]),
            onQuickView: () => _openProduct(products[i]),
            onWishlist: () {},
            onCompare: () {},
          ).animate().fadeIn(duration: 350.ms, delay: ((i % 12) * 40).ms),
        );
      },
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(V2.s12),
        decoration: BoxDecoration(
          color: V2Colors.bgSubtle,
          borderRadius: BorderRadius.circular(V2.r2xl),
          border: Border.all(color: V2Colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 64, color: V2Colors.ember),
            const SizedBox(height: V2.s6),
            Text(title, textAlign: TextAlign.center, style: V2Text.h3(context)),
            const SizedBox(height: V2.s2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: V2Text.body().copyWith(color: V2Colors.fgMuted),
            ),
            const SizedBox(height: V2.s8),
            FilledButton.icon(
              onPressed: onPrimary,
              icon: const Icon(Icons.storefront_outlined),
              label: Text(primaryLabel),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: V2.s2),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CrumbSep extends StatelessWidget {
  const _CrumbSep();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.chevron_right_rounded, size: 16, color: V2Colors.fgSubtle),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb(this.label, this.onTap, {this.isLast = false});

  final String label;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = V2Text.smallStrong().copyWith(
      color: isLast ? V2Colors.ink : V2Colors.fgMuted,
      fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
    );
    if (onTap == null) return Text(label, style: style);
    return InkWell(
      onTap: onTap,
      child: Text(label, style: style.copyWith(decoration: TextDecoration.underline)),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
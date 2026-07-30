// Store — premium public ecommerce experience.
// Landing journey (hero → offers → categories → product rails → brands) and an
// integrated catalog mode (multi-level nav + sidebar filters + sort + search).
// 100% admin-driven: banners, offers, categories, brands, products all come
// from Supabase. No hardcoded store content.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_glass.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/v2_text.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';
import '../../v2/widgets/v2_brand_showcase.dart';
import '../../v2/widgets/v2_page_container.dart';
import '../../../shop/domain/brand_logo_layout.dart';
import '../../data/models/public_store_models.dart';
import '../../data/repositories/public_store_repository.dart';
import '../../state/public_cart.dart';
import 'widgets/store_atoms.dart';
import 'widgets/store_category_strip.dart';
import 'widgets/store_filter_panel.dart';
import 'widgets/store_filters.dart';
import 'widgets/store_hero.dart';
import 'widgets/store_product_card.dart';
import 'widgets/store_product_image.dart';
import 'widgets/store_search_bar.dart';

class StorePage extends StatefulWidget {
  const StorePage({
    super.key,
    this.categorySlug,
    this.subcategorySlug,
    this.brandSlug,
    this.initialQuery,
  });

  final String? categorySlug;
  final String? subcategorySlug;
  final String? brandSlug;
  final String? initialQuery;

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final _repository = PublicStoreRepository();
  final _scroll = ScrollController();

  StoreCatalog _catalog = StoreCatalog.empty();
  late StoreQueryEngine _engine = StoreQueryEngine(_catalog);
  StoreFilters _filters = StoreFilters();
  final List<String> _recentSearches = [];

  bool _loading = true;
  bool _browse = false;

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
      final catalog = await _repository.loadCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _engine = StoreQueryEngine(catalog);
        _loading = false;
        _applyDeepLink();
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyDeepLink() {
    String? categoryId;
    String? subId;
    if (widget.categorySlug != null) {
      categoryId = _catalog.categories
          .where((c) => c.slug == widget.categorySlug)
          .map((c) => c.id)
          .firstOrNull;
    }
    if (widget.subcategorySlug != null) {
      final sub = _catalog.subcategories
          .where((s) => s.slug == widget.subcategorySlug)
          .firstOrNull;
      subId = sub?.id;
      categoryId ??= sub?.categoryId;
    }
    final brandIds = <String>{};
    if (widget.brandSlug != null) {
      final b = _catalog.brands
          .where((b) => b.slug == widget.brandSlug)
          .firstOrNull;
      if (b != null) brandIds.add(b.id);
    }
    final query = widget.initialQuery?.trim() ?? '';

    if (categoryId != null ||
        subId != null ||
        brandIds.isNotEmpty ||
        query.isNotEmpty) {
      _filters = StoreFilters(
        categoryId: categoryId,
        subCategoryId: subId,
        brandIds: brandIds,
        query: query,
      );
      _browse = true;
    }
  }

  // --- Mutations -------------------------------------------------------------

  void _update(StoreFilters f) => setState(() => _filters = f);

  void _enterBrowse(StoreFilters f) {
    setState(() {
      _filters = f;
      _browse = true;
    });
    _scroll.hasClients
        ? _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          )
        : null;
  }

  void _exitBrowse() => setState(() {
    _browse = false;
    _filters = StoreFilters();
  });

  void _search(String query) {
    final q = query.trim();
    if (q.isNotEmpty) {
      _recentSearches.remove(q);
      _recentSearches.insert(0, q);
      if (_recentSearches.length > 6) _recentSearches.removeLast();
    }
    _enterBrowse(_filters.copyWith(query: q));
  }

  void _openProduct(PublicProduct p) => context.go('/product/${p.slug}');

  void _addToCart(PublicProduct p) {
    PublicCart.instance.addProduct(p);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.name} added to cart'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: V2Colors.ink,
        action: SnackBarAction(
          label: 'View cart',
          textColor: V2Colors.ember,
          onPressed: () => context.go('/store/cart'),
        ),
      ),
    );
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V2Colors.surface,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              controller: _scroll,
              child: _browse ? _buildCatalog(context) : _buildLanding(context),
            ),
        ],
      ),
    );
  }

  // --- Landing ---------------------------------------------------------------

  Widget _buildLanding(BuildContext context) {
    final v = V2Responsive(context);
    final featuredCats = _catalog.categories;
    final newArrivals = (_engine.apply(
      StoreFilters(sort: StoreSort.newest),
    )).take(10).toList();
    final deals = _catalog.products.where((p) => p.hasDiscount).toList()
      ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    final featured = _catalog.products.take(10).toList();

    return Column(
      children: [
        StoreHeroSlider(
          banners: _catalog.banners,
          onBrowse: () => _enterBrowse(StoreFilters()),
        ),

        // Floating search command bar (overlaps hero for depth).
        Transform.translate(
          offset: const Offset(0, -40),
          child: V2PageContainer(maxWidth: V2.maxMedium, child: _searchCard(v)),
        ),

        if (_catalog.offers.isNotEmpty)
          _section(
            background: V2Colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StoreSectionHeader(
                  title: 'Limited-time offers',
                  subtitle: 'Live festival, flash & bundle deals from our team',
                ),
                const SizedBox(height: V2.s6),
                StoreOffersStrip(
                  offers: _catalog.offers,
                  onOfferTap: _onOfferTap,
                ),
              ],
            ),
          ),

        if (featuredCats.isNotEmpty)
          _section(
            background: V2Colors.bgSubtle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StoreSectionHeader(
                  title: 'Shop by category',
                  subtitle: 'Curated collections across security & IT',
                  actionLabel: 'Browse all',
                  onAction: () => _enterBrowse(StoreFilters()),
                ),
                const SizedBox(height: V2.s6),
                StoreCategoryStrip(
                  categories: featuredCats,
                  onCategoryTap: (c) =>
                      context.go(RouteNames.publicStoreCategory(c.slug)),
                ),
              ],
            ),
          ),

        if (newArrivals.isNotEmpty)
          _section(
            background: V2Colors.surface,
            child: _productRail(
              'New arrivals',
              'The latest additions to the catalog',
              newArrivals,
              isNew: true,
              onViewAll: () =>
                  _enterBrowse(StoreFilters(sort: StoreSort.newest)),
            ),
          ),

        if (deals.isNotEmpty)
          _section(
            background: V2Colors.bgSubtle,
            child: _productRail(
              'Best deals',
              'Biggest savings, while stocks last',
              deals.take(10).toList(),
              onViewAll: () =>
                  _enterBrowse(StoreFilters(sort: StoreSort.discount)),
            ),
          ),

        if (featured.isNotEmpty)
          _section(
            background: V2Colors.surface,
            child: _productRail(
              'Featured products',
              'Hand-picked for modern projects',
              featured,
              onViewAll: () => _enterBrowse(StoreFilters()),
            ),
          ),

        if (_catalog.brands.isNotEmpty)
          _section(
            background: V2Colors.bgSubtle,
            child: V2BrandShowcase(
              brands: _catalog.brands,
              title: 'Shop by brand',
              subtitle: 'Swipe to explore trusted manufacturers',
              horizontalScroll: true,
              canvasPreset: BrandLogoCanvasPreset.storeCarouselTablet,
              mobileCanvasPreset: BrandLogoCanvasPreset.storeCarouselMobile,
            ),
          ),

        _qualityBand(v),
        const V2Footer(),
        SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
      ],
    );
  }

  Widget _searchCard(V2Responsive v) {
    return Container(
      padding: EdgeInsets.all(v.r(xs: V2.s4, lg: V2.s6)),
      decoration: BoxDecoration(
        color: V2Colors.surface,
        borderRadius: BorderRadius.circular(V2.r2xl),
        border: Border.all(color: V2Colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          StoreSearchBar(
            suggestionProvider: _suggestions,
            onSubmit: _search,
            recentSearches: _recentSearches,
            popularSearches: _popularSearches(),
          ),
          const SizedBox(height: V2.s4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickChip(
                  'All products',
                  Icons.grid_view_rounded,
                  () => _enterBrowse(StoreFilters()),
                ),
                for (final c in _catalog.categories.take(8))
                  _quickChip(
                    c.name,
                    Icons.chevron_right_rounded,
                    () => _enterBrowse(StoreFilters(categoryId: c.id)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: V2.s2),
      child: _HoverChip(label: label, icon: icon, onTap: onTap),
    );
  }

  Widget _productRail(
    String title,
    String subtitle,
    List<PublicProduct> products, {
    bool isNew = false,
    VoidCallback? onViewAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreSectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: 'View all',
          onAction: onViewAll,
        ),
        const SizedBox(height: V2.s6),
        SizedBox(
          height: 430,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: V2.s6),
            itemBuilder: (context, i) => SizedBox(
              width: 270,
              child: StoreProductCard(
                product: products[i],
                isNew: isNew,
                onTap: () => _openProduct(products[i]),
                onQuickView: () => _quickView(products[i]),
                onWishlist: () => _toast('Saved to wishlist — sign in to sync'),
                onCompare: () => _toast('Added to compare'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _qualityBand(V2Responsive v) {
    final items = [
      (
        Icons.verified_user_outlined,
        'Authentic products',
        'Sourced direct from brands',
      ),
      (
        Icons.local_shipping_outlined,
        'Pan-India delivery',
        'Fast, tracked dispatch',
      ),
      (
        Icons.support_agent_outlined,
        'Expert support',
        'Pre & post-sales guidance',
      ),
      (
        Icons.workspace_premium_outlined,
        'Warranty assured',
        'Genuine manufacturer cover',
      ),
    ];
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: V2Colors.heroGradient),
      padding: EdgeInsets.symmetric(
        vertical: v.r(xs: V2.s12, lg: V2.s16),
      ),
      child: V2PageContainer(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: V2.s8,
          runSpacing: V2.s8,
          children: [
            for (final it in items)
              SizedBox(
                width: v.r(xs: 260, lg: 250),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: V2Colors.ember.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(V2.rLg),
                      ),
                      child: Icon(it.$1, color: V2Colors.ember),
                    ),
                    const SizedBox(width: V2.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.$2,
                            style: V2Text.bodyEmph().copyWith(
                              color: V2Colors.surface,
                            ),
                          ),
                          Text(
                            it.$3,
                            style: V2Text.small().copyWith(
                              color: V2Colors.surface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Catalog ---------------------------------------------------------------

  Widget _buildCatalog(BuildContext context) {
    final v = V2Responsive(context);
    final results = _engine.apply(_filters);
    final showSidebar = v.isDesktop;

    return ColoredBox(
      color: const Color(0xFFF5F5F7),
      child: Column(
        children: [
          SizedBox(height: v.r(xs: 12, lg: 16)),
          V2PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _catalogHeader(),
                const SizedBox(height: V2.s6),
                _toolbar(v, results.length, showSidebar),
                const SizedBox(height: V2.s6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSidebar) ...[
                      SizedBox(
                        width: 300,
                        child: _FloatingFilterShell(
                          child: StoreFilterPanel(
                            catalog: _catalog,
                            engine: _engine,
                            filters: _filters,
                            onChanged: _update,
                            onClear: () => _update(
                              StoreFilters(
                                categoryId: _filters.categoryId,
                                subCategoryId: _filters.subCategoryId,
                                query: _filters.query,
                                sort: _filters.sort,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: V2.s8),
                    ],
                    Expanded(
                      child: results.isEmpty
                          ? _emptyState()
                          : _resultsGrid(results),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: V2.s16),
          const V2Footer(),
        SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
        ],
      ),
    );
  }

  Widget _catalogHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: v2BlurLayer(
        sigma: 18,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(V2.s8),
          decoration: BoxDecoration(
            color: V2Colors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: V2Colors.surface.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.65),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _breadcrumb(),
              const SizedBox(height: V2.s4),
              Text(
                _catalogTitle(),
                style: V2Text.h2(
                  context,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.2),
              ),
              const SizedBox(height: V2.s2),
              Text(
                'Find the right products faster with category, brand, price and attribute filters.',
                style: V2Text.body().copyWith(color: V2Colors.fgMuted),
              ),
              const SizedBox(height: V2.s6),
              StoreSearchBar(
                suggestionProvider: _suggestions,
                onSubmit: _search,
                recentSearches: _recentSearches,
                popularSearches: _popularSearches(),
                initialQuery: _filters.query,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _breadcrumb() {
    final crumbs = <(String, VoidCallback?)>[
      ('Home', () => context.go('/')),
      ('Store', _exitBrowse),
    ];
    final cat = _filters.categoryId == null
        ? null
        : _catalog.categories
              .where((c) => c.id == _filters.categoryId)
              .firstOrNull;
    if (cat != null) {
      crumbs.add((
        cat.name,
        () => _update(_filters.copyWith(subCategoryId: null)),
      ));
    }
    final sub = _filters.subCategoryId == null
        ? null
        : _catalog.subcategories
              .where((s) => s.id == _filters.subCategoryId)
              .firstOrNull;
    if (sub != null) crumbs.add((sub.name, null));

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: V2Colors.fgSubtle,
              ),
            ),
          _BreadcrumbLink(
            label: crumbs[i].$1,
            onTap: crumbs[i].$2,
            isLast: i == crumbs.length - 1,
          ),
        ],
      ],
    );
  }

  String _catalogTitle() {
    if (_filters.query.trim().isNotEmpty) {
      return 'Results for "${_filters.query.trim()}"';
    }
    if (_filters.subCategoryId != null) {
      return _catalog.subcategories
              .where((s) => s.id == _filters.subCategoryId)
              .map((s) => s.name)
              .firstOrNull ??
          'Products';
    }
    if (_filters.categoryId != null) {
      return _catalog.categories
              .where((c) => c.id == _filters.categoryId)
              .map((c) => c.name)
              .firstOrNull ??
          'Products';
    }
    return 'All products';
  }

  Widget _toolbar(V2Responsive v, int count, bool showSidebar) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: V2Colors.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(color: V2Colors.border),
          ),
          child: Text(
            '$count ${count == 1 ? 'product' : 'products'}',
            style: V2Text.smallStrong().copyWith(
              color: V2Colors.fgMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        if (!showSidebar)
          OutlinedButton.icon(
            onPressed: _openFilterSheet,
            icon: Badge(
              isLabelVisible: _filters.activeRefinementCount > 0,
              label: Text('${_filters.activeRefinementCount}'),
              child: const Icon(Icons.tune_rounded, size: 18),
            ),
            label: const Text('Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: V2Colors.plasma,
              side: const BorderSide(color: V2Colors.border),
            ),
          ),
        const SizedBox(width: V2.s2),
        _sortDropdown(),
      ],
    );
  }

  Widget _sortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: V2.s4),
      decoration: BoxDecoration(
        color: V2Colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: V2Colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StoreSort>(
          value: _filters.sort,
          icon: const Icon(Icons.expand_more_rounded),
          borderRadius: BorderRadius.circular(V2.rLg),
          style: V2Text.smallStrong().copyWith(color: V2Colors.ink),
          items: [
            for (final s in StoreSort.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (v) =>
              v == null ? null : _update(_filters.copyWith(sort: v)),
        ),
      ),
    );
  }

  Widget _resultsGrid(List<PublicProduct> results) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 248).floor().clamp(1, 4);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: V2.s4,
            mainAxisSpacing: V2.s4,
            childAspectRatio: 0.68,
          ),
          itemCount: results.length,
          itemBuilder: (context, i) => StoreProductCard(
            product: results[i],
            onTap: () => _openProduct(results[i]),
            onQuickView: () => _quickView(results[i]),
            onWishlist: () => _toast('Saved to wishlist — sign in to sync'),
            onCompare: () => _toast('Added to compare'),
          ).animate().fadeIn(duration: 350.ms, delay: ((i % 12) * 40).ms),
        );
      },
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: V2.s24),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 72,
            color: V2Colors.fgFaint,
          ),
          const SizedBox(height: V2.s6),
          Text('No products match your filters', style: V2Text.h3(context)),
          const SizedBox(height: V2.s2),
          Text(
            'Try clearing some refinements or searching differently.',
            style: V2Text.body(),
          ),
          const SizedBox(height: V2.s6),
          TextButton(
            onPressed: () => _update(StoreFilters(query: _filters.query)),
            child: const Text('Reset filters'),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, controller) => Container(
            decoration: const BoxDecoration(
              color: V2Colors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(V2.r2xl),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: V2.s2),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: V2Colors.fgFaint,
                    borderRadius: BorderRadius.circular(V2.rFull),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.all(V2.s4),
                    child: StoreFilterPanel(
                      catalog: _catalog,
                      engine: _engine,
                      filters: _filters,
                      onChanged: (f) {
                        _update(f);
                        setSheet(() {});
                      },
                      onClear: () {
                        final cleared = StoreFilters(
                          categoryId: _filters.categoryId,
                          subCategoryId: _filters.subCategoryId,
                          query: _filters.query,
                          sort: _filters.sort,
                        );
                        _update(cleared);
                        setSheet(() {});
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(V2.s4),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: V2Colors.ember,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Show results'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Offers / quick view ---------------------------------------------------

  void _onOfferTap(PublicOffer offer) {
    if (offer.subcategoryId != null) {
      _enterBrowse(
        StoreFilters(
          subCategoryId: offer.subcategoryId,
          categoryId: _catalog.subcategories
              .where((s) => s.id == offer.subcategoryId)
              .map((s) => s.categoryId)
              .firstOrNull,
          sort: StoreSort.discount,
        ),
      );
    } else if (offer.categoryId != null) {
      _enterBrowse(
        StoreFilters(categoryId: offer.categoryId, sort: StoreSort.discount),
      );
    } else {
      _enterBrowse(StoreFilters(sort: StoreSort.discount));
    }
  }

  void _quickView(PublicProduct p) {
    final isMobile = V2Responsive(context).isMobile;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: V2Colors.surface,
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? V2.s4 : V2.s12,
          vertical: V2.s8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V2.r2xl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 560),
          child: _QuickViewBody(
            product: p,
            onViewDetails: () {
              Navigator.pop(dialogContext);
              _openProduct(p);
            },
            onAddToCart: () {
              Navigator.pop(dialogContext);
              _addToCart(p);
            },
          ),
        ),
      ),
    );
  }

  // --- Search helpers --------------------------------------------------------

  List<StoreSuggestion> _suggestions(String query) {
    final q = query.toLowerCase();
    final out = <StoreSuggestion>[];

    for (final c
        in _catalog.categories
            .where((c) => c.name.toLowerCase().contains(q))
            .take(3)) {
      out.add(
        StoreSuggestion(
          label: c.name,
          sublabel: 'Category · ${c.productCount} products',
          kind: StoreSuggestionKind.category,
          onTap: () => _enterBrowse(StoreFilters(categoryId: c.id)),
        ),
      );
    }
    for (final b
        in _catalog.brands
            .where((b) => b.name.toLowerCase().contains(q))
            .take(3)) {
      out.add(
        StoreSuggestion(
          label: b.name,
          sublabel: 'Brand',
          kind: StoreSuggestionKind.brand,
          onTap: () => _enterBrowse(StoreFilters(brandIds: {b.id})),
        ),
      );
    }
    for (final p
        in _catalog.products
            .where((p) {
              return p.name.toLowerCase().contains(q) ||
                  (p.sku ?? '').toLowerCase().contains(q) ||
                  (p.brandName ?? '').toLowerCase().contains(q);
            })
            .take(6)) {
      out.add(
        StoreSuggestion(
          label: p.name,
          sublabel: [p.brandName, p.sku].whereType<String>().join(' · '),
          kind: StoreSuggestionKind.product,
          onTap: () => _openProduct(p),
        ),
      );
    }
    return out;
  }

  List<String> _popularSearches() {
    final terms = <String>[];
    for (final c in _catalog.categories.take(3)) {
      terms.add(c.name);
    }
    for (final b in _catalog.brands.take(3)) {
      terms.add(b.name);
    }
    return terms;
  }

  // --- Misc ------------------------------------------------------------------

  Widget _section({required Widget child, required Color background}) {
    final v = V2Responsive(context);
    return Container(
      width: double.infinity,
      color: background,
      padding: EdgeInsets.symmetric(
        vertical: v.r(xs: V2.s12, lg: V2.s16),
      ),
      child: V2PageContainer(child: child),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: V2Colors.ink,
      ),
    );
  }
}

// --- Small widgets -----------------------------------------------------------

class _FloatingFilterShell extends StatelessWidget {
  const _FloatingFilterShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: v2BlurLayer(sigma: 16, child: child),
      ),
    ).animate().fadeIn(duration: 420.ms).slideX(begin: -0.04, end: 0);
  }
}

class _HoverChip extends StatefulWidget {
  const _HoverChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? V2Colors.ink : V2Colors.bgSubtle,
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(color: _hover ? V2Colors.ink : V2Colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: V2Text.smallStrong().copyWith(
                  color: _hover ? V2Colors.surface : V2Colors.fgMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                widget.icon,
                size: 16,
                color: _hover ? V2Colors.ember : V2Colors.fgSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbLink extends StatelessWidget {
  const _BreadcrumbLink({required this.label, this.onTap, this.isLast = false});
  final String label;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = V2Text.smallStrong().copyWith(
      color: isLast ? V2Colors.ink : V2Colors.fgSubtle,
      fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
    );
    if (onTap == null) return Text(label, style: style);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: style),
      ),
    );
  }
}

class _QuickViewBody extends StatelessWidget {
  const _QuickViewBody({
    required this.product,
    required this.onViewDetails,
    required this.onAddToCart,
  });
  final PublicProduct product;
  final VoidCallback onViewDetails;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final isMobile = V2Responsive(context).isMobile;
    final content = isMobile
        ? Column(
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: StoreProductImage(
                  product: product,
                  slotId: 'quick_view',
                  fit: BoxFit.cover,
                  backgroundColor: V2Colors.bgSubtle,
                ),
              ),
              Expanded(child: SingleChildScrollView(child: _info(context))),
            ],
          )
        : SizedBox(
            height: 460,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: StoreProductImage(
                    product: product,
                    slotId: 'quick_view',
                    fit: BoxFit.cover,
                    backgroundColor: V2Colors.bgSubtle,
                  ),
                ),
                const VerticalDivider(width: 1, color: V2Colors.border),
                Expanded(child: SingleChildScrollView(child: _info(context))),
              ],
            ),
          );

    return Stack(
      children: [
        content,
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _info(BuildContext context) {
    final desc = product.shortDescription ?? product.description;
    return Padding(
      padding: const EdgeInsets.all(V2.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((product.brandName ?? '').isNotEmpty)
            Text(
              product.brandName!.toUpperCase(),
              style: V2Text.micro().copyWith(color: V2Colors.ember),
            ),
          const SizedBox(height: 6),
          Text(product.name, style: V2Text.h3(context)),
          const SizedBox(height: V2.s4),
          if (product.price != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatINR(product.price),
                  style: V2Text.h3(context).copyWith(color: V2Colors.ink),
                ),
                if (product.hasDiscount) ...[
                  const SizedBox(width: 10),
                  Text(
                    formatINR(product.mrp),
                    style: V2Text.body().copyWith(
                      color: V2Colors.fgSubtle,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StorePill(
                    label: '-${product.discountPercent}%',
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ],
            ),
          const SizedBox(height: V2.s4),
          if (desc != null && desc.trim().isNotEmpty)
            Text(
              desc,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: V2Text.body(),
            ),
          const SizedBox(height: V2.s8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: V2Colors.ember,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onAddToCart,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('Add to Cart'),
                ),
              ),
              const SizedBox(width: V2.s2),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: V2Colors.plasma,
                    side: const BorderSide(color: V2Colors.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iter = iterator;
    return iter.moveNext() ? iter.current : null;
  }
}
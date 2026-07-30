import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../data/marketplace_catalog_repository.dart';
import '../data/marketplace_taxonomy_repository.dart';
import '../domain/marketplace_catalog_product.dart';
import '../state/marketplace_cart_controller.dart';
import 'widgets/marketplace_premium_shell.dart';
import 'widgets/marketplace_product_card.dart';
import 'widgets/marketplace_amazon_header.dart';
import '../../../shared/widgets/glass_container.dart';
import 'package:google_fonts/google_fonts.dart';

enum _MarketplaceHomeSort {
  bestOffers,
  lowestPrice,
  latest,
}

/// Buyer-facing marketplace hub — D.G.Yard branding only (no seller identity).
class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  StreamSubscription<User?>? _authSub;
  final _homeSearchController = TextEditingController();
  String _homeSearchQuery = '';
  bool _inStockOnly = false;
  _MarketplaceHomeSort _sort = _MarketplaceHomeSort.bestOffers;
  int _priceBand = 0; // 0=All, 1=<₹1,000, 2=₹1,000-₹5,000, 3=₹5,000+

  static const int _priceBand1000Paise = 1000 * 100;
  static const int _priceBand5000Paise = 5000 * 100;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _homeSearchController.dispose();
    super.dispose();
  }

  int _sortToIndex(_MarketplaceHomeSort s) {
    switch (s) {
      case _MarketplaceHomeSort.lowestPrice:
        return 1;
      case _MarketplaceHomeSort.latest:
        return 2;
      case _MarketplaceHomeSort.bestOffers:
        return 0;
    }
  }

  _MarketplaceHomeSort _indexToSort(int i) {
    switch (i) {
      case 1:
        return _MarketplaceHomeSort.lowestPrice;
      case 2:
        return _MarketplaceHomeSort.latest;
      case 0:
        return _MarketplaceHomeSort.bestOffers;
      default:
        return _MarketplaceHomeSort.bestOffers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<MarketplaceCartController>();
    final viewerUid = FirebaseAuth.instance.currentUser?.uid;
    final productStream = MarketplaceCatalogRepository().watchLiveProducts(excludeSellerUid: viewerUid);
    final canPop = Navigator.of(context).canPop();

    return MarketplacePremiumShell(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 76,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: canPop ? () => context.pop() : null,
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'D.G.Yard Supply',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Professional B2B Marketplace',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.82),
                        const Color(0xFFEFF6FF).withValues(alpha: 0.62),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => context.push(RouteNames.marketplaceSearch),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount > 99 ? '99+' : cart.itemCount}'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                onPressed: () => context.push(RouteNames.marketplaceCart),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: _HeroSection(theme: theme),
            ),
          ),
          SliverToBoxAdapter(
            child: MarketplaceAmazonHeader(
              searchController: _homeSearchController,
              searchQuery: _homeSearchQuery,
              onQueryChanged: (q) => setState(() => _homeSearchQuery = q),
              inStockOnly: _inStockOnly,
              onInStockOnlyChanged: (v) => setState(() => _inStockOnly = v),
              priceBand: _priceBand,
              onPriceBandChanged: (v) => setState(() => _priceBand = v),
              sortIndex: _sortToIndex(_sort),
              onSortIndexChanged: (v) => setState(() => _sort = _indexToSort(v)),
              categoriesStream: MarketplaceTaxonomyRepository().watchCategories(activeOnly: true),
            ),
          ),
          StreamBuilder<List<MarketplaceCatalogProduct>>(
            stream: productStream,
            builder: (context, snap) {
              if (snap.hasError || !snap.hasData) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              final products = _applyHomeFiltersAndSort(snap.data!);
              final bestOffers = products.where((p) => p.offerActive).toList(growable: false);
              final best = bestOffers.take(10).toList(growable: false);
              if (best.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best Offers',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 250,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: best.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => SizedBox(
                            width: 180,
                            height: 250,
                            child: MarketplaceProductCard(product: best[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          StreamBuilder<List<MarketplaceCatalogProduct>>(
            stream: productStream,
            builder: (context, snap) {
              if (snap.hasError || !snap.hasData) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              final products = _applyHomeFiltersAndSort(snap.data!);
              final featured = products.take(10).toList(growable: false);
              if (featured.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Featured Buys',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 250,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: featured.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => SizedBox(
                            width: 180,
                            height: 250,
                            child: MarketplaceProductCard(product: featured[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          StreamBuilder(
            stream: productStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Unable to load catalog. ${snap.error}', style: const TextStyle(color: AppColors.error)),
                  ),
                );
              }
              if (!snap.hasData) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              var products = snap.data!;
              products = _applyHomeFiltersAndSort(products);
              if (products.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _EmptyCatalog(onSell: () => context.push(RouteNames.marketplaceSellerHub)),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.58,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => MarketplaceProductCard(product: products[i]),
                    childCount: products.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<MarketplaceCatalogProduct> _applyHomeFiltersAndSort(List<MarketplaceCatalogProduct> products) {
    final q = _homeSearchQuery.trim().toLowerCase();
    var out = products.where((p) {
      if (_inStockOnly && p.isOutOfStock) return false;
      if (q.isNotEmpty) {
        final title = p.title.toLowerCase();
        final desc = p.description.toLowerCase();
        final cat = p.categoryName.toLowerCase();
        final sub = p.subcategoryName.toLowerCase();
        if (!(title.contains(q) || desc.contains(q) || cat.contains(q) || sub.contains(q))) return false;
      }
      final unitAtMoq = p.effectiveUnitPaiseForQuantity(p.moq);
      if (_priceBand == 1) return unitAtMoq < _priceBand1000Paise;
      if (_priceBand == 2) return unitAtMoq >= _priceBand1000Paise && unitAtMoq < _priceBand5000Paise;
      if (_priceBand == 3) return unitAtMoq >= _priceBand5000Paise;
      return true;
    }).toList(growable: false);

    int startingPrice(MarketplaceCatalogProduct p) => p.effectiveUnitPaiseForQuantity(p.moq);

    out.sort((a, b) {
      switch (_sort) {
        case _MarketplaceHomeSort.latest:
          final da = a.updatedAt?.millisecondsSinceEpoch ?? 0;
          final db = b.updatedAt?.millisecondsSinceEpoch ?? 0;
          final timeCmp = db.compareTo(da);
          if (timeCmp != 0) return timeCmp;
          return startingPrice(a).compareTo(startingPrice(b));
        case _MarketplaceHomeSort.lowestPrice:
          return startingPrice(a).compareTo(startingPrice(b));
        case _MarketplaceHomeSort.bestOffers:
          // Interim "best offers" (until offer fields are wired): lowest starting price wins.
          return startingPrice(a).compareTo(startingPrice(b));
      }
    });

    return out;
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 26,
      blurSigma: 18,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buy Smarter For Your Business',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Curated catalog, transparent pricing, and D.G.Yard fulfillment—built for B2B teams.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.10),
                  const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line('Trusted B2B Supply Platform'),
                const SizedBox(height: 6),
                _line('Quality Products at Competitive Prices'),
                const SizedBox(height: 6),
                _line('Fast & Reliable Fulfillment'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String text) {
    return Row(
      children: [
        Icon(Icons.verified_rounded, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onSell});

  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.inventory, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(
          'Catalog is being curated',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Approved products will appear here. Sellers can submit listings for admin review.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onSell, child: const Text('Seller workspace')),
      ],
    );
  }
}

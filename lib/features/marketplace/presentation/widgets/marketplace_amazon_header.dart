import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../domain/marketplace_taxonomy.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/app_colors.dart';

/// Amazon-like pinned header for marketplace Home.
///
/// Includes:
/// - Search (title/description/category)
/// - Quick filters chips (in-stock + price bands)
/// - Sort dropdown
/// - Category chips row
class MarketplaceAmazonHeader extends StatelessWidget {
  const MarketplaceAmazonHeader({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onQueryChanged,
    required this.inStockOnly,
    required this.onInStockOnlyChanged,
    required this.priceBand,
    required this.onPriceBandChanged,
    required this.sortIndex,
    required this.onSortIndexChanged,
    required this.categoriesStream,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final void Function(String) onQueryChanged;

  final bool inStockOnly;
  final void Function(bool) onInStockOnlyChanged;

  /// 0=All, 1=<₹1,000, 2=₹1,000–₹5,000, 3=₹5,000+
  final int priceBand;
  final void Function(int) onPriceBandChanged;

  /// 0=bestOffers, 1=lowestPrice, 2=latest
  final int sortIndex;
  final void Function(int) onSortIndexChanged;

  final Stream<List<MarketplaceCategoryNode>> categoriesStream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search row.
              TextField(
                controller: searchController,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => onQueryChanged(''),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Category chips.
              SizedBox(
                height: 38,
                child: StreamBuilder<List<MarketplaceCategoryNode>>(
                  stream: categoriesStream,
                  builder: (context, snap) {
                    final cats = snap.data ?? [];
                    if (cats.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Row(
                      children: [
                        Text(
                          'Category',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: cats.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final c = cats[i];
                              return ActionChip(
                                label: Text(c.name),
                                onPressed: () => context.push(RouteNames.marketplaceCategory(c.id)),
                                backgroundColor: Colors.white.withValues(alpha: 0.95),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Filter icon row (opens bottom sheet).
              SizedBox(
                height: 40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (sheetContext) {
                            return _FilterSheet(
                              inStockOnly: inStockOnly,
                              priceBand: priceBand,
                              sortIndex: sortIndex,
                              onInStockOnlyChanged: onInStockOnlyChanged,
                              onPriceBandChanged: onPriceBandChanged,
                              onSortIndexChanged: onSortIndexChanged,
                            );
                          },
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.filter_alt_rounded, size: 20, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Filters',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black.withValues(alpha: 0.65),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.inStockOnly,
    required this.priceBand,
    required this.sortIndex,
    required this.onInStockOnlyChanged,
    required this.onPriceBandChanged,
    required this.onSortIndexChanged,
  });

  final bool inStockOnly;
  final int priceBand;
  final int sortIndex;

  final void Function(bool) onInStockOnlyChanged;
  final void Function(int) onPriceBandChanged;
  final void Function(int) onSortIndexChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Availability',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 8),
              FilterChip(
                label: const Text('In-stock only'),
                selected: inStockOnly,
                onSelected: (v) => onInStockOnlyChanged(v),
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
              ),
              const SizedBox(height: 14),
              Text(
                'Price range',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _sheetPriceChip(context, theme, 0, 'All prices'),
                  _sheetPriceChip(context, theme, 1, '<₹1,000'),
                  _sheetPriceChip(context, theme, 2, '₹1,000–₹5,000'),
                  _sheetPriceChip(context, theme, 3, '₹5,000+'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Sort',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _sheetSortChip(context, theme, 0, 'Best'),
                  _sheetSortChip(context, theme, 1, 'Low'),
                  _sheetSortChip(context, theme, 2, 'Latest'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetPriceChip(BuildContext context, ThemeData theme, int band, String label) {
    return FilterChip(
      label: Text(label),
      selected: priceBand == band,
      onSelected: (_) => onPriceBandChanged(band),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
    );
  }

  Widget _sheetSortChip(BuildContext context, ThemeData theme, int idx, String label) {
    return FilterChip(
      label: Text(label),
      selected: sortIndex == idx,
      onSelected: (_) => onSortIndexChanged(idx),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
    );
  }
}


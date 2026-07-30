import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_catalog_repository.dart';
import '../../marketplace/domain/marketplace_catalog_product.dart';
import '../../marketplace/presentation/marketplace_format.dart';
import '../../marketplace/presentation/widgets/marketplace_status_chip.dart';

/// All catalog SKUs (any status) — open row to edit or delete.
class AdminMarketplaceCatalogProductsScreen extends StatefulWidget {
  const AdminMarketplaceCatalogProductsScreen({super.key});

  @override
  State<AdminMarketplaceCatalogProductsScreen> createState() => _AdminMarketplaceCatalogProductsScreenState();
}

class _AdminMarketplaceCatalogProductsScreenState extends State<AdminMarketplaceCatalogProductsScreen> {
  final _repo = MarketplaceCatalogRepository();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MarketplaceCatalogProduct> _filter(List<MarketplaceCatalogProduct> raw) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return raw;
    return raw.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          p.categoryName.toLowerCase().contains(q) ||
          p.sellerUid.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'live':
        return 'Live';
      case 'out_of_stock':
        return 'Out of stock';
      case 'draft':
        return 'Draft';
      default:
        return s.replaceAll('_', ' ');
    }
  }

  MarketplaceChipTone _toneFor(String s) {
    switch (s) {
      case 'live':
        return MarketplaceChipTone.success;
      case 'out_of_stock':
        return MarketplaceChipTone.warning;
      case 'draft':
        return MarketplaceChipTone.neutral;
      default:
        return MarketplaceChipTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Catalog products')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search title, ID, category, seller UID',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MarketplaceCatalogProduct>>(
              stream: _repo.watchAllForAdmin(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = _filter(snap.data!);
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      snap.data!.isEmpty ? 'No catalog products yet.' : 'No matches.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(RouteNames.adminMarketplaceCatalogProductEdit(p.id)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      p.categoryName.isNotEmpty
                                          ? '${p.categoryName}${p.subcategoryName.isNotEmpty ? ' · ${p.subcategoryName}' : ''}'
                                          : p.categoryId,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      marketplaceFormatInr(p.pricePaise),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    if (p.sellerUid.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Seller: ${p.sellerUid}',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${p.id}',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.textSecondary.withValues(alpha: 0.85),
                                            fontFamily: 'monospace',
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              MarketplaceStatusChip(
                                label: _statusLabel(p.listingStatus),
                                tone: _toneFor(p.listingStatus),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

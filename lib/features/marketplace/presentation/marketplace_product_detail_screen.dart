import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../data/marketplace_catalog_repository.dart';
import '../state/marketplace_cart_controller.dart';
import '../domain/marketplace_catalog_product.dart';
import 'marketplace_format.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceProductDetailScreen extends StatefulWidget {
  const MarketplaceProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<MarketplaceProductDetailScreen> createState() => _MarketplaceProductDetailScreenState();
}

class _MarketplaceProductDetailScreenState extends State<MarketplaceProductDetailScreen> {
  final _repo = MarketplaceCatalogRepository();
  MarketplaceCatalogProduct? _product;
  bool _loading = true;
  String? _error;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final r = await _repo.loadProductForBuyer(widget.productId, uid);
      if (!mounted) return;
      setState(() {
        _product = r.product;
        _qty = r.product?.moq ?? 1;
        _loading = false;
        if (r.product != null) {
          _error = null;
        } else if (r.isOwnListing) {
          _error = 'This is your own listing. Manage it from the seller hub — you cannot buy your own product here.';
        } else {
          _error = 'Product unavailable';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyWidget = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : _product == null
                ? const SizedBox.shrink()
                : _Body(
                    product: _product!,
                    qty: _qty,
                    onQty: (q) => setState(() => _qty = q),
                    theme: theme,
                  );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Product')),
      body: Column(
        children: [
          Expanded(child: bodyWidget),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.product,
    required this.qty,
    required this.onQty,
    required this.theme,
  });

  final MarketplaceCatalogProduct product;
  final int qty;
  final ValueChanged<int> onQty;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<MarketplaceCartController>();
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final taxonomyLines = _taxonomySummary(product);
    final unitPaise = product.effectiveUnitPaiseForQuantity(qty);
    final lineTotal = unitPaise * qty;
    final oos = product.isOutOfStock;
    final priceTiers = product.offerActive ? product.effectivePriceTiers() : product.priceTiers;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: AppColors.surfaceVariant),
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.image_not_supported_outlined, size: 48),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          child: Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${marketplaceFormatInr(unitPaise)} / unit @ $qty pcs',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (priceTiers.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('All quantity bands', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        ...priceTiers.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${t.quantityLabel()}: ${marketplaceFormatInr(t.pricePaise)} / unit',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.3),
                            ),
                          ),
                        ),
                      ],
                      if (oos) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Currently out of stock.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (taxonomyLines.isNotEmpty) ...[
                        Text(
                          'Category & options',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: taxonomyLines
                              .map(
                                (line) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(line, style: theme.textTheme.labelMedium),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Sold & fulfilled by D.G.Yard. GST-compliant invoicing from D.G.Yard on dispatch.',
                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(product.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text('Quantity', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: qty > product.moq ? () => onQty(qty - 1) : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('$qty', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => onQty(qty + 1),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: FilledButton(
              onPressed: oos
                  ? null
                  : () async {
                      await cart.addCatalogProduct(product, quantity: qty);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Added to cart')),
                        );
                        context.pop();
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  oos ? 'Out of stock' : 'Add to cart · ${marketplaceFormatInr(lineTotal)}',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static List<String> _taxonomySummary(MarketplaceCatalogProduct product) {
    final out = <String>[];
    if (product.categoryName.trim().isNotEmpty) {
      out.add(product.categoryName.trim());
    }
    if (product.subcategoryName.trim().isNotEmpty) {
      out.add(product.subcategoryName.trim());
    }
    product.attributeSelections.forEach((k, v) {
      if (v.trim().isEmpty) return;
      final label = k.replaceAll('_', ' ');
      out.add('$label: ${v.trim()}');
    });
    return out;
  }
}

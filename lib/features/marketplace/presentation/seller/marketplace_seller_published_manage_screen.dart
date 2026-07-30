import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/marketplace_catalog_repository.dart';
import '../../data/marketplace_listing_repository.dart';
import '../../domain/marketplace_catalog_product.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_format.dart';
import '../widgets/marketplace_premium_shell.dart';

/// Stock / availability and edit-delete requests for a [published] listing with a catalog row.
class MarketplaceSellerPublishedManageScreen extends StatefulWidget {
  const MarketplaceSellerPublishedManageScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<MarketplaceSellerPublishedManageScreen> createState() => _MarketplaceSellerPublishedManageScreenState();
}

class _MarketplaceSellerPublishedManageScreenState extends State<MarketplaceSellerPublishedManageScreen> {
  final _listings = MarketplaceListingRepository();
  final _catalog = MarketplaceCatalogRepository();
  final _stockCtrl = TextEditingController();

  MarketplaceListing? _listing;
  MarketplaceCatalogProduct? _product;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final l = await _listings.getListing(widget.listingId);
    if (!mounted) return;
    if (l == null || l.status != 'published' || (l.catalogProductId ?? '').isEmpty || l.sellerUid != uid) {
      setState(() {
        _loading = false;
        _error = 'Listing not available or not published.';
      });
      return;
    }
    final p = await _catalog.getProductIfOwnedBySeller(l.catalogProductId!, uid);
    if (!mounted) return;
    setState(() {
      _listing = l;
      _product = p;
      _stockCtrl.text = p?.stockQty != null ? '${p!.stockQty}' : '';
      _loading = false;
      if (p == null) _error = 'Catalog product missing or not linked to your account yet. Ask admin to republish.';
    });
  }

  Future<void> _applyStockAndStatus({String? listingStatus, bool saveStockOnly = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final l = _listing;
    final p = _product;
    if (uid == null || l == null || p == null) return;
    final raw = _stockCtrl.text.trim();
    int? stock;
    var clearStock = false;
    if (saveStockOnly) {
      if (raw.isEmpty) {
        clearStock = true;
      } else {
        stock = int.tryParse(raw);
        if (stock == null || stock < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock must be empty or a non‑negative whole number.')),
          );
          return;
        }
      }
    }
    setState(() => _busy = true);
    try {
      await _catalog.sellerPatchCatalog(
        catalogProductId: p.id,
        sellerUid: uid,
        listingStatus: listingStatus,
        stockQty: stock,
        clearStockQty: clearStock,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDeletionRequest() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request removal?'),
        content: const Text(
          'Admin will review and can remove this product from the buyer catalog. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request removal')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _listings.requestCatalogDeletionReview(widget.listingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removal request sent for admin approval')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MarketplacePremiumShell(
        body: Column(
          children: [
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }
    if (_error != null || _listing == null) {
      return MarketplacePremiumShell(
        appBar: AppBar(title: const Text('Product')),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error ?? 'Error'),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final l = _listing!;
    final p = _product;

    return MarketplacePremiumShell(
      appBar: AppBar(title: Text(l.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Live on catalog · buyers see this version until a change is approved.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 20),
                if (p != null) ...[
                  Text('Catalog price (from last approval)', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    marketplaceFormatInr(p.pricePaise),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (p.priceTiers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Quantity bands',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...p.priceTiers.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${t.quantityLabel()}: ${marketplaceFormatInr(t.pricePaise)} / unit',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Stock',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stockCtrl,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Units in stock',
                      helperText: 'Empty = not tracking count in Firestore',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : () => _applyStockAndStatus(saveStockOnly: true),
                    child: const Text('Save stock'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _applyStockAndStatus(listingStatus: 'out_of_stock'),
                          child: const Text('Mark out of stock'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _busy ? null : () => _applyStockAndStatus(listingStatus: 'live'),
                          child: const Text('Mark live'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Changes needing approval',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : () => context.push(RouteNames.marketplaceSellerListingEdit(l.id)),
                  child: const Text('Edit product (text, photos, prices, category…)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : _confirmDeletionRequest,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Request removal from catalog'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

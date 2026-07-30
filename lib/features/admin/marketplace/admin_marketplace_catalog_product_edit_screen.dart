import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_catalog_repository.dart';
import '../../marketplace/data/marketplace_admin_actions.dart';
import '../../marketplace/domain/marketplace_catalog_product.dart';
import '../../marketplace/presentation/marketplace_format.dart';

/// Superadmin: edit or delete one catalog row.
class AdminMarketplaceCatalogProductEditScreen extends StatefulWidget {
  const AdminMarketplaceCatalogProductEditScreen({super.key, required this.productId});

  final String productId;

  @override
  State<AdminMarketplaceCatalogProductEditScreen> createState() => _AdminMarketplaceCatalogProductEditScreenState();
}

class _AdminMarketplaceCatalogProductEditScreenState extends State<AdminMarketplaceCatalogProductEditScreen> {
  final _repo = MarketplaceCatalogRepository();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _moq = TextEditingController();
  final _stock = TextEditingController();
  final _offerDiscount = TextEditingController();
  final _offerPrice = TextEditingController();

  MarketplaceCatalogProduct? _product;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _listingStatus = 'live';
  bool _offerActive = false;

  static const _statuses = ['live', 'out_of_stock', 'draft'];

  static String _statusMenuLabel(String s) {
    switch (s) {
      case 'live':
        return 'Live';
      case 'out_of_stock':
        return 'Out of stock';
      case 'draft':
        return 'Draft';
      default:
        return s;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _moq.dispose();
    _stock.dispose();
    _offerDiscount.dispose();
    _offerPrice.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final p = await _repo.getProductForAdmin(widget.productId);
    if (!mounted) return;
    if (p == null) {
      setState(() {
        _loading = false;
        _error = 'Product not found.';
      });
      return;
    }
    _product = p;
    _title.text = p.title;
    _desc.text = p.description;
    _price.text = (p.pricePaise / 100).toStringAsFixed(p.pricePaise % 100 == 0 ? 0 : 2);
    _moq.text = '${p.moq}';
    _stock.text = p.stockQty != null ? '${p.stockQty}' : '';
    _listingStatus = _statuses.contains(p.listingStatus) ? p.listingStatus : 'live';
    _offerActive = p.offerActive;
    _offerDiscount.text = p.offerDiscountPercent?.toString() ?? '';
    if (p.offerPricePaise != null && p.offerPricePaise! > 0) {
      final rupees = p.offerPricePaise! / 100;
      _offerPrice.text = rupees.toStringAsFixed(p.offerPricePaise! % 100 == 0 ? 0 : 2);
    } else {
      _offerPrice.text = '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final p = _product;
    if (p == null) return;
    final rupees = double.tryParse(_price.text.trim());
    final moq = int.tryParse(_moq.text.trim());
    if (_title.text.trim().isEmpty || rupees == null || moq == null || moq < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title, valid price, and MOQ ≥ 1 are required')),
      );
      return;
    }
    final stockRaw = _stock.text.trim();
    int? stock;
    var clearStock = false;
    if (stockRaw.isEmpty) {
      clearStock = true;
    } else {
      stock = int.tryParse(stockRaw);
      if (stock == null || stock < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock must be empty or a non‑negative number')),
        );
        return;
      }
    }

    int? offerDiscountPercent;
    int? offerPricePaise;
    if (_offerActive) {
      final dRaw = _offerDiscount.text.trim();
      if (dRaw.isNotEmpty) {
        offerDiscountPercent = int.tryParse(dRaw);
        if (offerDiscountPercent == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer discount % must be a valid integer.')));
          return;
        }
      }
      final pRaw = _offerPrice.text.trim();
      if (pRaw.isNotEmpty) {
        final d = double.tryParse(pRaw);
        if (d == null || d < 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer price must be a valid number.')));
          return;
        }
        offerPricePaise = (d * 100).round();
      }

      if (_offerDiscount.text.trim().isEmpty && _offerPrice.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set an offer discount % or offer price.')));
        return;
      }
    }

    setState(() => _busy = true);
    try {
      await MarketplaceAdminActions.adminUpdateCatalogProduct(
        catalogProductId: p.id,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        pricePaise: (rupees * 100).round(),
        moq: moq,
        listingStatus: _listingStatus,
        stockQty: clearStock ? null : stock,
        clearStockQty: clearStock,
        offerActive: _offerActive,
        offerDiscountPercent: offerDiscountPercent,
        offerPricePaise: offerPricePaise,
      );
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await MarketplaceAdminActions.logAudit(
        actorUid: uid,
        action: 'admin_edit_catalog_product',
        entityType: 'marketplace_catalog',
        entityId: p.id,
        payload: {'listing_status': _listingStatus},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete catalog product?'),
        content: const Text(
          'Removes this row from the buyer catalog. If a seller listing is linked, it will be archived.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(foregroundColor: Colors.white, backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = widget.productId;
      await MarketplaceAdminActions.deleteCatalogProductAndUnlinkListing(id);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await MarketplaceAdminActions.logAudit(
        actorUid: uid,
        action: 'admin_delete_catalog_product',
        entityType: 'marketplace_catalog',
        entityId: id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Catalog product')),
        body: Center(child: Text(_error ?? 'Error')),
      );
    }
    final p = _product!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Edit catalog product'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Document ${p.id}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                ),
          ),
          if (p.sourceListingId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Source listing: ${p.sourceListingId}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            enabled: !_busy,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (INR)',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _moq,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'MOQ',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Offer Active'),
            trailing: Switch(
              value: _offerActive,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                        _offerActive = v;
                      }),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _offerDiscount,
            enabled: !_busy && _offerActive,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Offer Discount % (optional)',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _offerPrice,
            enabled: !_busy && _offerActive,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Offer Price at MOQ (INR)',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _listingStatus,
                isExpanded: true,
                items: _statuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          _statusMenuLabel(s),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v != null) setState(() => _listingStatus = v);
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stock,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stock (optional)',
              helperText: 'Empty = not tracking quantity',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          if (p.priceTiers.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Quantity bands (read-only here)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...p.priceTiers.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${t.quantityLabel()}: ${marketplaceFormatInr(t.pricePaise)} / unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ),
            ),
            Text(
              'To change bands, use seller resubmit or update Firestore.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _confirmDelete,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete from catalog'),
          ),
        ],
      ),
    );
  }
}

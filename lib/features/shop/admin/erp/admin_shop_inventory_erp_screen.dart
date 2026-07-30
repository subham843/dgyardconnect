import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../admin/widgets/admin_embedded_scaffold.dart';
import '../../data/shop_erp_repository.dart';
import '../../domain/shop_erp_models.dart';

/// FIFO-aware inventory view (stock from transaction ledger, not manual qty edits).
class AdminShopInventoryErpScreen extends StatefulWidget {
  const AdminShopInventoryErpScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopInventoryErpScreen> createState() => _AdminShopInventoryErpScreenState();
}

class _AdminShopInventoryErpScreenState extends State<AdminShopInventoryErpScreen> {
  final _repo = ShopErpRepository();
  List<StockReportRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _rows = await _repo.stockReport();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return AdminEmbeddedScaffold(
      title: 'Inventory',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Stock increases via Purchase receipts only — same SKU, no duplicate products. FIFO lots and serials tracked in database.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  ..._rows.map(
                    (r) => ListTile(
                      title: Text(r.productName),
                      subtitle: Text('${r.sku} · avg ${inr.format(r.avgCost)} · ${r.serialsInStock} serials'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${r.qtyOnHand} pcs', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(inr.format(r.stockValue), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

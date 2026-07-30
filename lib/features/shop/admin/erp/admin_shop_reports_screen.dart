import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../admin/widgets/admin_embedded_scaffold.dart';
import '../../data/shop_erp_repository.dart';

class AdminShopReportsScreen extends StatefulWidget {
  const AdminShopReportsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopReportsScreen> createState() => _AdminShopReportsScreenState();
}

class _AdminShopReportsScreenState extends State<AdminShopReportsScreen> {
  final _repo = ShopErpRepository();
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _gst = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _purchases = await _repo.purchaseRegister();
    _gst = await _repo.gstSummary();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return AdminEmbeddedScaffold(
      title: 'Reports',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('GST summary (purchases)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_gst.isEmpty)
                    const Text('No GST data yet')
                  else
                    ..._gst.map(
                      (g) => ListTile(
                        dense: true,
                        title: Text(g['period_month']?.toString() ?? ''),
                        trailing: Text(inr.format((g['input_gst'] as num?) ?? 0)),
                        subtitle: Text('Taxable: ${inr.format((g['taxable_purchases'] as num?) ?? 0)}'),
                      ),
                    ),
                  const Divider(height: 32),
                  Text('Purchase register', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_purchases.isEmpty)
                    const Text('No purchases posted yet')
                  else
                    ..._purchases.take(50).map(
                      (p) => ListTile(
                        dense: true,
                        title: Text('${p['purchase_invoice_no']} — ${p['sku']}'),
                        subtitle: Text('${p['supplier_name'] ?? ''} · qty ${p['quantity']}'),
                        trailing: Text(inr.format((p['line_total'] as num?) ?? 0)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_order_repository.dart';
import '../domain/shop_order.dart';
import 'erp/admin_shop_inventory_erp_screen.dart';

/// Inventory admin — transaction-based stock (see [AdminShopInventoryErpScreen]).
class AdminShopInventoryScreen extends StatelessWidget {
  const AdminShopInventoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) => AdminShopInventoryErpScreen(embedded: embedded);
}

class AdminShopOrdersScreen extends StatefulWidget {
  const AdminShopOrdersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopOrdersScreen> createState() => _AdminShopOrdersScreenState();
}

class _AdminShopOrdersScreenState extends State<AdminShopOrdersScreen> {
  final _repo = ShopOrderRepository();
  List<ShopOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _orders = await _repo.listAllOrdersAdmin();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editOrderStatus(ShopOrder o) async {
    const statuses = ['draft', 'pending_payment', 'paid', 'processing', 'shipped', 'delivered', 'cancelled'];
    var status = o.status;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Order status'),
        content: DropdownButtonFormField<String>(
          initialValue: status,
          items: [for (final s in statuses) DropdownMenuItem(value: s, child: Text(s))],
          onChanged: (v) => status = v ?? status,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.updateOrderStatus(o.id, status);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Shop orders',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (_, i) {
                final o = _orders[i];
                return ListTile(
                  title: Text('₹${o.totalAmount.toStringAsFixed(0)} · ${o.status}'),
                  subtitle: Text('${o.firebaseUid} · ${o.createdAt}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Change status',
                    onPressed: () => _editOrderStatus(o),
                  ),
                );
              },
            ),
    );
  }
}

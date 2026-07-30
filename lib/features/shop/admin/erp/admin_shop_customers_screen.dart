import 'package:flutter/material.dart';

import '../../../admin/widgets/admin_embedded_scaffold.dart';
import '../../admin/validation/shop_erp_validation.dart';
import '../../data/shop_erp_repository.dart';
import '../../domain/shop_erp_models.dart';

class AdminShopCustomersScreen extends StatefulWidget {
  const AdminShopCustomersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopCustomersScreen> createState() => _AdminShopCustomersScreenState();
}

class _AdminShopCustomersScreenState extends State<AdminShopCustomersScreen> {
  final _repo = ShopErpRepository();
  List<ShopCustomer> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listCustomers();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Code *')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final cErr = ShopErpValidation.customerCode(code.text);
    final nErr = ShopErpValidation.requiredText(name.text, label: 'Name');
    if (cErr != null || nErr != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cErr ?? nErr!)));
      }
      return;
    }
    await _repo.createCustomer(code: code.text, name: name.text, phone: phone.text);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Customers',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Customer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final c = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(c.name),
                    subtitle: Text('${c.code}${c.phone != null ? ' · ${c.phone}' : ''}'),
                  );
                },
              ),
            ),
    );
  }
}

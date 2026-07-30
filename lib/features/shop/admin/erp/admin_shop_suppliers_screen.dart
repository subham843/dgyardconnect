import 'package:flutter/material.dart';

import '../../../admin/widgets/admin_embedded_scaffold.dart';
import '../../admin/validation/shop_erp_validation.dart';
import '../../data/shop_erp_repository.dart';
import '../../domain/shop_erp_models.dart';

class AdminShopSuppliersScreen extends StatefulWidget {
  const AdminShopSuppliersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopSuppliersScreen> createState() => _AdminShopSuppliersScreenState();
}

class _AdminShopSuppliersScreenState extends State<AdminShopSuppliersScreen> {
  final _repo = ShopErpRepository();
  List<ShopSupplier> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listSuppliers();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final gstin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'Code *')),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
              TextField(controller: gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final cErr = ShopErpValidation.supplierCode(code.text);
    final nErr = ShopErpValidation.requiredText(name.text, label: 'Name');
    if (cErr != null || nErr != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cErr ?? nErr!)));
      }
      return;
    }
    await _repo.createSupplier(code: code.text, name: name.text, gstin: gstin.text);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Suppliers',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Supplier'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final s = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(s.name),
                    subtitle: Text('${s.code}${s.gstin != null ? ' · ${s.gstin}' : ''}'),
                    trailing: s.isActive ? null : const Text('Inactive', style: TextStyle(color: Colors.grey)),
                  );
                },
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import 'shop_admin_crud_actions.dart';
import '../domain/shop_product.dart';

class AdminShopBrandsScreen extends StatefulWidget {
  const AdminShopBrandsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopBrandsScreen> createState() => _AdminShopBrandsScreenState();
}

class _AdminShopBrandsScreenState extends State<AdminShopBrandsScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopBrand> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listBrands();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New brand'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.createBrand(name.text.trim());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Brands',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Brand')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final b = _items[i];
                return ListTile(
                  title: Text(b.name),
                  subtitle: Text('${b.slug}${b.isActive ? '' : ' · hidden'}'),
                  trailing: ShopAdminRowActions(
                    isActive: b.isActive,
                    onEdit: () => ShopAdminCrudActions.editBrand(context, b, _load),
                    onToggleActive: () => ShopAdminCrudActions.toggleBrandActive(context, b, _load),
                    onDelete: () => ShopAdminCrudActions.deleteBrand(context, b, _load),
                  ),
                );
              },
            ),
    );
  }
}

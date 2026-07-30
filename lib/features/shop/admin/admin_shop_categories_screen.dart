import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import 'shop_admin_crud_actions.dart';
import '../domain/shop_category.dart';

class AdminShopCategoriesScreen extends StatefulWidget {
  const AdminShopCategoriesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopCategoriesScreen> createState() => _AdminShopCategoriesScreenState();
}

class _AdminShopCategoriesScreenState extends State<AdminShopCategoriesScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopCategory> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listCategories(activeOnly: false);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    await ShopAdminCrudActions.addCategory(context, _load);
  }

  @override
  Widget build(BuildContext context) {
    final list = _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
            ? const Center(child: Text('No categories. Add CCTV, Networking, etc.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = _items[i];
                    return ListTile(
                      tileColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${c.slug} · order ${c.sortOrder}${c.isActive ? ' · live on homepage' : ' · hidden from homepage'}',
                      ),
                      trailing: ShopAdminRowActions(
                        isActive: c.isActive,
                        onEdit: () => ShopAdminCrudActions.editCategory(context, c, _load),
                        onToggleActive: () => ShopAdminCrudActions.toggleCategoryActive(context, c, _load),
                        onDelete: () => ShopAdminCrudActions.deleteCategory(context, c, _load),
                      ),
                    );
                  },
              );

    return AdminEmbeddedScaffold(
      title: 'Categories',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Category')),
      body: list,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import 'shop_admin_crud_actions.dart';
import '../domain/shop_category.dart';

class AdminShopSubCategoriesScreen extends StatefulWidget {
  const AdminShopSubCategoriesScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminShopSubCategoriesScreen> createState() => _AdminShopSubCategoriesScreenState();
}

class _AdminShopSubCategoriesScreenState extends State<AdminShopSubCategoriesScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopCategory> _categories = [];
  String? _categoryId;
  List<ShopSubCategory> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _categories = await _repo.listCategories(activeOnly: false);
    _categoryId = _categories.isNotEmpty ? _categories.first.id : null;
    await _loadSubs();
  }

  Future<void> _loadSubs() async {
    if (_categoryId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    _subs = await _repo.listSubCategories(_categoryId!, activeOnly: false);
    if (mounted) setState(() => _loading = false);
  }

  void _openEditor({String? subCategoryId}) {
    final route = subCategoryId == null
        ? (_categoryId != null
            ? RouteNames.adminShopSubCategoryCreateInCategory(_categoryId!)
            : RouteNames.adminShopSubCategoryCreate)
        : RouteNames.adminShopSubCategoryEdit(subCategoryId);
    if (widget.embedded && widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
      return;
    }
    context.push(route).then((_) => _loadSubs());
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Sub categories',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Sub category'),
      ),
      body: Column(
        children: [
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Parent category', border: OutlineInputBorder()),
                items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) async {
                  setState(() => _categoryId = v);
                  await _loadSubs();
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _subs.length,
                    itemBuilder: (_, i) {
                      final s = _subs[i];
                      final groups = s.attributeGroupNames.isEmpty
                          ? 'No attribute groups'
                          : s.attributeGroupNames.join(', ');
                      return ListTile(
                        title: Text(s.name),
                        subtitle: Text('${s.slug} · $groups${s.isActive ? '' : ' · hidden'}'),
                        isThreeLine: s.attributeGroupNames.length > 2,
                        onTap: () => _openEditor(subCategoryId: s.id),
                        trailing: ShopAdminRowActions(
                          isActive: s.isActive,
                          onEdit: () => _openEditor(subCategoryId: s.id),
                          onToggleActive: () => ShopAdminCrudActions.toggleSubCategoryActive(context, s, _loadSubs),
                          onDelete: () => ShopAdminCrudActions.deleteSubCategory(context, s, _loadSubs),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

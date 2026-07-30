import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../data/shop_catalog_repository.dart';
import '../domain/shop_attribute.dart';
import '../domain/shop_category.dart';
import '../domain/shop_product.dart';
import 'widgets/shop_attribute_filters.dart';

class ShopCategoryScreen extends StatefulWidget {
  const ShopCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<ShopCategoryScreen> createState() => _ShopCategoryScreenState();
}

class _ShopCategoryScreenState extends State<ShopCategoryScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopSubCategory> _subs = [];
  String? _subId;
  List<ShopProduct> _products = [];
  List<ShopAttributeMaster> _filterAttrs = [];
  List<ShopProductAttributeValue> _productAttrs = [];
  final Map<String, Set<String>> _filters = {};
  bool _loading = true;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _subs = await _repo.listSubCategories(widget.categoryId);
    _subId = _subs.isNotEmpty ? _subs.first.id : null;
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (_subId != null) {
      _products = await _repo.listProducts(subCategoryId: _subId);
      _filterAttrs = await _repo.listFilterAttributes(subCategoryId: _subId);
      _productAttrs = await _repo.listProductAttributesForSubCategory(_subId!);
    } else {
      _products = [];
      _filterAttrs = [];
      _productAttrs = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<ShopProduct> get _visibleProducts {
    final ids = filterProductIds(_products, _productAttrs, _filters);
    return _products.where((p) => ids.contains(p.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (_filterAttrs.isNotEmpty)
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
              tooltip: 'Filters',
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_subs.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: DropdownButtonFormField<String>(
                      initialValue: _subId,
                      decoration: const InputDecoration(labelText: 'Sub category', isDense: true),
                      items: [for (final s in _subs) DropdownMenuItem(value: s.id, child: Text(s.name))],
                      onChanged: (v) async {
                        setState(() {
                          _subId = v;
                          _filters.clear();
                        });
                        await _load();
                      },
                    ),
                  ),
                if (_showFilters && _filterAttrs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ShopAttributeFilters(
                      attributes: _filterAttrs,
                      productAttributes: _productAttrs,
                      selected: _filters,
                      onChanged: (id, values) => setState(() {
                        if (values.isEmpty) {
                          _filters.remove(id);
                        } else {
                          _filters[id] = values;
                        }
                      }),
                    ),
                  ),
                Expanded(
                  child: _visibleProducts.isEmpty
                      ? const Center(child: Text('No products match your filters'))
                      : ListView.builder(
                          itemCount: _visibleProducts.length,
                          itemBuilder: (_, i) {
                            final p = _visibleProducts[i];
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text('₹${p.basePrice.toStringAsFixed(0)}'),
                              onTap: () => context.push(RouteNames.shopProduct(p.id)),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

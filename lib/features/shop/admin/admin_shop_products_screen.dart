import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import '../domain/shop_category.dart';
import '../domain/shop_product.dart';
import 'shop_admin_crud_actions.dart';

/// All products with optional category / sub-category filters.
class AdminShopProductsScreen extends StatefulWidget {
  const AdminShopProductsScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminShopProductsScreen> createState() => _AdminShopProductsScreenState();
}

class _AdminShopProductsScreenState extends State<AdminShopProductsScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopProduct> _allProducts = [];
  List<ShopSubCategory> _allSubs = [];
  List<ShopCategory> _categories = [];
  String? _filterCategoryId;
  String? _filterSubId;
  bool _loading = true;
  String? _error;

  static const _allCategoriesValue = '__all_categories__';
  static const _allSubsValue = '__all_subs__';

  List<ShopProduct> get _visibleProducts {
    var list = _allProducts;
    if (_filterSubId != null && _filterSubId!.isNotEmpty) {
      list = list.where((p) => p.subCategoryId == _filterSubId).toList();
    } else if (_filterCategoryId != null && _filterCategoryId!.isNotEmpty) {
      final subIds = _allSubs.where((s) => s.categoryId == _filterCategoryId).map((s) => s.id).toSet();
      list = list.where((p) => subIds.contains(p.subCategoryId)).toList();
    }
    return list;
  }

  List<ShopSubCategory> get _subsForFilterCategory {
    if (_filterCategoryId == null || _filterCategoryId!.isEmpty) return _allSubs;
    return _allSubs.where((s) => s.categoryId == _filterCategoryId).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listCategories(activeOnly: false),
        _repo.listAllSubCategories(),
        _repo.listProductsAdmin(activeOnly: false),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<ShopCategory>;
        _allSubs = results[1] as List<ShopSubCategory>;
        _allProducts = results[2] as List<ShopProduct>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _allProducts = [];
      });
    }
  }

  Future<void> _pickCategorySubCategoryForNewProduct() async {
    if (_categories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a category first, then add products.')),
      );
      return;
    }

    String? catId = _filterCategoryId ?? _categories.first.id;
    var subs = _allSubs.where((s) => s.categoryId == catId).toList();
    String? subId = subs.isNotEmpty ? subs.first.id : null;

    final picked = await showDialog<({String categoryId, String subCategoryId})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            subs = _allSubs.where((s) => s.categoryId == catId).toList();
            if (subId != null && !subs.any((s) => s.id == subId)) {
              subId = subs.isNotEmpty ? subs.first.id : null;
            }
            return AlertDialog(
              title: const Text('New product'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose category and sub-category before adding product details.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: catId,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          catId = v;
                          final nextSubs = _allSubs.where((s) => s.categoryId == catId).toList();
                          subId = nextSubs.isNotEmpty ? nextSubs.first.id : null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: subId,
                      decoration: const InputDecoration(
                        labelText: 'Sub-category *',
                        border: OutlineInputBorder(),
                      ),
                      items: subs.isEmpty
                          ? const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('No sub-categories — create one first'),
                              ),
                            ]
                          : [
                              for (final s in subs)
                                DropdownMenuItem(value: s.id, child: Text(s.name)),
                            ],
                      onChanged: subs.isEmpty ? null : (v) => setDialogState(() => subId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: subId == null || subId!.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, (categoryId: catId!, subCategoryId: subId!)),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;
    _openEditor(subCategoryId: picked.subCategoryId);
  }

  void _openEditor({String? productId, String? subCategoryId}) {
    final route = productId == null
        ? (subCategoryId != null && subCategoryId.isNotEmpty
            ? RouteNames.adminShopProductCreateInSubCategory(subCategoryId)
            : RouteNames.adminShopProductCreate)
        : RouteNames.adminShopProductEdit(productId);
    if (widget.embedded && widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
      return;
    }
    context.push(route).then((_) => _loadAll());
  }

  void _openAiImport() {
    const route = RouteNames.adminShopProductImport;
    if (widget.embedded && widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
      return;
    }
    context.push(route).then((_) => _loadAll());
  }

  void _clearFilters() {
    setState(() {
      _filterCategoryId = null;
      _filterSubId = null;
    });
  }

  void _patchProduct(ShopProduct updated) {
    setState(() {
      _allProducts = [
        for (final p in _allProducts)
          if (p.id == updated.id) updated else p,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProducts;

    return AdminEmbeddedScaffold(
      title: 'Products',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _pickCategorySubCategoryForNewProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFFF1F5F9),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: _loading ? null : _openAiImport,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('AI import'),
                      ),
                      const SizedBox(width: 8),
                      if (_filterCategoryId != null || _filterSubId != null)
                        TextButton(onPressed: _clearFilters, child: const Text('Clear filters')),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loading ? null : _loadAll,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filterCategoryId ?? _allCategoriesValue,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            isDense: true,
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: _allCategoriesValue,
                              child: Text('All categories'),
                            ),
                            for (final c in _categories)
                              DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ],
                          onChanged: _loading
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == _allCategoriesValue) {
                                      _filterCategoryId = null;
                                      _filterSubId = null;
                                    } else {
                                      _filterCategoryId = v;
                                      _filterSubId = null;
                                    }
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filterSubId ?? _allSubsValue,
                          decoration: const InputDecoration(
                            labelText: 'Sub-category',
                            isDense: true,
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: _allSubsValue,
                              child: Text('All sub-categories'),
                            ),
                            for (final s in _subsForFilterCategory)
                              DropdownMenuItem(value: s.id, child: Text(s.name)),
                          ],
                          onChanged: _loading
                              ? null
                              : (v) {
                                  setState(() {
                                    _filterSubId = v == _allSubsValue ? null : v;
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _loading
                        ? 'Loading…'
                        : '${visible.length} shown · ${_allProducts.length} total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<ShopProduct> visible) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text('Could not load products', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _allProducts.isEmpty ? 'No products yet' : 'No products match these filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_allProducts.isEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _pickCategorySubCategoryForNewProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add first product'),
              ),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
        itemCount: visible.length,
        itemBuilder: (_, i) {
          final p = visible[i];
          return _ProductPriceListRow(
            key: ValueKey(p.id),
            product: p,
            repo: _repo,
            onSaved: _patchProduct,
            onEdit: () => _openEditor(productId: p.id),
            onToggleActive: () => ShopAdminCrudActions.toggleProductActive(context, p, _loadAll),
            onDelete: () => ShopAdminCrudActions.deleteProduct(context, p, _loadAll),
          );
        },
      ),
    );
  }
}

class _ProductPriceListRow extends StatefulWidget {
  const _ProductPriceListRow({
    super.key,
    required this.product,
    required this.repo,
    required this.onSaved,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final ShopProduct product;
  final ShopCatalogRepository repo;
  final ValueChanged<ShopProduct> onSaved;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  State<_ProductPriceListRow> createState() => _ProductPriceListRowState();
}

class _ProductPriceListRowState extends State<_ProductPriceListRow> {
  late final TextEditingController _mrpCtrl;
  late final TextEditingController _onlineCtrl;
  late final TextEditingController _dealerCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mrpCtrl = TextEditingController();
    _onlineCtrl = TextEditingController();
    _dealerCtrl = TextEditingController();
    _applyProductToControllers(widget.product);
    for (final c in [_mrpCtrl, _onlineCtrl, _dealerCtrl]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void didUpdateWidget(covariant _ProductPriceListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.mrp != widget.product.mrp ||
        oldWidget.product.onlinePrice != widget.product.onlinePrice ||
        oldWidget.product.dealerPrice != widget.product.dealerPrice) {
      _applyProductToControllers(widget.product);
    }
  }

  void _applyProductToControllers(ShopProduct p) {
    _mrpCtrl.text = _priceText(p.mrp);
    _onlineCtrl.text = _priceText(p.onlinePrice ?? p.basePrice);
    _dealerCtrl.text = _priceText(p.dealerPrice);
  }

  String _priceText(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  double? _parsePrice(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _dirty {
    final p = widget.product;
    return _parsePrice(_mrpCtrl) != p.mrp ||
        _parsePrice(_onlineCtrl) != (p.onlinePrice ?? p.basePrice) ||
        _parsePrice(_dealerCtrl) != p.dealerPrice;
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_mrpCtrl, _onlineCtrl, _dealerCtrl]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _savePrices() async {
    final mrp = _parsePrice(_mrpCtrl);
    final online = _parsePrice(_onlineCtrl);
    final dealer = _parsePrice(_dealerCtrl);

    if (online != null && online <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Online price must be greater than zero.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repo.updateProductPricing(
        productId: widget.product.id,
        mrp: mrp,
        onlinePrice: online,
        dealerPrice: dealer,
      );
      if (!mounted) return;
      final updated = widget.product.copyWith(
        mrp: mrp,
        onlinePrice: online,
        dealerPrice: dealer,
        basePrice: online ?? widget.product.basePrice,
        clearMrp: mrp == null,
        clearDealerPrice: dealer == null,
        clearOnlinePrice: online == null,
      );
      widget.onSaved(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prices updated for ${widget.product.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save prices: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _priceField({
    required String label,
    required TextEditingController controller,
  }) {
    return SizedBox(
      width: 108,
      child: TextField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixText: '₹ ',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final path = [
      if (p.categoryName != null && p.categoryName!.isNotEmpty) p.categoryName,
      if (p.subCategoryName != null && p.subCategoryName!.isNotEmpty) p.subCategoryName,
    ].join(' → ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 720;
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: widget.onEdit,
                  child: Text(
                    p.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (path.isNotEmpty) path,
                    p.sku,
                    if (!p.isActive) 'hidden',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            );

            final prices = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _priceField(label: 'MRP', controller: _mrpCtrl),
                _priceField(label: 'Online', controller: _onlineCtrl),
                _priceField(label: 'Dealer', controller: _dealerCtrl),
                FilledButton.tonalIcon(
                  onPressed: !_dirty || _saving ? null : _savePrices,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Saving' : 'Save'),
                ),
              ],
            );

            final actions = ShopAdminRowActions(
              isActive: p.isActive,
              onEdit: widget.onEdit,
              onToggleActive: widget.onToggleActive,
              onDelete: widget.onDelete,
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: info),
                      actions,
                    ],
                  ),
                  const SizedBox(height: 10),
                  prices,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: info),
                Expanded(flex: 5, child: prices),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

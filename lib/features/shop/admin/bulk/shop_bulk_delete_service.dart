import '../../data/shop_catalog_repository.dart';
import '../../data/shop_erp_repository.dart';
import '../../data/supabase_repository_base.dart';
import 'shop_bulk_import_service.dart';
import 'shop_bulk_import_type.dart';
import 'shop_bulk_list_item.dart';

class ShopBulkDeleteService {
  ShopBulkDeleteService({
    ShopCatalogRepository? repo,
    ShopErpRepository? erpRepo,
  })  : _repo = repo ?? ShopCatalogRepository(),
        _erpRepo = erpRepo ?? ShopErpRepository();

  final ShopCatalogRepository _repo;
  final ShopErpRepository _erpRepo;

  Future<List<ShopBulkListItem>> listItems(ShopBulkImportType type) async {
    return switch (type) {
      ShopBulkImportType.categories => _listCategories(),
      ShopBulkImportType.attributeMaster => _listAttributeMaster(),
      ShopBulkImportType.attributeOptions => _listAttributeOptions(),
      ShopBulkImportType.attributeGroups => _listAttributeGroups(),
      ShopBulkImportType.brands => _listBrands(),
      ShopBulkImportType.subCategories => _listSubCategories(),
      ShopBulkImportType.products => _listProducts(),
      ShopBulkImportType.productAttributes => Future.value(const []),
      ShopBulkImportType.suppliers => _listSuppliers(),
      ShopBulkImportType.customers => _listCustomers(),
    };
  }

  Future<ShopBulkImportResult> deleteItems({
    required ShopBulkImportType type,
    required List<ShopBulkListItem> items,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final results = <ShopBulkImportRowResult>[];
    var deleted = 0;
    var failed = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        await _deleteOne(type, item);
        results.add(ShopBulkImportRowResult(
          rowNumber: i + 1,
          label: item.label,
          success: true,
          message: 'Deleted',
        ));
        deleted++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(
          rowNumber: i + 1,
          label: item.label,
          success: false,
          message: '$e',
        ));
        failed++;
      }
    }

    return ShopBulkImportResult(
      results: results,
      created: deleted,
      skipped: 0,
      failed: failed,
    );
  }

  Future<void> _deleteOne(ShopBulkImportType type, ShopBulkListItem item) async {
    switch (type) {
      case ShopBulkImportType.categories:
        await _repo.deleteCategory(item.id);
      case ShopBulkImportType.attributeMaster:
        await _repo.deleteAttributeMaster(item.id);
      case ShopBulkImportType.attributeOptions:
        final attrId = item.parentId;
        if (attrId == null) throw StateError('Missing attribute_id');
        await _repo.deleteAttributeOption(optionId: item.id, attributeId: attrId);
      case ShopBulkImportType.attributeGroups:
        await _repo.deleteAttributeGroup(item.id);
      case ShopBulkImportType.brands:
        await _repo.deleteBrand(item.id);
      case ShopBulkImportType.subCategories:
        await _repo.deleteSubCategory(item.id);
      case ShopBulkImportType.products:
        await _repo.deleteProduct(item.id);
      case ShopBulkImportType.productAttributes:
        throw UnsupportedError('Not deletable here');
      case ShopBulkImportType.suppliers:
        await _erpRepo.deleteSupplier(item.id);
      case ShopBulkImportType.customers:
        await _erpRepo.deleteCustomer(item.id);
    }
  }

  Future<List<ShopBulkListItem>> _listCategories() async {
    final rows = await _repo.listCategories(activeOnly: false);
    return rows
        .map((c) => ShopBulkListItem(id: c.id, label: c.name, subtitle: c.slug))
        .toList();
  }

  Future<List<ShopBulkListItem>> _listAttributeMaster() async {
    final rows = await _repo.listAttributeMaster(activeOnly: false);
    return rows
        .map((a) => ShopBulkListItem(id: a.id, label: a.label, subtitle: a.key))
        .toList();
  }

  Future<List<ShopBulkListItem>> _listAttributeOptions() async {
    final masters = await _repo.listAttributeMaster(activeOnly: false);
    final lists = await Future.wait(masters.map((m) => _repo.listAttributeOptions(m.id)));
    final items = <ShopBulkListItem>[];
    for (var i = 0; i < masters.length; i++) {
      final m = masters[i];
      for (final o in lists[i]) {
        items.add(ShopBulkListItem(
          id: o.id,
          label: o.label,
          subtitle: '${m.key} · ${m.label}',
          parentId: m.id,
        ));
      }
    }
    items.sort((a, b) => (a.subtitle ?? '').compareTo(b.subtitle ?? ''));
    return items;
  }

  Future<List<ShopBulkListItem>> _listAttributeGroups() async {
    final rows = await _repo.listAttributeGroups();
    return rows
        .map((g) => ShopBulkListItem(id: g.id, label: g.name, subtitle: '${g.linkedAttributes.length} attributes'))
        .toList();
  }

  Future<List<ShopBulkListItem>> _listBrands() async {
    final rows = await _repo.listBrands();
    return rows.map((b) => ShopBulkListItem(id: b.id, label: b.name, subtitle: b.slug)).toList();
  }

  Future<List<ShopBulkListItem>> _listSubCategories() async {
    final cats = await _repo.listCategories(activeOnly: false);
    final catName = {for (final c in cats) c.id: c.name};
    final subs = await _repo.listAllSubCategories();
    return subs
        .map((s) => ShopBulkListItem(
              id: s.id,
              label: s.name,
              subtitle: '${catName[s.categoryId] ?? '?'} · ${s.slug}',
            ))
        .toList();
  }

  Future<List<ShopBulkListItem>> _listProducts() async {
    final rows = await _repo.listProductsAdmin(limit: 5000);
    return rows
        .map((p) => ShopBulkListItem(
              id: p.id,
              label: p.name,
              subtitle: 'SKU ${p.sku}${p.categoryName != null ? ' · ${p.categoryName}' : ''}',
            ))
        .toList();
  }

  Future<List<ShopBulkListItem>> _listSuppliers() async {
    final rows = await _erpRepo.listSuppliers();
    return rows.map((s) => ShopBulkListItem(id: s.id, label: s.name, subtitle: s.code)).toList();
  }

  Future<List<ShopBulkListItem>> _listCustomers() async {
    final rows = await _erpRepo.listCustomers();
    return rows.map((c) => ShopBulkListItem(id: c.id, label: c.name, subtitle: c.code)).toList();
  }
}

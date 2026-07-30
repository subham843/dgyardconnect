import '../../data/shop_catalog_repository.dart';
import '../../data/shop_erp_repository.dart';
import '../../domain/attribute_data_type.dart';
import '../../domain/shop_product_detail.dart';
import 'shop_bulk_import_type.dart';
import 'shop_csv_templates.dart';
import 'shop_csv_writer.dart';

class ShopBulkExportResult {
  const ShopBulkExportResult({
    required this.csv,
    required this.rowCount,
    required this.filename,
  });

  final String csv;
  final int rowCount;
  final String filename;
}

class ShopBulkExportService {
  ShopBulkExportService({
    ShopCatalogRepository? repo,
    ShopErpRepository? erpRepo,
  })  : _repo = repo ?? ShopCatalogRepository(),
        _erpRepo = erpRepo ?? ShopErpRepository();

  final ShopCatalogRepository _repo;
  final ShopErpRepository _erpRepo;

  Future<ShopBulkExportResult> export(ShopBulkImportType type) async {
    final headers = ShopCsvTemplates.headersFor(type);
    final rows = await switch (type) {
      ShopBulkImportType.categories => _exportCategories(),
      ShopBulkImportType.attributeMaster => _exportAttributeMaster(),
      ShopBulkImportType.attributeOptions => _exportAttributeOptions(),
      ShopBulkImportType.attributeGroups => _exportAttributeGroups(),
      ShopBulkImportType.brands => _exportBrands(),
      ShopBulkImportType.subCategories => _exportSubCategories(),
      ShopBulkImportType.products => _exportProducts(),
      ShopBulkImportType.productAttributes => _exportProductAttributes(),
      ShopBulkImportType.suppliers => _exportSuppliers(),
      ShopBulkImportType.customers => _exportCustomers(),
    };
    return ShopBulkExportResult(
      csv: ShopCsvWriter.buildCsv(headers: headers, rows: rows),
      rowCount: rows.length,
      filename: type.exportFilename,
    );
  }

  Future<List<List<String?>>> _exportCategories() async {
    final items = await _repo.listCategories(activeOnly: false);
    return items
        .map((c) => [
              c.name,
              '${c.sortOrder}',
              ShopCsvWriter.boolStr(c.isActive),
              c.slug,
              c.seo.seoTitle,
              c.seo.metaDescription,
            ])
        .toList();
  }

  Future<List<List<String?>>> _exportAttributeMaster() async {
    final items = await _repo.listAttributeMaster(activeOnly: false);
    return items
        .map((a) => [
              a.key,
              a.label,
              a.dataType,
              a.unit,
              ShopCsvWriter.boolStr(a.isRequired),
              ShopCsvWriter.boolStr(a.useInFilter),
              ShopCsvWriter.boolStr(a.useInCalculator),
              ShopCsvWriter.boolStr(a.isActive),
              a.allowedValues == null || a.allowedValues!.isEmpty
                  ? null
                  : ShopCsvWriter.pipeJoin(a.allowedValues!),
            ])
        .toList();
  }

  Future<List<List<String?>>> _exportAttributeOptions() async {
    final masters = await _repo.listAttributeMaster(activeOnly: false);
    final optionLists = await Future.wait(masters.map((m) => _repo.listAttributeOptions(m.id)));
    final rows = <List<String?>>[];
    for (var i = 0; i < masters.length; i++) {
      final m = masters[i];
      for (final o in optionLists[i]) {
        rows.add([
          m.key,
          o.label,
          '${o.sortOrder}',
          ShopCsvWriter.boolStr(o.isActive),
        ]);
      }
    }
    return rows;
  }

  Future<List<List<String?>>> _exportAttributeGroups() async {
    final items = await _repo.listAttributeGroups();
    return items.map((g) {
      final keys = g.linkedAttributes.map((l) => l.master.key).toList();
      final required = g.linkedAttributes
          .where((l) => l.isRequiredInGroup)
          .map((l) => l.master.key)
          .toList();
      return [
        g.name,
        g.description,
        ShopCsvWriter.boolStr(g.isActive),
        keys.isEmpty ? null : ShopCsvWriter.pipeJoin(keys),
        required.isEmpty ? null : ShopCsvWriter.pipeJoin(required),
      ];
    }).toList();
  }

  Future<List<List<String?>>> _exportBrands() async {
    final items = await _repo.listBrands();
    return items.map((b) => [b.name, ShopCsvWriter.boolStr(b.isActive)]).toList();
  }

  Future<List<List<String?>>> _exportSubCategories() async {
    final cats = await _repo.listCategories(activeOnly: false);
    final catSlug = {for (final c in cats) c.id: c.slug};
    final rows = <List<String?>>[];
    for (final cat in cats) {
      final subs = await _repo.listSubCategories(cat.id, activeOnly: false);
      for (final s in subs) {
        rows.add([
          catSlug[s.categoryId] ?? cat.slug,
          s.name,
          s.description,
          '${s.sortOrder}',
          ShopCsvWriter.boolStr(s.isActive),
          _numStr(s.defaultGstPercentage),
          s.defaultHsnCode,
          s.attributeGroupNames.isEmpty ? null : ShopCsvWriter.pipeJoin(s.attributeGroupNames),
          s.slug,
          s.seo.seoTitle,
          s.seo.metaDescription,
        ]);
      }
    }
    return rows;
  }

  Future<List<List<String?>>> _exportProducts() async {
    final rawRows = await _repo.listProductExportRows();
    return rawRows.map((map) {
      String? catSlug;
      String? subSlug;
      String? brandName;
      String? calcFamilyName;
      final sub = map['sub_categories'];
      if (sub is Map) {
        subSlug = sub['slug'] as String?;
        final cat = sub['categories'];
        if (cat is Map) catSlug = cat['slug'] as String?;
      }
      final brand = map['brands'];
      if (brand is Map) brandName = brand['name'] as String?;
      final cf = map['calculator_families'];
      if (cf is Map) calcFamilyName = cf['name'] as String?;

      final d = ShopProductDetail.fromRow(map, categoryId: sub is Map ? sub['category_id'] as String? : null);
      return [
        catSlug,
        subSlug,
        d.name,
        d.sku,
        brandName,
        d.barcode,
        d.modelName,
        d.hsnCode,
        _numStr(d.taxPercentage),
        ShopCsvWriter.boolStr(d.useGstOverride),
        d.taxClass,
        _numStr(d.costPrice),
        d.mrp != null ? _numStr(d.mrp!) : null,
        d.onlinePrice != null ? _numStr(d.onlinePrice!) : null,
        d.dealerPrice != null ? _numStr(d.dealerPrice!) : null,
        d.distributorPrice != null ? _numStr(d.distributorPrice!) : null,
        d.warranty,
        d.warrantyMonths?.toString(),
        ShopCsvWriter.boolStr(d.trackSerial),
        ShopCsvWriter.boolStr(d.trackBatch),
        d.shortDescription,
        d.description,
        d.technicalNotes,
        d.installationNotes,
        ShopCsvWriter.boolStr(d.isActive),
        '${d.qtyOnHand}',
        '${d.reorderLevel}',
        d.unit,
        d.stockStatus,
        ShopCsvWriter.boolStr(d.showInCalculator),
        calcFamilyName,
        '${d.calculatorPriority}',
        d.datasheetUrls.isEmpty ? null : ShopCsvWriter.pipeJoin(d.datasheetUrls),
        d.brochureUrls.isEmpty ? null : ShopCsvWriter.pipeJoin(d.brochureUrls),
        d.seo.slug,
        d.seo.seoTitle,
        d.seo.metaDescription,
      ];
    }).toList();
  }

  Future<List<List<String?>>> _exportProductAttributes() async {
    final rawRows = await _repo.listProductAttributeExportRows();
    final rows = <List<String?>>[];
    for (final map in rawRows) {
      final value = _attributeExportValue(map);
      if (value == null || value.isEmpty) continue;
      final sku = _nestedSku(map);
      final key = _nestedAttrKey(map);
      if (sku == null || key == null) continue;
      rows.add([sku, key, value]);
    }
    return rows;
  }

  String? _attributeExportValue(Map<String, dynamic> map) {
    final am = map['attribute_master'];
    final dataType = am is Map ? am['data_type'] as String? : null;
    final json = map['value_json'];
    if (json is List && json.isNotEmpty) {
      return dataType == AttributeDataType.multiSelect
          ? ShopCsvWriter.pipeJoin(json.map((e) => e.toString()))
          : json.first.toString();
    }
    final num = map['value_number'];
    if (num != null) return num.toString();
    final text = map['value_text'] as String?;
    if (text != null && text.trim().isNotEmpty) return text.trim();
    return null;
  }

  String? _nestedSku(Map<String, dynamic> map) {
    final p = map['products'];
    if (p is Map) return p['sku'] as String?;
    return null;
  }

  String? _nestedAttrKey(Map<String, dynamic> map) {
    final am = map['attribute_master'];
    if (am is Map) return am['key'] as String?;
    return null;
  }

  Future<List<List<String?>>> _exportSuppliers() async {
    final items = await _erpRepo.listSuppliers();
    return items
        .map((s) => [
              s.code,
              s.name,
              s.contactName,
              s.email,
              s.phone,
              s.gstin,
              ShopCsvWriter.boolStr(s.isActive),
            ])
        .toList();
  }

  Future<List<List<String?>>> _exportCustomers() async {
    final items = await _erpRepo.listCustomers();
    return items
        .map((c) => [
              c.code,
              c.name,
              c.email,
              c.phone,
              c.gstin,
              ShopCsvWriter.boolStr(c.isActive),
            ])
        .toList();
  }

  static String _numStr(double n) {
    if (n == n.roundToDouble()) return '${n.toInt()}';
    return n.toString();
  }
}

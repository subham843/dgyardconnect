import '../../admin/validation/shop_erp_validation.dart';
import '../../data/shop_catalog_repository.dart';
import '../../data/shop_erp_repository.dart';
import '../../data/supabase_repository_base.dart';
import '../../domain/attribute_data_type.dart';
import '../../domain/shop_attribute.dart';
import '../../domain/shop_category.dart';
import '../../domain/shop_product_detail.dart';
import '../../domain/shop_seo.dart';
import 'shop_bulk_import_issue.dart';
import 'shop_bulk_import_type.dart';
import 'shop_csv_parser.dart';

class ShopBulkImportRowResult {
  const ShopBulkImportRowResult({
    required this.rowNumber,
    required this.label,
    required this.success,
    this.message,
    this.issue,
    this.rowData,
  });

  final int rowNumber;
  final String label;
  final bool success;
  final String? message;
  final ShopBulkImportIssue? issue;
  final Map<String, String>? rowData;
}

class ShopBulkImportResult {
  const ShopBulkImportResult({
    required this.results,
    required this.created,
    required this.skipped,
    required this.failed,
  });

  final List<ShopBulkImportRowResult> results;
  final int created;
  final int skipped;
  final int failed;

  bool get hasResolvableIssues =>
      results.any((r) => !r.success && ShopBulkImportIssue.parseAll(r.message ?? '').isNotEmpty);

  List<ShopBulkImportRowResult> get resolvableFailures => results
      .where((r) => !r.success && ShopBulkImportIssue.parseAll(r.message ?? '').isNotEmpty)
      .toList();
}

class ShopBulkImportService {
  ShopBulkImportService({
    ShopCatalogRepository? repo,
    ShopErpRepository? erpRepo,
  })  : _repo = repo ?? ShopCatalogRepository(),
        _erpRepo = erpRepo ?? ShopErpRepository();

  final ShopCatalogRepository _repo;
  final ShopErpRepository _erpRepo;

  Future<ShopBulkImportResult> import({
    required ShopBulkImportType type,
    required String csvText,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final rows = ShopCsvParser.parseRows(csvText);
    return importParsedRows(type: type, rows: rows);
  }

  Future<ShopBulkImportResult> importParsedRows({
    required ShopBulkImportType type,
    required List<Map<String, String>> rows,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    if (rows.isEmpty) {
      return const ShopBulkImportResult(
        results: [ShopBulkImportRowResult(rowNumber: 0, label: 'CSV', success: false, message: 'No data rows found')],
        created: 0,
        skipped: 0,
        failed: 1,
      );
    }

    return switch (type) {
      ShopBulkImportType.categories => _importCategories(rows),
      ShopBulkImportType.attributeMaster => _importAttributeMaster(rows),
      ShopBulkImportType.attributeOptions => _importAttributeOptions(rows),
      ShopBulkImportType.attributeGroups => _importAttributeGroups(rows),
      ShopBulkImportType.brands => _importBrands(rows),
      ShopBulkImportType.subCategories => _importSubCategories(rows),
      ShopBulkImportType.products => _importProducts(rows),
      ShopBulkImportType.productAttributes => _importProductAttributes(rows),
      ShopBulkImportType.suppliers => _importSuppliers(rows),
      ShopBulkImportType.customers => _importCustomers(rows),
    };
  }

  Future<ShopBulkImportResult> _importCategories(List<Map<String, String>> rows) async {
    final existing = await _repo.listCategories(activeOnly: false);
    final seenSlugs = existing.map((c) => c.slug.toLowerCase()).toSet();
    final seenNames = existing.map((c) => c.name.toLowerCase()).toSet();
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final name = shopCsvOptional(row['name']);
      if (name == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '(empty)', success: false, message: 'name is required'));
        failed++;
        continue;
      }
      final slug = shopCsvOptional(row['slug'])?.toLowerCase() ?? SupabaseRepositoryBase.slugify(name);
      if (seenSlugs.contains(slug) || seenNames.contains(name.toLowerCase())) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Skipped — already exists'));
        skipped++;
        continue;
      }
      try {
        final id = await _repo.createCategory(
          name: name,
          sortOrder: shopCsvInt(row['sort_order']),
          seo: ShopSeoAdminInput(
            slugOverride: shopCsvOptional(row['slug']),
            seoTitle: shopCsvOptional(row['seo_title']),
            metaDescription: shopCsvOptional(row['meta_description']),
          ),
        );
        if (id == null) throw StateError('Insert failed');
        if (!shopCsvBool(row['is_active'])) {
          await _repo.updateCategory(id, name: name, isActive: false);
        }
        seenSlugs.add(slug);
        seenNames.add(name.toLowerCase());
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Created'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importAttributeMaster(List<Map<String, String>> rows) async {
    final existing = await _repo.listAttributeMaster(activeOnly: false);
    final seenKeys = existing.map((a) => a.key.toLowerCase()).toSet();
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final key = shopCsvOptional(row['key']);
      final label = shopCsvOptional(row['label']);
      if (key == null || label == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: key ?? label ?? '(empty)', success: false, message: 'key and label are required'));
        failed++;
        continue;
      }
      if (seenKeys.contains(key.toLowerCase())) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: key, success: true, message: 'Skipped — already exists'));
        skipped++;
        continue;
      }
      var dataType = shopCsvOptional(row['data_type']) ?? AttributeDataType.text;
      if (!AttributeDataType.all.contains(dataType)) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: key, success: false, message: 'Invalid data_type: $dataType'));
        failed++;
        continue;
      }
      try {
        final allowed = shopCsvPipeList(row['allowed_values']);
        final id = await _repo.createAttributeMaster(
          key: key,
          label: label,
          dataType: dataType,
          unit: shopCsvOptional(row['unit']),
          isRequired: shopCsvBool(row['is_required'], defaultValue: false),
          useInFilter: shopCsvBool(row['use_in_filter'], defaultValue: false),
          useInCalculator: shopCsvBool(row['use_in_calculator'], defaultValue: false),
          isActive: shopCsvBool(row['is_active']),
          allowedValues: allowed.isEmpty ? null : allowed,
        );
        if (id == null) throw StateError('Insert failed');
        seenKeys.add(key.toLowerCase());
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: key, success: true, message: 'Created'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: key, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importAttributeOptions(List<Map<String, String>> rows) async {
    final attrs = await _repo.listAttributeMaster(activeOnly: false);
    final attrIdByKey = {for (final a in attrs) a.key.toLowerCase(): a.id};
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final attrKey = shopCsvField(row, ['attribute_key', 'key']);
      final label = shopCsvOptional(row['label']);
      if (attrKey == null || label == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: attrKey ?? '(empty)', success: false, message: 'attribute_key and label are required'));
        failed++;
        continue;
      }
      final attrId = attrIdByKey[attrKey.toLowerCase()];
      if (attrId == null) {
        results.add(shopImportFail(rowNo: rowNo, label: label, message: 'Attribute not found: $attrKey', row: row));
        failed++;
        continue;
      }
      try {
        final existing = await _repo.listAttributeOptions(attrId);
        if (existing.any((o) => o.label.toLowerCase() == label.toLowerCase())) {
          results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '$attrKey → $label', success: true, message: 'Skipped — option exists'));
          skipped++;
          continue;
        }
        await _repo.createAttributeOption(
          attributeId: attrId,
          label: label,
          sortOrder: shopCsvInt(row['sort_order']),
        );
        if (!shopCsvBool(row['is_active'])) {
          final opts = await _repo.listAttributeOptions(attrId);
          final match = opts.where((o) => o.label.toLowerCase() == label.toLowerCase()).firstOrNull;
          if (match != null) {
            await _repo.updateAttributeOption(
              optionId: match.id,
              attributeId: attrId,
              label: label,
              isActive: false,
            );
          }
        }
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '$attrKey → $label', success: true, message: 'Created'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: label, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importAttributeGroups(List<Map<String, String>> rows) async {
    final groups = await _repo.listAttributeGroups();
    final attrs = await _repo.listAttributeMaster(activeOnly: false);
    final groupIdByName = {for (final g in groups) g.name.toLowerCase(): g.id};
    final attrIdByKey = {for (final a in attrs) a.key.toLowerCase(): a.id};
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final name = shopCsvOptional(row['group_name']) ?? shopCsvOptional(row['name']);
      if (name == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '(empty)', success: false, message: 'group_name is required'));
        failed++;
        continue;
      }
      try {
        final existed = groupIdByName.containsKey(name.toLowerCase());
        late final String groupId;
        if (existed) {
          groupId = groupIdByName[name.toLowerCase()]!;
        } else {
          final newId = await _repo.createAttributeGroup(
            name: name,
            description: shopCsvOptional(row['description']),
          );
          if (newId == null) throw StateError('Insert failed');
          groupId = newId;
          groupIdByName[name.toLowerCase()] = newId;
          created++;
        }

        final isActive = shopCsvBool(row['is_active']);
        if (!isActive) {
          await _repo.updateAttributeGroup(groupId, name: name, description: shopCsvOptional(row['description']), isActive: false);
        }

        final keys = shopCsvPipeList(row['attribute_keys']);
        final requiredKeys = shopCsvPipeList(row['required_attribute_keys']).map((e) => e.toLowerCase()).toSet();
        if (keys.isEmpty) {
          results.add(ShopBulkImportRowResult(
            rowNumber: rowNo,
            label: name,
            success: true,
            message: existed ? 'Group exists — no attributes to link' : 'Created (no attributes)',
          ));
          if (existed) skipped++;
          continue;
        }

        final links = <({String attributeId, int sortOrder, bool isRequired})>[];
        final missing = <String>[];
        for (var j = 0; j < keys.length; j++) {
          final attrId = attrIdByKey[keys[j].toLowerCase()];
          if (attrId == null) {
            missing.add(keys[j]);
            continue;
          }
          links.add((
            attributeId: attrId,
            sortOrder: j,
            isRequired: requiredKeys.contains(keys[j].toLowerCase()),
          ));
        }
        if (missing.isNotEmpty) {
          results.add(shopImportFail(
            rowNo: rowNo,
            label: name,
            message: 'Unknown attribute keys: ${missing.join(', ')}',
            row: row,
          ));
          failed++;
          continue;
        }
        await _repo.linkAttributesToGroup(groupId: groupId, links: links);
        results.add(ShopBulkImportRowResult(
          rowNumber: rowNo,
          label: name,
          success: true,
          message: existed ? 'Linked ${links.length} attribute(s) to existing group' : 'Created and linked ${links.length} attribute(s)',
        ));
        if (existed) skipped++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importBrands(List<Map<String, String>> rows) async {
    final existing = await _repo.listBrands();
    final seenNames = existing.map((b) => b.name.toLowerCase()).toSet();
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final name = shopCsvOptional(row['name']);
      if (name == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '(empty)', success: false, message: 'name is required'));
        failed++;
        continue;
      }
      if (seenNames.contains(name.toLowerCase())) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Skipped — already exists'));
        skipped++;
        continue;
      }
      try {
        await _repo.createBrand(name);
        if (!shopCsvBool(row['is_active'])) {
          final brands = await _repo.listBrands();
          final match = brands.where((b) => b.name.toLowerCase() == name.toLowerCase()).firstOrNull;
          if (match != null) await _repo.updateBrand(match.id, name: name, isActive: false);
        }
        seenNames.add(name.toLowerCase());
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Created'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importSubCategories(List<Map<String, String>> rows) async {
    final categories = await _repo.listCategories(activeOnly: false);
    final catBySlug = {for (final c in categories) c.slug.toLowerCase(): c};
    final catByName = {for (final c in categories) c.name.toLowerCase(): c};
    final groups = await _repo.listAttributeGroups();
    final groupByName = {for (final g in groups) g.name.toLowerCase(): g.id};
    final allSubs = await _repo.listAllSubCategories();
    final subKey = <String>{for (final s in allSubs) '${s.categoryId}|${s.slug.toLowerCase()}'};
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final name = shopCsvOptional(row['name']);
      final catRef = shopCsvField(row, ['category_slug', 'category_name']);
      if (name == null || catRef == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name ?? '(empty)', success: false, message: 'name and category_slug are required'));
        failed++;
        continue;
      }
      final cat = catBySlug[catRef.toLowerCase()] ?? catByName[catRef.toLowerCase()];
      if (cat == null) {
        results.add(shopImportFail(rowNo: rowNo, label: name, message: 'Category not found: $catRef', row: row));
        failed++;
        continue;
      }
      final gst = shopCsvGstField(row);
      final gstErr = ShopErpValidation.gstPercentage(gst);
      if (gstErr != null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: gstErr));
        failed++;
        continue;
      }
      final hsn = shopCsvHsnField(row);
      final hsnErr = ShopErpValidation.hsnCode(hsn);
      if (hsnErr != null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: hsnErr));
        failed++;
        continue;
      }
      final slug = shopCsvOptional(row['slug'])?.toLowerCase() ?? SupabaseRepositoryBase.slugify(name);
      final dupKey = '${cat.id}|$slug';
      if (subKey.contains(dupKey)) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Skipped — already exists'));
        skipped++;
        continue;
      }
      final groupNames = shopCsvPipeList(row['attribute_group_names']);
      final groupIds = <String>[];
      final missingGroups = <String>[];
      for (final gn in groupNames) {
        final gid = groupByName[gn.toLowerCase()];
        if (gid == null) {
          missingGroups.add(gn);
        } else {
          groupIds.add(gid);
        }
      }
      if (missingGroups.isNotEmpty) {
        results.add(shopImportFail(
          rowNo: rowNo,
          label: name,
          message: 'Unknown attribute groups: ${missingGroups.join(', ')}',
          row: row,
        ));
        failed++;
        continue;
      }
      try {
        final id = await _repo.createSubCategory(
          categoryId: cat.id,
          name: name,
          description: shopCsvOptional(row['description']),
          sortOrder: shopCsvInt(row['sort_order']),
          isActive: shopCsvBool(row['is_active']),
          defaultGstPercentage: gst,
          defaultHsnCode: hsn,
          categorySlug: cat.slug,
          attributeGroupIds: groupIds,
          seo: ShopSeoAdminInput(
            slugOverride: shopCsvOptional(row['slug']),
            seoTitle: shopCsvOptional(row['seo_title']),
            metaDescription: shopCsvOptional(row['meta_description']),
          ),
        );
        if (id == null) throw StateError('Insert failed');
        subKey.add(dupKey);
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Created (image: upload separately in editor)'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importProducts(List<Map<String, String>> rows) async {
    final categories = await _repo.listCategories(activeOnly: false);
    final subs = await _repo.listAllSubCategories();
    final subByKey = <String, ShopSubCategory>{};
    for (final s in subs) {
      subByKey[s.slug.toLowerCase()] = s;
      final cat = categories.where((c) => c.id == s.categoryId).firstOrNull;
      if (cat != null) {
        subByKey['${cat.slug.toLowerCase()}|${s.slug.toLowerCase()}'] = s;
      }
    }
    final brands = await _repo.listBrands();
    final brandByName = {for (final b in brands) b.name.toLowerCase(): b.id};
    final calcFamilies = await _repo.listCalculatorFamilies();
    final calcFamilyByName = {for (final f in calcFamilies) f.name.toLowerCase(): f.id};
    final existingProducts = await _repo.listProductsAdmin(limit: 5000);
    final seenSkus = existingProducts.map((p) => p.sku.toLowerCase()).toSet();

    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final name = shopCsvOptional(row['name']);
      final catSlug = shopCsvOptional(row['category_slug']);
      final subSlug = shopCsvOptional(row['sub_category_slug']);
      if (name == null || subSlug == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name ?? '(empty)', success: false, message: 'name and sub_category_slug are required'));
        failed++;
        continue;
      }
      final sub = _resolveSubCategory(subByKey, catSlug, subSlug);
      if (sub == null) {
        results.add(shopImportFail(rowNo: rowNo, label: name, message: 'Sub category not found: $subSlug', row: row));
        failed++;
        continue;
      }
      var sku = shopCsvOptional(row['sku']) ?? SupabaseRepositoryBase.slugify(name);
      if (sku.isEmpty) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: 'Could not derive SKU — add sku column'));
        failed++;
        continue;
      }
      final skuErr = ShopErpValidation.sku(sku);
      if (skuErr != null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: skuErr));
        failed++;
        continue;
      }
      if (seenSkus.contains(sku.toLowerCase())) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Skipped — SKU already exists'));
        skipped++;
        continue;
      }
      String? brandId;
      final brandName = shopCsvOptional(row['brand_name']);
      if (brandName != null) {
        brandId = brandByName[brandName.toLowerCase()];
        if (brandId == null) {
          results.add(shopImportFail(rowNo: rowNo, label: name, message: 'Brand not found: $brandName', row: row));
          failed++;
          continue;
        }
      }

      final useGstOverride = shopCsvBool(row['use_gst_override'], defaultValue: false);
      final hasGstCol = shopCsvField(row, ['gst_percentage', 'gst_percent', 'tax_percentage', 'gst']) != null;
      final taxPct = useGstOverride || hasGstCol
          ? shopCsvGstField(row, defaultValue: sub.defaultGstPercentage)
          : sub.defaultGstPercentage;
      final gstErr = ShopErpValidation.gstPercentage(taxPct);
      if (gstErr != null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: gstErr));
        failed++;
        continue;
      }

      final hsn = shopCsvHsnField(row) ?? sub.defaultHsnCode;
      final hsnErr = ShopErpValidation.hsnCode(hsn);
      if (hsnErr != null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: hsnErr));
        failed++;
        continue;
      }

      String? calcFamilyId;
      final calcFamilyIds = <String>[];
      final calcFamilyName = shopCsvOptional(row['calculator_family_name']);
      final showInCalc = shopCsvBool(row['show_in_calculator'], defaultValue: false);
      if (showInCalc) {
        if (calcFamilyName == null) {
          results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: 'calculator_family_name required when show_in_calculator is true'));
          failed++;
          continue;
        }
        // Support multi: "HD CCTV, IP CCTV, Computer Assemble"
        final names = calcFamilyName
            .split(RegExp(r'[,|;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        var missing = false;
        for (final n in names) {
          final id = calcFamilyByName[n.toLowerCase()];
          if (id == null) {
            results.add(shopImportFail(
              rowNo: rowNo,
              label: name,
              message: 'Calculator family not found: $n',
              row: row,
            ));
            failed++;
            missing = true;
            break;
          }
          calcFamilyIds.add(id);
        }
        if (missing) continue;
        calcFamilyId = calcFamilyIds.isNotEmpty ? calcFamilyIds.first : null;
      }

      try {
        final online = shopCsvDouble(row['online_price']);
        final selling = shopCsvDouble(row['selling_price']);
        final effectiveOnline = online > 0 ? online : (selling > 0 ? selling : null);
        final detail = ShopProductDetail(
          id: '',
          subCategoryId: sub.id,
          categoryId: sub.categoryId,
          brandId: brandId,
          sku: sku,
          name: name,
          barcode: shopCsvOptional(row['barcode']),
          modelName: shopCsvOptional(row['model_name']),
          hsnCode: hsn,
          taxPercentage: taxPct,
          useGstOverride: useGstOverride,
          taxClass: shopCsvOptional(row['tax_class']),
          warranty: shopCsvOptional(row['warranty']),
          warrantyMonths: shopCsvOptionalInt(row['warranty_months']),
          trackSerial: shopCsvBool(row['track_serial'], defaultValue: false),
          trackBatch: shopCsvBool(row['track_batch'], defaultValue: false),
          description: shopCsvOptional(row['description']),
          shortDescription: shopCsvOptional(row['short_description']),
          technicalNotes: shopCsvOptional(row['technical_notes']),
          installationNotes: shopCsvOptional(row['installation_notes']),
          costPrice: shopCsvDouble(row['cost_price']),
          sellingPrice: effectiveOnline ?? 0,
          mrp: shopCsvOptional(row['mrp']) != null ? shopCsvDouble(row['mrp']) : null,
          onlinePrice: effectiveOnline,
          dealerPrice: shopCsvOptional(row['dealer_price']) != null ? shopCsvDouble(row['dealer_price']) : null,
          distributorPrice: shopCsvOptional(row['distributor_price']) != null ? shopCsvDouble(row['distributor_price']) : null,
          isActive: shopCsvBool(row['is_active']),
          qtyOnHand: shopCsvInt(row['qty_on_hand']),
          reorderLevel: shopCsvInt(row['reorder_level']),
          unit: shopCsvOptional(row['unit']) ?? 'pcs',
          stockStatus: shopCsvOptional(row['stock_status']) ?? 'in_stock',
          datasheetUrls: shopCsvPipeList(row['datasheet_urls']),
          brochureUrls: shopCsvPipeList(row['brochure_urls']),
          documentUrls: [
            ...shopCsvPipeList(row['document_urls']),
            ...shopCsvPipeList(row['datasheet_urls']),
            ...shopCsvPipeList(row['brochure_urls']),
          ],
          seo: ShopSeoResolved(
            slug: shopCsvOptional(row['slug']) ?? sku,
            seoTitle: shopCsvOptional(row['seo_title']),
            metaDescription: shopCsvOptional(row['seo_description']) ?? shopCsvOptional(row['meta_description']),
          ),
          showInCalculator: showInCalc,
          calculatorFamilyId: calcFamilyId,
          calculatorFamilyIds: calcFamilyIds,
          calculatorPriority: shopCsvInt(row['calculator_priority']),
        );
        final productId = await _repo.saveProductDetail(detail);
        if (productId == null) throw StateError('Insert failed');
        seenSkus.add(sku.toLowerCase());
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: true, message: 'Created'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: name, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importProductAttributes(List<Map<String, String>> rows) async {
    final products = await _repo.listProductsAdmin(limit: 5000, lightSelect: false);
    final productBySku = {
      for (final p in products) p.sku.toLowerCase(): (id: p.id, subCategoryId: p.subCategoryId),
    };
    final attrs = await _repo.listAttributeMaster(activeOnly: false);
    final attrByKey = {for (final a in attrs) a.key.toLowerCase(): a};
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final sku = shopCsvField(row, ['product_sku', 'sku']);
      final attrKey = shopCsvField(row, ['attribute_key', 'key']);
      final value = shopCsvField(row, ['value', 'attribute_value']);
      if (sku == null || attrKey == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: sku ?? '(empty)', success: false, message: 'product_sku and attribute_key are required'));
        failed++;
        continue;
      }
      if (value == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '$sku → $attrKey', success: true, message: 'Skipped — empty value'));
        skipped++;
        continue;
      }
      final product = productBySku[sku.toLowerCase()];
      if (product == null) {
        results.add(shopImportFail(rowNo: rowNo, label: sku, message: 'Product not found for SKU: $sku', row: row));
        failed++;
        continue;
      }
      final master = attrByKey[attrKey.toLowerCase()];
      if (master == null) {
        results.add(shopImportFail(rowNo: rowNo, label: attrKey, message: 'Attribute not found: $attrKey', row: row));
        failed++;
        continue;
      }
      try {
        final attrRows = await _repo.listProductAttributeValues(product.id);
        final match = attrRows.where((r) => r.master.id == master.id).firstOrNull;
        if (match == null) {
          await _repo.ensureProductAttributesForSubCategory(product.id, product.subCategoryId);
          final refreshed = await _repo.listProductAttributeValues(product.id);
          final retry = refreshed.where((r) => r.master.id == master.id).firstOrNull;
          if (retry == null) {
            results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '$sku → $attrKey', success: false, message: 'Attribute not linked to product sub-category'));
            failed++;
            continue;
          }
          await _saveAttributeValue(retry, master, value);
        } else {
          await _saveAttributeValue(match, master, value);
        }
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '$sku → $attrKey', success: true, message: 'Saved'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: '$sku → $attrKey', success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<void> _saveAttributeValue(ShopProductAttributeValue row, ShopAttributeMaster master, String value) async {
    switch (master.dataType) {
      case AttributeDataType.number:
        await _repo.updateProductAttribute(
          row.id,
          valueNumber: double.tryParse(value),
          clearNumber: double.tryParse(value) == null,
          clearJson: true,
        );
      case AttributeDataType.boolean:
        await _repo.updateProductAttribute(
          row.id,
          valueText: shopCsvBool(value) ? 'true' : 'false',
          clearNumber: true,
          clearJson: true,
        );
      case AttributeDataType.multiSelect:
        final list = shopCsvPipeList(value);
        await _repo.updateProductAttribute(
          row.id,
          valueJson: list,
          valueText: list.join(', '),
          clearNumber: true,
        );
      default:
        await _repo.updateProductAttribute(
          row.id,
          valueText: value,
          clearNumber: true,
          clearJson: true,
        );
    }
  }

  Future<ShopBulkImportResult> _importSuppliers(List<Map<String, String>> rows) async {
    final existing = await _erpRepo.listSuppliers();
    final seenCodes = existing.map((s) => s.code.toLowerCase()).toSet();
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final code = shopCsvOptional(row['code']);
      final name = shopCsvOptional(row['name']);
      if (code == null || name == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code ?? '(empty)', success: false, message: 'code and name are required'));
        failed++;
        continue;
      }
      if (seenCodes.contains(code.toLowerCase())) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code, success: true, message: 'Skipped — code exists'));
        skipped++;
        continue;
      }
      try {
        final id = await _erpRepo.createSupplier(
          code: code,
          name: name,
          contactName: shopCsvOptional(row['contact_name']),
          email: shopCsvOptional(row['email']),
          phone: shopCsvOptional(row['phone']),
          gstin: shopCsvOptional(row['gstin']),
        );
        if (id == null) throw StateError('Insert failed');
        seenCodes.add(code.toLowerCase());
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code, success: true, message: 'Created'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  Future<ShopBulkImportResult> _importCustomers(List<Map<String, String>> rows) async {
    final existing = await _erpRepo.listCustomers();
    final seenCodes = existing.map((c) => c.code.toLowerCase()).toSet();
    final results = <ShopBulkImportRowResult>[];
    var created = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNo = i + 2;
      final code = shopCsvOptional(row['code']);
      final name = shopCsvOptional(row['name']);
      if (code == null || name == null) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code ?? '(empty)', success: false, message: 'code and name are required'));
        failed++;
        continue;
      }
      if (seenCodes.contains(code.toLowerCase())) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code, success: true, message: 'Skipped — code exists'));
        skipped++;
        continue;
      }
      try {
        final id = await _erpRepo.createCustomer(
          code: code,
          name: name,
          email: shopCsvOptional(row['email']),
          phone: shopCsvOptional(row['phone']),
          gstin: shopCsvOptional(row['gstin']),
        );
        if (id == null) throw StateError('Insert failed');
        seenCodes.add(code.toLowerCase());
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code, success: true, message: 'Created'));
        created++;
      } catch (e) {
        results.add(ShopBulkImportRowResult(rowNumber: rowNo, label: code, success: false, message: '$e'));
        failed++;
      }
    }
    return ShopBulkImportResult(results: results, created: created, skipped: skipped, failed: failed);
  }

  ShopSubCategory? _resolveSubCategory(
    Map<String, ShopSubCategory> subByKey,
    String? catSlug,
    String subSlug,
  ) {
    if (catSlug != null) {
      final composite = subByKey['${catSlug.toLowerCase()}|${subSlug.toLowerCase()}'];
      if (composite != null) return composite;
    }
    return subByKey[subSlug.toLowerCase()];
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

ShopBulkImportRowResult shopImportFail({
  required int rowNo,
  required String label,
  required String message,
  Map<String, String>? row,
}) {
  return ShopBulkImportRowResult(
    rowNumber: rowNo,
    label: label,
    success: false,
    message: message,
    issue: ShopBulkImportIssue.fromMessage(message),
    rowData: row == null ? null : Map<String, String>.from(row),
  );
}

import '../../../calculator/data/calculator_repository.dart';
import '../../data/shop_catalog_repository.dart';
import '../../domain/attribute_data_type.dart';
import '../../data/supabase_repository_base.dart';
import 'shop_bulk_import_issue.dart';
import 'shop_bulk_import_service.dart';
import 'shop_bulk_import_type.dart';
import 'shop_csv_parser.dart';

class ShopBulkImportRetryOutcome {
  const ShopBulkImportRetryOutcome({required this.result, required this.patchedRows});

  final ShopBulkImportResult result;
  final List<Map<String, String>> patchedRows;
}

class ShopBulkImportResolver {
  ShopBulkImportResolver({
    ShopCatalogRepository? catalogRepo,
    CalculatorRepository? calculatorRepo,
    ShopBulkImportService? importService,
  })  : _catalog = catalogRepo ?? ShopCatalogRepository(),
        _calculator = calculatorRepo ?? CalculatorRepository(),
        _importService = importService ?? ShopBulkImportService();

  final ShopCatalogRepository _catalog;
  final CalculatorRepository _calculator;
  final ShopBulkImportService _importService;

  Future<Map<ShopBulkImportIssueKind, List<ShopBulkImportReferenceOption>>> loadAllReferenceOptions() async {
    final categories = await _catalog.listCategories(activeOnly: false);
    final catById = {for (final c in categories) c.id: c};
    final subs = await _catalog.listAllSubCategories(activeOnly: false);
    final brands = await _catalog.listBrands();
    final attrs = await _catalog.listAttributeMaster(activeOnly: false);
    final groups = await _catalog.listAttributeGroups();
    final products = await _catalog.listProductsAdmin(limit: 5000);
    final calcFamilies = await _catalog.listCalculatorFamilies();

    return {
      ShopBulkImportIssueKind.category: [
        for (final c in categories)
          ShopBulkImportReferenceOption(id: c.id, label: c.name, csvValue: c.slug),
      ],
      ShopBulkImportIssueKind.subCategory: [
        for (final s in subs)
          ShopBulkImportReferenceOption(
            id: s.id,
            label: '${catById[s.categoryId]?.name ?? "?"} › ${s.name} (${s.slug})',
            csvValue: s.slug,
          ),
      ],
      ShopBulkImportIssueKind.brand: [
        for (final b in brands) ShopBulkImportReferenceOption(id: b.id, label: b.name, csvValue: b.name),
      ],
      ShopBulkImportIssueKind.attribute: [
        for (final a in attrs) ShopBulkImportReferenceOption(id: a.id, label: a.label, csvValue: a.key),
      ],
      ShopBulkImportIssueKind.attributeGroup: [
        for (final g in groups) ShopBulkImportReferenceOption(id: g.id, label: g.name, csvValue: g.name),
      ],
      ShopBulkImportIssueKind.productSku: [
        for (final p in products) ShopBulkImportReferenceOption(id: p.id, label: '${p.sku} — ${p.name}', csvValue: p.sku),
      ],
      ShopBulkImportIssueKind.calculatorFamily: [
        for (final f in calcFamilies) ShopBulkImportReferenceOption(id: f.id, label: f.name, csvValue: f.name),
      ],
    };
  }

  /// Creates missing master data, then patches [rows] and re-imports.
  Future<ShopBulkImportRetryOutcome> applyFixesAndRetry({
    required ShopBulkImportType type,
    required List<Map<String, String>> rows,
    required List<ShopBulkImportFixAction> fixes,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();

    final patched = rows.map((r) => Map<String, String>.from(r)).toList();
    final sortedFixes = [...fixes]..sort((a, b) => _fixKindOrder(a.issue.kind).compareTo(_fixKindOrder(b.issue.kind)));
    for (final fix in sortedFixes) {
      if (!fix.isReady) continue;
      if (fix.mode == ShopBulkImportFixMode.createNew) {
        await _ensureEntityExists(fix, patched);
      }
      final csvValue = fix.mode == ShopBulkImportFixMode.mapExisting
          ? fix.existingCsvValue!.trim()
          : await _lookupCreatedCsvValue(fix);
      if (csvValue.isEmpty) continue;
      _applyFixToRows(patched, fix, csvValue);
    }

    await _syncProductRowCategorySlugs(patched);

    final result = await _importService.importParsedRows(type: type, rows: patched);
    return ShopBulkImportRetryOutcome(result: result, patchedRows: patched);
  }

  int _fixKindOrder(ShopBulkImportIssueKind kind) => switch (kind) {
        ShopBulkImportIssueKind.category => 0,
        ShopBulkImportIssueKind.attribute => 1,
        ShopBulkImportIssueKind.attributeGroup => 1,
        ShopBulkImportIssueKind.subCategory => 2,
        ShopBulkImportIssueKind.brand => 3,
        ShopBulkImportIssueKind.calculatorFamily => 4,
        ShopBulkImportIssueKind.productSku => 5,
      };

  /// Align category_slug with sub_category_slug so product import composite lookup succeeds.
  Future<void> _syncProductRowCategorySlugs(List<Map<String, String>> rows) async {
    final subs = await _catalog.listAllSubCategories(activeOnly: false);
    final cats = await _catalog.listCategories(activeOnly: false);
    final catById = {for (final c in cats) c.id: c};

    for (final row in rows) {
      if (shopCsvOptional(row['name']) == null && shopCsvOptional(row['product_sku']) == null) continue;
      final subSlug = shopCsvOptional(row['sub_category_slug']);
      if (subSlug == null) continue;
      final sub = subs
          .where((s) => s.slug.toLowerCase() == subSlug.toLowerCase() || s.name.toLowerCase() == subSlug.toLowerCase())
          .firstOrNull;
      if (sub == null) continue;
      final cat = catById[sub.categoryId];
      if (cat == null) continue;
      row['sub_category_slug'] = sub.slug;
      row['category_slug'] = cat.slug;
      row['category_name'] = cat.name;
    }
  }

  Future<void> _ensureEntityExists(ShopBulkImportFixAction fix, List<Map<String, String>> rows) async {
    if (fix.mode != ShopBulkImportFixMode.createNew) return;
    if (!fix.issue.kind.supportsCreateNew) return;

    final name = fix.resolvedCsvValue;
    switch (fix.issue.kind) {
      case ShopBulkImportIssueKind.category:
        await _catalog.createCategory(name: name);
      case ShopBulkImportIssueKind.brand:
        await _catalog.createBrand(name);
      case ShopBulkImportIssueKind.attribute:
        await _catalog.createAttributeMaster(
          key: SupabaseRepositoryBase.slugify(name),
          label: name,
          dataType: AttributeDataType.text,
        );
      case ShopBulkImportIssueKind.attributeGroup:
        await _catalog.createAttributeGroup(name: name);
      case ShopBulkImportIssueKind.calculatorFamily:
        await _calculator.createFamily(name: name);
      case ShopBulkImportIssueKind.subCategory:
        Map<String, String>? matchingRow;
        for (final r in rows) {
          if (_rowMatchesIssue(r, fix.issue)) {
            matchingRow = r;
            break;
          }
        }
        if (matchingRow == null) break;
        final catRef = shopCsvField(matchingRow, ['category_slug', 'category_name']);
        if (catRef == null) break;
        final categories = await _catalog.listCategories(activeOnly: false);
        final cat = categories
            .where((c) =>
                c.slug.toLowerCase() == catRef.toLowerCase() || c.name.toLowerCase() == catRef.toLowerCase())
            .firstOrNull;
        if (cat == null) break;
        await _catalog.createSubCategory(
          categoryId: cat.id,
          name: name,
          categorySlug: cat.slug,
        );
      case ShopBulkImportIssueKind.productSku:
        break;
    }
  }

  Future<String> _lookupCreatedCsvValue(ShopBulkImportFixAction fix) async {
    final name = fix.resolvedCsvValue;
    switch (fix.issue.kind) {
      case ShopBulkImportIssueKind.category:
        final cats = await _catalog.listCategories(activeOnly: false);
        return cats
                .where((c) => c.name.toLowerCase() == name.toLowerCase())
                .map((c) => c.slug)
                .firstOrNull ??
            SupabaseRepositoryBase.slugify(name);
      case ShopBulkImportIssueKind.subCategory:
        final subs = await _catalog.listAllSubCategories(activeOnly: false);
        return subs
                .where((s) => s.name.toLowerCase() == name.toLowerCase() || s.slug.toLowerCase() == name.toLowerCase())
                .map((s) => s.slug)
                .firstOrNull ??
            SupabaseRepositoryBase.slugify(name);
      case ShopBulkImportIssueKind.brand:
        return name;
      case ShopBulkImportIssueKind.attribute:
        final attrs = await _catalog.listAttributeMaster(activeOnly: false);
        return attrs
                .where((a) => a.label.toLowerCase() == name.toLowerCase() || a.key.toLowerCase() == name.toLowerCase())
                .map((a) => a.key)
                .firstOrNull ??
            SupabaseRepositoryBase.slugify(name);
      case ShopBulkImportIssueKind.attributeGroup:
        final groups = await _catalog.listAttributeGroups();
        return groups.where((g) => g.name.toLowerCase() == name.toLowerCase()).map((g) => g.name).firstOrNull ?? name;
      case ShopBulkImportIssueKind.calculatorFamily:
        final families = await _catalog.listCalculatorFamilies();
        return families.where((f) => f.name.toLowerCase() == name.toLowerCase()).map((f) => f.name).firstOrNull ?? name;
      case ShopBulkImportIssueKind.productSku:
        return name;
    }
  }

  void _applyFixToRows(List<Map<String, String>> rows, ShopBulkImportFixAction fix, String replacement) {
    final issue = fix.issue;

    for (final row in rows) {
      if (!_rowMatchesIssue(row, issue)) continue;
      _patchRow(row, issue, replacement);
    }
  }

  bool _rowMatchesIssue(Map<String, String> row, ShopBulkImportIssue issue) {
    for (final col in issue.kind.csvColumns) {
      final val = shopCsvOptional(row[col]);
      if (val == null) continue;
      if (issue.pipeSeparated) {
        final parts = shopCsvPipeList(val);
        if (parts.any((p) => p.toLowerCase() == issue.missingValue.toLowerCase())) return true;
      } else if (val.toLowerCase() == issue.missingValue.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  void _patchRow(Map<String, String> row, ShopBulkImportIssue issue, String replacement) {
    for (final col in issue.kind.csvColumns) {
      final val = shopCsvOptional(row[col]);
      if (val == null) continue;

      if (issue.pipeSeparated) {
        final parts = shopCsvPipeList(val);
        final patched = [
          for (final p in parts)
            if (p.toLowerCase() == issue.missingValue.toLowerCase()) replacement else p,
        ];
        row[col] = patched.join('|');
        return;
      }

      if (val.toLowerCase() == issue.missingValue.toLowerCase()) {
        row[col] = replacement;
        if (issue.kind == ShopBulkImportIssueKind.category && col == 'category_slug') {
          row['category_name'] = replacement;
        }
        return;
      }
    }
  }

  /// Unique resolvable issues from import result (bulk mode grouping).
  List<ShopBulkImportServiceGroup> groupResolvableIssues(ShopBulkImportResult result) {
    final map = <String, ShopBulkImportServiceGroup>{};
    for (final r in result.resolvableFailures) {
      final issues = r.message == null ? const <ShopBulkImportIssue>[] : ShopBulkImportIssue.parseAll(r.message!);
      for (final issue in issues) {
        final existing = map[issue.key];
        if (existing == null) {
          map[issue.key] = ShopBulkImportServiceGroup(issue: issue, rowNumbers: [r.rowNumber]);
        } else if (!existing.rowNumbers.contains(r.rowNumber)) {
          map[issue.key] = ShopBulkImportServiceGroup(
            issue: issue,
            rowNumbers: [...existing.rowNumbers, r.rowNumber],
          );
        }
      }
    }
    return map.values.toList()..sort((a, b) => a.issue.kind.label.compareTo(b.issue.kind.label));
  }
}

extension _FirstOrNullResolver<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

class ShopBulkImportServiceGroup {
  const ShopBulkImportServiceGroup({required this.issue, required this.rowNumbers});

  final ShopBulkImportIssue issue;
  final List<int> rowNumbers;
}

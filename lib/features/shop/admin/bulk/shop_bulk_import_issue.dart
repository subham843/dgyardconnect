enum ShopBulkImportIssueKind {
  category,
  subCategory,
  brand,
  attribute,
  attributeGroup,
  productSku,
  calculatorFamily,
}

extension ShopBulkImportIssueKindX on ShopBulkImportIssueKind {
  String get label => switch (this) {
        ShopBulkImportIssueKind.category => 'Category',
        ShopBulkImportIssueKind.subCategory => 'Sub category',
        ShopBulkImportIssueKind.brand => 'Brand',
        ShopBulkImportIssueKind.attribute => 'Attribute',
        ShopBulkImportIssueKind.attributeGroup => 'Attribute group',
        ShopBulkImportIssueKind.productSku => 'Product SKU',
        ShopBulkImportIssueKind.calculatorFamily => 'Calculator family',
      };

  /// CSV column headers to patch when mapping or after create.
  List<String> get csvColumns => switch (this) {
        ShopBulkImportIssueKind.category => ['category_slug', 'category_name'],
        ShopBulkImportIssueKind.subCategory => ['sub_category_slug'],
        ShopBulkImportIssueKind.brand => ['brand_name'],
        ShopBulkImportIssueKind.attribute => ['attribute_key', 'key'],
        ShopBulkImportIssueKind.attributeGroup => ['attribute_group_names'],
        ShopBulkImportIssueKind.productSku => ['product_sku', 'sku'],
        ShopBulkImportIssueKind.calculatorFamily => ['calculator_family_name'],
      };

  bool get supportsCreateNew => this != ShopBulkImportIssueKind.productSku;
}

class ShopBulkImportIssue {
  const ShopBulkImportIssue({
    required this.kind,
    required this.missingValue,
    this.pipeSeparated = false,
  });

  final ShopBulkImportIssueKind kind;
  final String missingValue;
  final bool pipeSeparated;

  String get key => '${kind.name}|${missingValue.toLowerCase()}';

  static List<ShopBulkImportIssue> parseAll(String message) {
    if (message.startsWith('Unknown attribute keys:')) {
      final rest = message.substring('Unknown attribute keys:'.length).trim();
      return [
        for (final part in rest.split(','))
          if (part.trim().isNotEmpty)
            ShopBulkImportIssue(
              kind: ShopBulkImportIssueKind.attribute,
              missingValue: part.trim(),
              pipeSeparated: true,
            ),
      ];
    }
    if (message.startsWith('Unknown attribute groups:')) {
      final rest = message.substring('Unknown attribute groups:'.length).trim();
      return [
        for (final part in rest.split(','))
          if (part.trim().isNotEmpty)
            ShopBulkImportIssue(
              kind: ShopBulkImportIssueKind.attributeGroup,
              missingValue: part.trim(),
              pipeSeparated: true,
            ),
      ];
    }
    final single = fromMessage(message);
    return single == null ? const [] : [single];
  }

  static ShopBulkImportIssue? fromMessage(String message) {
    String? extract(String prefix) {
      if (!message.startsWith(prefix)) return null;
      return message.substring(prefix.length).trim();
    }

    final category = extract('Category not found:');
    if (category != null) {
      return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.category, missingValue: category);
    }
    final sub = extract('Sub category not found:');
    if (sub != null) {
      return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.subCategory, missingValue: sub);
    }
    final brand = extract('Brand not found:');
    if (brand != null) {
      return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.brand, missingValue: brand);
    }
    final attr = extract('Attribute not found:');
    if (attr != null) {
      return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.attribute, missingValue: attr);
    }
    final calc = extract('Calculator family not found:');
    if (calc != null) {
      return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.calculatorFamily, missingValue: calc);
    }
    final sku = extract('Product not found for SKU:');
    if (sku != null) {
      return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.productSku, missingValue: sku);
    }

    if (message.startsWith('Unknown attribute keys:')) {
      final rest = message.substring('Unknown attribute keys:'.length).trim();
      final first = rest.split(',').map((e) => e.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
      if (first.isNotEmpty) {
        return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.attribute, missingValue: first, pipeSeparated: true);
      }
    }
    if (message.startsWith('Unknown attribute groups:')) {
      final rest = message.substring('Unknown attribute groups:'.length).trim();
      final first = rest.split(',').map((e) => e.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
      if (first.isNotEmpty) {
        return ShopBulkImportIssue(kind: ShopBulkImportIssueKind.attributeGroup, missingValue: first, pipeSeparated: true);
      }
    }
    return null;
  }
}

enum ShopBulkImportFixMode { mapExisting, createNew }

class ShopBulkImportFixAction {
  const ShopBulkImportFixAction({
    required this.issue,
    required this.mode,
    this.existingCsvValue,
    this.newName,
  });

  final ShopBulkImportIssue issue;
  final ShopBulkImportFixMode mode;
  final String? existingCsvValue;
  final String? newName;

  bool get isReady => switch (mode) {
        ShopBulkImportFixMode.mapExisting => (existingCsvValue ?? '').trim().isNotEmpty,
        ShopBulkImportFixMode.createNew => effectiveNewName.isNotEmpty,
      };

  String get effectiveNewName {
    final typed = newName?.trim();
    if (typed != null && typed.isNotEmpty) return typed;
    return issue.missingValue.trim();
  }

  String get resolvedCsvValue => switch (mode) {
        ShopBulkImportFixMode.mapExisting => existingCsvValue!.trim(),
        ShopBulkImportFixMode.createNew => effectiveNewName,
      };
}

class ShopBulkImportReferenceOption {
  const ShopBulkImportReferenceOption({
    required this.id,
    required this.label,
    required this.csvValue,
  });

  final String id;
  final String label;
  final String csvValue;
}

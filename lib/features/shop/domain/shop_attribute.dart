import '../data/supabase_repository_base.dart';
import 'attribute_data_type.dart';

class ShopAttributeOption {
  const ShopAttributeOption({
    required this.id,
    required this.attributeId,
    required this.label,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String attributeId;
  final String label;
  final int sortOrder;
  final bool isActive;

  factory ShopAttributeOption.fromRow(Map<String, dynamic> row) {
    return ShopAttributeOption(
      id: row['id'] as String,
      attributeId: row['attribute_id'] as String,
      label: row['label'] as String? ?? '',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

class ShopAttributeMaster {
  const ShopAttributeMaster({
    required this.id,
    required this.key,
    required this.label,
    required this.dataType,
    this.unit,
    this.allowedValues,
    this.options = const [],
    required this.isRequired,
    required this.useInFilter,
    required this.useInCalculator,
    required this.isActive,
  });

  final String id;
  final String key;
  final String label;
  final String dataType;
  final String? unit;
  final List<String>? allowedValues;
  final List<ShopAttributeOption> options;
  final bool isRequired;
  final bool useInFilter;
  final bool useInCalculator;
  final bool isActive;

  List<String> get effectiveOptions {
    if (options.isNotEmpty) {
      return options.where((o) => o.isActive).map((o) => o.label).toList();
    }
    return allowedValues ?? const [];
  }

  bool get hasSelectableOptions => AttributeDataType.hasOptions(dataType);

  factory ShopAttributeMaster.fromRow(Map<String, dynamic> row) {
    final av = row['allowed_values'];
    List<String>? values;
    if (av is List) {
      values = av.map((e) => e.toString()).toList();
    }

    List<ShopAttributeOption> opts = const [];
    final nested = row['attribute_options'];
    if (nested is List) {
      opts = nested
          .map((e) => ShopAttributeOption.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return ShopAttributeMaster(
      id: row['id'] as String,
      key: row['key'] as String? ?? '',
      label: row['label'] as String? ?? '',
      dataType: row['data_type'] as String? ?? AttributeDataType.text,
      unit: row['unit'] as String?,
      allowedValues: values,
      options: opts,
      isRequired: row['is_required'] as bool? ?? false,
      useInFilter: row['use_in_filter'] as bool? ?? false,
      useInCalculator: row['use_in_calculator'] as bool? ?? false,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

/// Attribute master linked to an attribute group (junction row).
class ShopAttributeGroupLink {
  const ShopAttributeGroupLink({
    required this.attributeId,
    required this.master,
    this.sortOrder = 0,
    this.isRequiredInGroup = false,
  });

  final String attributeId;
  final ShopAttributeMaster master;
  final int sortOrder;
  final bool isRequiredInGroup;
}

class ShopAttributeGroup {
  const ShopAttributeGroup({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    this.linkedAttributes = const [],
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final List<ShopAttributeGroupLink> linkedAttributes;

  factory ShopAttributeGroup.fromRow(Map<String, dynamic> row) {
    final links = <ShopAttributeGroupLink>[];
    for (final agaMap in SupabaseRepositoryBase.embeddedRows(row['attribute_group_attributes'])) {
      final am = agaMap['attribute_master'];
      if (am is! Map) continue;
      final master = ShopAttributeMaster.fromRow(Map<String, dynamic>.from(am));
      links.add(
        ShopAttributeGroupLink(
          attributeId: agaMap['attribute_id'] as String? ?? master.id,
          master: master,
          sortOrder: (agaMap['sort_order'] as num?)?.toInt() ?? 0,
          isRequiredInGroup: agaMap['is_required'] as bool? ?? false,
        ),
      );
    }
    links.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ShopAttributeGroup(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      description: row['description'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      linkedAttributes: links,
    );
  }
}

/// Attribute linked to a product with full master metadata for forms.
class ShopProductAttributeValue {
  const ShopProductAttributeValue({
    required this.id,
    required this.productId,
    required this.master,
    this.valueText,
    this.valueNumber,
    this.valueJson,
  });

  final String id;
  final String productId;
  final ShopAttributeMaster master;
  final String? valueText;
  final double? valueNumber;
  final dynamic valueJson;

  List<String> get multiSelectValues {
    if (valueJson is List) {
      return (valueJson as List).map((e) => e.toString()).toList();
    }
    if (valueText != null && valueText!.contains(',')) {
      return valueText!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (valueText != null && valueText!.isNotEmpty) return [valueText!];
    return const [];
  }

  factory ShopProductAttributeValue.fromRow(Map<String, dynamic> row) {
    final am = row['attribute_master'] as Map<String, dynamic>? ?? {};
    return ShopProductAttributeValue(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      master: ShopAttributeMaster.fromRow(am),
      valueText: row['value_text'] as String?,
      valueNumber: (row['value_number'] as num?)?.toDouble(),
      valueJson: row['value_json'],
    );
  }
}

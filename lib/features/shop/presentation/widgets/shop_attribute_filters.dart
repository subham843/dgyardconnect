import 'package:flutter/material.dart';

import '../../domain/attribute_data_type.dart';
import '../../domain/shop_attribute.dart';
import '../../domain/shop_product.dart';

/// Client-side filters driven by Attribute Master (use_in_filter = true).
class ShopAttributeFilters extends StatelessWidget {
  const ShopAttributeFilters({
    super.key,
    required this.attributes,
    required this.productAttributes,
    required this.selected,
    required this.onChanged,
  });

  final List<ShopAttributeMaster> attributes;
  final List<ShopProductAttributeValue> productAttributes;
  final Map<String, Set<String>> selected;
  final void Function(String attributeId, Set<String> values) onChanged;

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final a in attributes) _FilterField(
          attribute: a,
          productAttributes: productAttributes,
          selected: selected[a.id] ?? {},
          onChanged: (v) => onChanged(a.id, v),
        ),
      ],
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.attribute,
    required this.productAttributes,
    required this.selected,
    required this.onChanged,
  });

  final ShopAttributeMaster attribute;
  final List<ShopProductAttributeValue> productAttributes;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  Set<String> _distinctValues() {
    final out = <String>{};
    for (final pa in productAttributes) {
      if (pa.master.id != attribute.id) continue;
      if (attribute.dataType == AttributeDataType.multiSelect) {
        out.addAll(pa.multiSelectValues);
      } else if (attribute.dataType == AttributeDataType.boolean) {
        out.add(pa.valueText == 'true' || pa.valueText == 'yes' ? 'Yes' : 'No');
      } else if (pa.valueNumber != null) {
        out.add(pa.valueNumber.toString());
      } else if (pa.valueText != null && pa.valueText!.isNotEmpty) {
        out.add(pa.valueText!);
      }
    }
    if (attribute.effectiveOptions.isNotEmpty) {
      return attribute.effectiveOptions.where(out.contains).toSet().isEmpty
          ? attribute.effectiveOptions.toSet()
          : attribute.effectiveOptions.where((o) => out.contains(o)).toSet();
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final values = _distinctValues().toList()..sort();
    if (values.isEmpty) return const SizedBox.shrink();

    if (attribute.dataType == AttributeDataType.boolean) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Yes', label: Text('Yes')),
            ButtonSegment(value: 'No', label: Text('No')),
          ],
          emptySelectionAllowed: true,
          selected: selected,
          onSelectionChanged: onChanged,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(attribute.label, style: const TextStyle(fontSize: 14)),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final v in values)
                FilterChip(
                  label: Text(v),
                  selected: selected.contains(v),
                  onSelected: (on) {
                    final next = Set<String>.from(selected);
                    if (on) {
                      next.add(v);
                    } else {
                      next.remove(v);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Returns product IDs matching all active attribute filters.
Set<String> filterProductIds(
  List<ShopProduct> products,
  List<ShopProductAttributeValue> productAttributes,
  Map<String, Set<String>> filters,
) {
  if (filters.isEmpty || filters.values.every((s) => s.isEmpty)) {
    return products.map((p) => p.id).toSet();
  }
  final out = <String>{};
  for (final p in products) {
    var match = true;
    for (final entry in filters.entries) {
      if (entry.value.isEmpty) continue;
      final pa = productAttributes.where((a) => a.productId == p.id && a.master.id == entry.key);
      if (pa.isEmpty) {
        match = false;
        break;
      }
      final row = pa.first;
      final selected = entry.value;
      if (row.master.dataType == AttributeDataType.multiSelect) {
        if (!row.multiSelectValues.any(selected.contains)) {
          match = false;
          break;
        }
      } else if (row.master.dataType == AttributeDataType.boolean) {
        final label = row.valueText == 'true' || row.valueText == 'yes' ? 'Yes' : 'No';
        if (!selected.contains(label)) {
          match = false;
          break;
        }
      } else {
        final v = row.valueText ?? row.valueNumber?.toString() ?? '';
        if (!selected.contains(v)) {
          match = false;
          break;
        }
      }
    }
    if (match) out.add(p.id);
  }
  return out;
}

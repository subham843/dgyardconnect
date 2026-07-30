import 'package:flutter/material.dart';

import '../../data/shop_catalog_repository.dart';
import '../../domain/attribute_data_type.dart';
import '../../domain/shop_attribute.dart';

/// Dynamic product attribute inputs based on Attribute Master data types.
class ProductAttributeFields extends StatelessWidget {
  const ProductAttributeFields({
    super.key,
    required this.attributes,
    required this.values,
    required this.onChanged,
  });

  final List<ShopProductAttributeValue> attributes;
  final Map<String, dynamic> values;
  final void Function(String attributeId, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Select a sub-category to load attributes from assigned groups.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in attributes) ...[
          _Field(
            attribute: a,
            value: values[a.master.id],
            onChanged: (v) => onChanged(a.master.id, v),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.attribute, required this.value, required this.onChanged});

  final ShopProductAttributeValue attribute;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final m = attribute.master;
    final label = '${m.label}${m.isRequired ? ' *' : ''}';
    final type = m.dataType;

    switch (type) {
      case AttributeDataType.longText:
        return TextFormField(
          initialValue: (value as String?) ?? attribute.valueText ?? '',
          maxLines: 4,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: true),
          onChanged: (v) => onChanged(v),
        );
      case AttributeDataType.number:
        return TextFormField(
          initialValue: value?.toString() ?? attribute.valueNumber?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixText: m.unit),
          onChanged: (v) => onChanged(double.tryParse(v)),
        );
      case AttributeDataType.boolean:
        final boolVal = value is bool
            ? value
            : (attribute.valueText == 'true' || attribute.valueText == 'yes');
        return InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Yes')),
              ButtonSegment(value: false, label: Text('No')),
            ],
            selected: {boolVal},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        );
      case AttributeDataType.select:
        final opts = m.effectiveOptions;
        var selected = value as String? ?? attribute.valueText;
        if (selected != null && !opts.contains(selected) && opts.isNotEmpty) selected = null;
        return DropdownButtonFormField<String>(
          initialValue: opts.contains(selected) ? selected : null,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => onChanged(v),
        );
      case AttributeDataType.multiSelect:
        final opts = m.effectiveOptions;
        final selected = value is List<String>
            ? List<String>.from(value)
            : attribute.multiSelectValues;
        return InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final o in opts)
                FilterChip(
                  label: Text(o),
                  selected: selected.contains(o),
                  onSelected: (on) {
                    final next = List<String>.from(selected);
                    if (on) {
                      next.add(o);
                    } else {
                      next.remove(o);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        );
      case AttributeDataType.date:
        return TextFormField(
          initialValue: (value as String?) ?? attribute.valueText ?? '',
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
            helperText: 'Stored as text (date picker coming soon)',
          ),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onChanged(picked.toIso8601String().split('T').first);
            }
          },
        );
      case AttributeDataType.text:
      default:
        return TextFormField(
          initialValue: (value as String?) ?? attribute.valueText ?? '',
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          onChanged: (v) => onChanged(v),
        );
    }
  }
}

/// Persist edited values to Supabase product_attributes rows.
Future<void> _saveOneAttributeValue(
  ShopCatalogRepository repo,
  ShopProductAttributeValue row,
  dynamic v,
) async {
  final type = row.master.dataType;
  switch (type) {
    case AttributeDataType.number:
      await repo.updateProductAttribute(
        row.id,
        valueNumber: v is num ? v.toDouble() : double.tryParse('$v'),
        clearNumber: v == null,
        clearJson: true,
        valueText: null,
      );
    case AttributeDataType.boolean:
      await repo.updateProductAttribute(
        row.id,
        valueText: v == true ? 'true' : 'false',
        clearNumber: true,
        clearJson: true,
      );
    case AttributeDataType.multiSelect:
      final list = v is List ? List<dynamic>.from(v) : [v];
      await repo.updateProductAttribute(
        row.id,
        valueJson: list,
        valueText: list.join(', '),
        clearNumber: true,
      );
    default:
      await repo.updateProductAttribute(
        row.id,
        valueText: '$v',
        clearNumber: true,
        clearJson: true,
      );
  }
}

bool _hasAttributeValue(dynamic v) {
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  if (v is List) return v.isNotEmpty;
  return true;
}

/// Persist edited values to Supabase product_attributes rows (parallel updates).
Future<void> saveProductAttributeValues(
  ShopCatalogRepository repo,
  List<ShopProductAttributeValue> rows,
  Map<String, dynamic> values,
) async {
  final tasks = <Future<void>>[];
  for (final row in rows) {
    if (row.id.isEmpty) continue;
    final v = values[row.master.id];
    if (!_hasAttributeValue(v)) continue;
    tasks.add(_saveOneAttributeValue(repo, row, v));
  }
  if (tasks.isNotEmpty) await Future.wait(tasks);
}

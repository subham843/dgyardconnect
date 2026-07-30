import 'package:flutter/material.dart';

import 'datasheet_spec_models.dart';

/// Shows PDF-extracted specs; user picks what to apply to the product form.
class DatasheetSpecsReviewSheet extends StatefulWidget {
  const DatasheetSpecsReviewSheet({
    super.key,
    required this.specs,
    required this.fileName,
  });

  final DatasheetExtractedSpecs specs;
  final String fileName;

  static Future<DatasheetExtractedSpecs?> show(
    BuildContext context, {
    required DatasheetExtractedSpecs specs,
    required String fileName,
  }) {
    return showModalBottomSheet<DatasheetExtractedSpecs>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: DatasheetSpecsReviewSheet(specs: specs, fileName: fileName),
      ),
    );
  }

  @override
  State<DatasheetSpecsReviewSheet> createState() => _DatasheetSpecsReviewSheetState();
}

class _DatasheetSpecsReviewSheetState extends State<DatasheetSpecsReviewSheet> {
  late bool _applyModel = widget.specs.modelName?.trim().isNotEmpty == true;
  late bool _applyHsn = widget.specs.hsnCode?.trim().isNotEmpty == true;
  late bool _applyWarranty = widget.specs.warranty?.trim().isNotEmpty == true;
  late bool _applyShort = widget.specs.shortDescription?.trim().isNotEmpty == true;
  late bool _applyDesc = widget.specs.description?.trim().isNotEmpty == true;
  late bool _applyTech = widget.specs.technicalNotes?.trim().isNotEmpty == true;
  late bool _applyInstall = widget.specs.installationNotes?.trim().isNotEmpty == true;
  late bool _applyAttributes = widget.specs.attributeHints.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = widget.specs;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Datasheet specs detected',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(widget.fileName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            if (s.modelName?.trim().isNotEmpty == true)
              _toggle('Model number', s.modelName!, _applyModel, (v) => setState(() => _applyModel = v)),
            if (s.hsnCode?.trim().isNotEmpty == true)
              _toggle('HSN code', s.hsnCode!, _applyHsn, (v) => setState(() => _applyHsn = v)),
            if (s.warranty?.trim().isNotEmpty == true)
              _toggle('Warranty', s.warranty!, _applyWarranty, (v) => setState(() => _applyWarranty = v)),
            if (s.shortDescription?.trim().isNotEmpty == true)
              _toggle('Short description', s.shortDescription!, _applyShort, (v) => setState(() => _applyShort = v)),
            if (s.description?.trim().isNotEmpty == true)
              _toggle('Full description', s.description!, _applyDesc, (v) => setState(() => _applyDesc = v)),
            if (s.technicalNotes?.trim().isNotEmpty == true)
              _toggle('Technical notes', s.technicalNotes!, _applyTech, (v) => setState(() => _applyTech = v)),
            if (s.installationNotes?.trim().isNotEmpty == true)
              _toggle('Installation notes', s.installationNotes!, _applyInstall, (v) => setState(() => _applyInstall = v)),
            if (s.specifications.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Specifications (${s.specifications.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
              ...s.specifications.take(12).map(
                    (p) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.label, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(p.value),
                    ),
                  ),
            ],
            if (s.attributeHints.isNotEmpty)
              SwitchListTile(
                title: Text('Apply ${s.attributeHints.length} attribute hint(s)'),
                subtitle: const Text('Matches attribute keys on the product form'),
                value: _applyAttributes,
                onChanged: (v) => setState(() => _applyAttributes = v),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  DatasheetExtractedSpecs(
                    modelName: _applyModel ? s.modelName : null,
                    hsnCode: _applyHsn ? s.hsnCode : null,
                    warranty: _applyWarranty ? s.warranty : null,
                    warrantyMonths: _applyWarranty ? s.warrantyMonths : null,
                    shortDescription: _applyShort ? s.shortDescription : null,
                    description: _applyDesc ? s.description : null,
                    technicalNotes: _applyTech ? s.technicalNotes : null,
                    installationNotes: _applyInstall ? s.installationNotes : null,
                    specifications: s.specifications,
                    attributeHints: _applyAttributes ? s.attributeHints : const [],
                  ),
                );
              },
              child: const Text('Apply selected to product'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String label, String preview, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label),
      subtitle: Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis),
      value: value,
      onChanged: onChanged,
    );
  }
}

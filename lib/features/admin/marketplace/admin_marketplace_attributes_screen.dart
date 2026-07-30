import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_taxonomy_repository.dart';
import '../../marketplace/domain/marketplace_taxonomy.dart';

List<String> _parseOptionVals(String raw) => raw
    .split(RegExp(r'[,;\n]+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// Admin: attribute definitions + allowed values per subcategory (e.g. cable_type → CAT6).
class AdminMarketplaceAttributesScreen extends StatelessWidget {
  const AdminMarketplaceAttributesScreen({
    super.key,
    required this.categoryId,
    required this.subcategoryId,
  });

  final String categoryId;
  final String subcategoryId;

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceTaxonomyRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Features & options')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAttributeDialog(context, repo),
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Feature'),
      ),
      body: StreamBuilder<List<MarketplaceAttributeDef>>(
        stream: repo.watchAttributes(categoryId, subcategoryId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Add a feature: e.g. key "cable_type", label "Cable type", values "CAT5e, CAT6, CAT6A". '
                  'Sellers must pick one value per required feature when listing in this subcategory.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = list[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.label,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (a.required)
                            Chip(
                              label: const Text('Required', style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          if (a.scanQrBarcode && a.values.isEmpty)
                            Chip(
                              label: const Text('QR / barcode', style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _editAttributeDialog(context, repo, a),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () async {
                              final del = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove feature?'),
                                  content: Text('Delete "${a.label}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (del == true && context.mounted) {
                                await repo.deleteAttribute(categoryId, subcategoryId, a.id);
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      Text('Key: ${a.key}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      if (a.values.isEmpty)
                        Text(
                          'Free text (seller types value)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: a.values.map((v) => Chip(label: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addAttributeDialog(BuildContext context, MarketplaceTaxonomyRepository repo) async {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final valuesCtrl = TextEditingController();
    final sortCtrl = TextEditingController(text: '0');
    try {
      var enableScan = false;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            final optionsBlank = _parseOptionVals(valuesCtrl.text).isEmpty;
            return AlertDialog(
              title: const Text('New feature'),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.55),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: keyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Key (machine id)',
                            hintText: 'cable_type',
                            helperText: 'Lowercase, use underscores',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: labelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Label (shown to seller)',
                            hintText: 'Cable type',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: valuesCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Options',
                            hintText: 'CAT5e, CAT6, CAT6A',
                            helperText: 'Comma-separated, or leave blank for free text',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              if (_parseOptionVals(valuesCtrl.text).isNotEmpty) {
                                enableScan = false;
                              }
                            });
                          },
                        ),
                        if (optionsBlank) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('QR / barcode scan'),
                            subtitle: const Text(
                              'Show a scan icon next to the value field; camera fills text in capitals.',
                            ),
                            value: enableScan,
                            onChanged: (v) => setModalState(() => enableScan = v),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: sortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Sort order'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
              ],
            );
          },
        ),
      );
      if (ok != true || !context.mounted) return;
      final key = keyCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final label = labelCtrl.text.trim();
      final vals = _parseOptionVals(valuesCtrl.text);
      if (key.isEmpty || label.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key and label are required')),
        );
        return;
      }
      final so = int.tryParse(sortCtrl.text.trim()) ?? 0;
      final scanOn = vals.isEmpty && enableScan;
      await repo.createAttribute(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        key: key,
        label: label,
        values: vals,
        sortOrder: so,
        scanQrBarcode: scanOn,
      );
    } finally {
      keyCtrl.dispose();
      labelCtrl.dispose();
      valuesCtrl.dispose();
      sortCtrl.dispose();
    }
  }

  Future<void> _editAttributeDialog(
    BuildContext context,
    MarketplaceTaxonomyRepository repo,
    MarketplaceAttributeDef a,
  ) async {
    final labelCtrl = TextEditingController(text: a.label);
    final valuesCtrl = TextEditingController(text: a.values.join(', '));
    final sortCtrl = TextEditingController(text: '${a.sortOrder}');
    var requiredFlag = a.required;
    var enableScan = a.scanQrBarcode;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) {
            final optionsBlank = _parseOptionVals(valuesCtrl.text).isEmpty;
            return AlertDialog(
              title: const Text('Edit feature'),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.55),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Key: ${a.key}',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        Text(
                          'Key cannot be changed (existing listings use it).',
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: labelCtrl,
                          decoration: const InputDecoration(labelText: 'Label (shown to seller)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: valuesCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Options',
                            helperText: 'Comma-separated, or blank for free text',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) {
                            setSt(() {
                              if (_parseOptionVals(valuesCtrl.text).isNotEmpty) {
                                enableScan = false;
                              }
                            });
                          },
                        ),
                        if (optionsBlank) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('QR / barcode scan'),
                            subtitle: const Text(
                              'Show a scan icon next to the value field; camera fills text in capitals.',
                            ),
                            value: enableScan,
                            onChanged: (v) => setSt(() => enableScan = v),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: sortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Sort order'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Required for sellers'),
                          value: requiredFlag,
                          onChanged: (v) => setSt(() => requiredFlag = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            );
          },
        ),
      );
      if (ok != true || !context.mounted) return;
      final label = labelCtrl.text.trim();
      final vals = _parseOptionVals(valuesCtrl.text);
      if (label.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Label is required')),
        );
        return;
      }
      final so = int.tryParse(sortCtrl.text.trim());
      final scanOn = vals.isEmpty && enableScan;
      await repo.updateAttribute(
        categoryId,
        subcategoryId,
        a.id,
        label: label,
        values: vals,
        isRequired: requiredFlag,
        sortOrder: so,
        scanQrBarcode: scanOn,
      );
    } finally {
      labelCtrl.dispose();
      valuesCtrl.dispose();
      sortCtrl.dispose();
    }
  }
}

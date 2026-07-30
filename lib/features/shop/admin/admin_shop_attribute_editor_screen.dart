import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import '../data/supabase_repository_base.dart';
import '../domain/attribute_data_type.dart';
import '../domain/shop_attribute.dart';

/// Create or edit an Attribute Master record with optional options management.
class AdminShopAttributeEditorScreen extends StatefulWidget {
  const AdminShopAttributeEditorScreen({super.key, this.attributeId, this.embedded = false, this.onNavigateRoute});

  final String? attributeId;
  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  bool get isCreate => attributeId == null || attributeId!.isEmpty;

  @override
  State<AdminShopAttributeEditorScreen> createState() => _AdminShopAttributeEditorScreenState();
}

class _AdminShopAttributeEditorScreenState extends State<AdminShopAttributeEditorScreen> {
  final _repo = ShopCatalogRepository();
  final _keyCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  String _dataType = AttributeDataType.text;
  bool _isRequired = false;
  bool _useInFilter = false;
  bool _useInCalculator = false;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _savedId;
  List<ShopAttributeOption> _options = [];
  /// When true, slug stays as stored (edit / after create); label changes do not rewrite it.
  bool _slugLocked = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl.addListener(_syncSlugFromLabel);
    _load();
  }

  void _syncSlugFromLabel() {
    if (_slugLocked) return;
    final slug = SupabaseRepositoryBase.slugify(_labelCtrl.text);
    if (_keyCtrl.text != slug) {
      _keyCtrl.text = slug;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _labelCtrl.removeListener(_syncSlugFromLabel);
    _labelCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (!widget.isCreate) {
      final a = await _repo.getAttributeMaster(widget.attributeId!);
      if (a != null) {
        _savedId = a.id;
        _keyCtrl.text = a.key;
        _labelCtrl.text = a.label;
        _dataType = a.dataType;
        _isRequired = a.isRequired;
        _useInFilter = a.useInFilter;
        _useInCalculator = a.useInCalculator;
        _isActive = a.isActive;
        _unitCtrl.text = a.unit ?? '';
        _options = List.from(a.options);
        _slugLocked = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String get _resolvedKey {
    final fromField = _keyCtrl.text.trim();
    if (_slugLocked) return fromField;
    return SupabaseRepositoryBase.slugify(_labelCtrl.text);
  }

  Future<void> _saveMaster() async {
    final label = _labelCtrl.text.trim();
    final key = _resolvedKey;
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Label is required')));
      return;
    }
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate slug — use letters or numbers in the label')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.isCreate && _savedId == null) {
        final id = await _repo.createAttributeMaster(
          key: key,
          label: label,
          dataType: _dataType,
          unit: _dataType == AttributeDataType.number ? _unitCtrl.text : null,
          isRequired: _isRequired,
          useInFilter: _useInFilter,
          useInCalculator: _useInCalculator,
          isActive: _isActive,
        );
        if (id != null && mounted) {
          _savedId = id;
          _slugLocked = true;
          _keyCtrl.text = key;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attribute created')));
        }
      } else {
        final id = _savedId ?? widget.attributeId!;
        await _repo.updateAttributeMaster(
          id,
          key: key,
          label: label,
          dataType: _dataType,
          unit: _dataType == AttributeDataType.number ? _unitCtrl.text : '',
          isRequired: _isRequired,
          useInFilter: _useInFilter,
          useInCalculator: _useInCalculator,
          isActive: _isActive,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOption() async {
    final id = _savedId ?? widget.attributeId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save the attribute first')));
      return;
    }
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add option'),
        content: TextField(controller: label, decoration: const InputDecoration(labelText: 'Option label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && label.text.trim().isNotEmpty) {
      await _repo.createAttributeOption(attributeId: id, label: label.text.trim(), sortOrder: _options.length);
      final a = await _repo.getAttributeMaster(id);
      if (mounted && a != null) setState(() => _options = List.from(a.options));
    }
    label.dispose();
  }

  Future<void> _editOption(ShopAttributeOption opt) async {
    final id = _savedId ?? widget.attributeId!;
    final label = TextEditingController(text: opt.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit option'),
        content: TextField(controller: label, decoration: const InputDecoration(labelText: 'Option label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && label.text.trim().isNotEmpty) {
      await _repo.updateAttributeOption(optionId: opt.id, attributeId: id, label: label.text.trim());
      final a = await _repo.getAttributeMaster(id);
      if (mounted && a != null) setState(() => _options = List.from(a.options));
    }
    label.dispose();
  }

  Future<void> _deleteOption(ShopAttributeOption opt) async {
    final id = _savedId ?? widget.attributeId!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete option?'),
        content: Text('Remove "${opt.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteAttributeOption(optionId: opt.id, attributeId: id);
      final a = await _repo.getAttributeMaster(id);
      if (mounted && a != null) setState(() => _options = List.from(a.options));
    }
  }

  void _backToList() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminShopAttributeMaster);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final id = _savedId ?? widget.attributeId;
    if (id == null) return;
    if (newIndex > oldIndex) newIndex--;
    final list = List<ShopAttributeOption>.from(_options);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() => _options = list);
    await _repo.reorderAttributeOptions(id, list.map((o) => o.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final showOptions = AttributeDataType.hasOptions(_dataType);
    final canEditOptions = showOptions && (_savedId != null || !widget.isCreate);

    return AdminEmbeddedScaffold(
      title: widget.isCreate && _savedId == null ? 'New attribute' : 'Edit attribute',
      embedded: widget.embedded,
      onBack: _backToList,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                    helperText: 'Slug is generated automatically from the label',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _keyCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Slug (key)',
                    border: const OutlineInputBorder(),
                    helperText: _slugLocked
                        ? 'Slug cannot be changed after creation'
                        : 'Auto-generated, e.g. "Night Mode" → night-mode',
                    suffixIcon: _slugLocked ? null : const Icon(Icons.auto_fix_high_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: AttributeDataType.all.contains(_dataType) ? _dataType : AttributeDataType.text,
                  decoration: const InputDecoration(labelText: 'Data type', border: OutlineInputBorder()),
                  items: [
                    for (final t in AttributeDataType.all)
                      DropdownMenuItem(value: t, child: Text(AttributeDataType.labelFor(t))),
                  ],
                  onChanged: (v) => setState(() => _dataType = v ?? AttributeDataType.text),
                ),
                if (_dataType == AttributeDataType.number) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit (optional)', border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Is required'),
                  value: _isRequired,
                  onChanged: (v) => setState(() => _isRequired = v),
                ),
                SwitchListTile(
                  title: const Text('Use in filter'),
                  subtitle: const Text('Shown in shop product filters'),
                  value: _useInFilter,
                  onChanged: (v) => setState(() => _useInFilter = v),
                ),
                SwitchListTile(
                  title: const Text('Use in calculator'),
                  subtitle: const Text('Available for calculator rules'),
                  value: _useInCalculator,
                  onChanged: (v) => setState(() => _useInCalculator = v),
                ),
                SwitchListTile(
                  title: const Text('Status: Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveMaster,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(widget.isCreate && _savedId == null ? 'Create attribute' : 'Save changes'),
                ),
                if (showOptions) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Attribute options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      if (canEditOptions)
                        TextButton.icon(onPressed: _addOption, icon: const Icon(Icons.add), label: const Text('Add option')),
                    ],
                  ),
                  if (!canEditOptions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Save the attribute first, then add options for Select / Multi Select types.'),
                    )
                  else if (_options.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No options yet. Add predefined choices for products.'),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _options.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final o = _options[index];
                        return ListTile(
                          key: ValueKey(o.id),
                          leading: const Icon(Icons.drag_handle),
                          title: Text(o.label),
                          subtitle: o.isActive ? null : const Text('Hidden'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editOption(o)),
                              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteOption(o)),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
    );
  }
}

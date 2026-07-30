import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../../shop/data/shop_catalog_repository.dart';
import '../../shop/domain/attribute_data_type.dart';
import '../../shop/domain/shop_attribute.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_engine.dart';
import '../domain/calculator_models.dart';
import 'calculator_admin_family_context.dart';
import 'calculator_admin_ui.dart';

export 'admin_calculator_rules_screen.dart';
export 'admin_calculator_options_screen.dart';
export 'admin_calculator_family_rules_screen.dart';
export 'admin_calculator_family_editor_screen.dart';
export 'admin_calculator_question_groups_screen.dart';
export 'option_rule_editor.dart';

class AdminCalculatorFamiliesScreen extends StatefulWidget {
  const AdminCalculatorFamiliesScreen({
    super.key,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminCalculatorFamiliesScreen> createState() =>
      _AdminCalculatorFamiliesScreenState();
}

class _AdminCalculatorFamiliesScreenState
    extends State<AdminCalculatorFamiliesScreen> {
  final _repo = CalculatorRepository();
  List<CalculatorFamily> _items = [];
  final _familyLinks = <String, List<CalculatorFamilyAttributeLink>>{};
  bool _loading = true;

  final _ctx = CalculatorAdminFamilyContext.instance;

  @override
  void initState() {
    super.initState();
    _ctx.addListener(_syncFromCtx);
    _load();
  }

  void _syncFromCtx() {
    if (!mounted) return;
    setState(() {
      _items = _ctx.families;
      _familyLinks
        ..clear()
        ..addAll(_ctx.linksByFamily);
      _loading = _ctx.loading;
    });
  }

  @override
  void dispose() {
    _ctx.removeListener(_syncFromCtx);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _ctx.ensureLoaded(force: true);
    _syncFromCtx();
  }

  void _openEditor({String? familyId}) {
    final route = familyId == null
        ? RouteNames.adminCalculatorFamilyCreate
        : RouteNames.adminCalculatorFamilyEdit(familyId);
    if (widget.embedded && widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
      return;
    }
    context.push(route).then((_) => _load());
  }

  Future<void> _delete(CalculatorFamily family) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete family?'),
        content: Text(
          'Delete "${family.name}"?\n\n'
          'This will permanently remove its templates, questions and rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteFamily(family.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Family deleted')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = _ctx.selectedFamilyId;
    return AdminEmbeddedScaffold(
      title: 'Families',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: CalcAdminUi.ink,
        icon: const Icon(Icons.add),
        label: const Text('Family'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Text(
                'No families yet. Tap + Family to add one.',
                style: CalcAdminUi.body,
              ),
            ).calcPageEnter()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Text('Families', style: CalcAdminUi.largeTitle).calcPageEnter(),
                const SizedBox(height: 6),
                Text(
                  'Select a family, then configure options and rules from the left menu.',
                  style: CalcAdminUi.body,
                ).calcPageEnter(delayMs: 40),
                const SizedBox(height: 20),
                for (var i = 0; i < _items.length; i++)
                  _familyTile(_items[i], selectedId, i),
              ],
            ),
    );
  }

  Widget _familyTile(CalculatorFamily f, String? selectedId, int index) {
    final attrCount = _familyLinks[f.id]?.length ?? 0;
    final selected = f.id == selectedId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? CalcAdminUi.ink : CalcAdminUi.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _ctx.selectFamilyObject(f);
            setState(() {});
          },
          onDoubleTap: () => _openEditor(familyId: f.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CalcAdminUi.softBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    color: f.isActive ? CalcAdminUi.ink : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: CalcAdminUi.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          f.slug,
                          '$attrCount attributes',
                          f.isActive ? 'Active' : 'Inactive',
                          if (selected) 'Selected',
                        ].join(' · '),
                        style: CalcAdminUi.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _openEditor(familyId: f.id);
                    if (v == 'delete') _delete(f);
                    if (v == 'select') {
                      _ctx.selectFamilyObject(f);
                      setState(() {});
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'select', child: Text('Select')),
                    PopupMenuItem(value: 'edit', child: Text('Edit setup')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).calcStagger(index);
  }
}

class AdminCalculatorTemplatesScreen extends StatefulWidget {
  const AdminCalculatorTemplatesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminCalculatorTemplatesScreen> createState() =>
      _AdminCalculatorTemplatesScreenState();
}

class _AdminCalculatorTemplatesScreenState
    extends State<AdminCalculatorTemplatesScreen> {
  final _repo = CalculatorRepository();
  List<CalculatorFamily> _families = [];
  List<CalculatorTemplate> _templates = [];
  String? _familyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _families = await _repo.listFamilies(activeOnly: false);
    _familyId = _families.isNotEmpty ? _families.first.id : null;
    await _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    _templates = await _repo.listTemplates(
      familyId: _familyId,
      publishedOnly: false,
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    if (_familyId == null) return;
    final saved = await _showTemplateEditor();
    if (saved == true) await _loadTemplates();
  }

  Future<void> _edit(CalculatorTemplate t) async {
    final saved = await _showTemplateEditor(existing: t);
    if (saved == true) await _loadTemplates();
  }

  Future<bool?> _showTemplateEditor({CalculatorTemplate? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final versionCtrl = TextEditingController(
      text: '${existing?.version ?? 1}',
    );
    var isPublished = existing?.isPublished ?? false;
    var isActive = existing?.isActive ?? true;
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isEdit ? 'Edit template' : 'New template'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  autofocus: !isEdit,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: versionCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Version',
                    helperText:
                        'Revision number (v1, v2…). Same family can have multiple versions; usually keep 1.',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  subtitle: const Text(
                    'Only published templates show on public calculator',
                  ),
                  value: isPublished,
                  onChanged: (v) => setLocal(() => isPublished = v),
                ),
                if (isEdit)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setLocal(() => isActive = v),
                  ),
                if (isEdit && existing.slug.isNotEmpty)
                  Text(
                    'Slug: ${existing.slug}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || name.text.trim().isEmpty) {
      name.dispose();
      versionCtrl.dispose();
      return false;
    }

    final version = int.tryParse(versionCtrl.text.trim()) ?? 1;
    try {
      if (isEdit) {
        await _repo.updateTemplate(
          id: existing.id,
          name: name.text.trim(),
          version: version,
          isPublished: isPublished,
          isActive: isActive,
        );
      } else {
        await _repo.createTemplate(
          familyId: _familyId!,
          name: name.text.trim(),
          isPublished: isPublished,
          version: version,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Template updated' : 'Template created'),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
      return false;
    } finally {
      name.dispose();
      versionCtrl.dispose();
    }
  }

  Future<void> _delete(CalculatorTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          'Delete "${t.name}" (v${t.version})?\n\n'
          'This permanently removes its questions and rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteTemplate(t.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Template deleted')));
      }
      await _loadTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Calculator templates',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _familyId == null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Template'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'A template is one calculator setup for a family (questions + rules). '
              'Version = revision number — normally leave as 1.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_families.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _familyId,
                decoration: const InputDecoration(
                  labelText: 'Family',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final f in _families)
                    DropdownMenuItem(value: f.id, child: Text(f.name)),
                ],
                onChanged: (v) async {
                  setState(() => _familyId = v);
                  await _loadTemplates();
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Create a calculator family first.'),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _templates.isEmpty
                ? const Center(child: Text('No templates for this family yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: _templates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final t = _templates[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: t.isPublished
                                ? Colors.teal.withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            child: Icon(
                              Icons.description_outlined,
                              color: t.isPublished
                                  ? Colors.teal
                                  : Colors.orange,
                            ),
                          ),
                          title: Text(t.name),
                          subtitle: Text(
                            [
                              'v${t.version}',
                              t.isPublished ? 'Published' : 'Draft',
                              t.isActive ? 'Active' : 'Inactive',
                              t.slug,
                            ].join(' · '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: t.isPublished,
                                onChanged: (v) async {
                                  await _repo.setTemplatePublished(t.id, v);
                                  await _loadTemplates();
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _edit(t);
                                  if (v == 'delete') _delete(t);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Edit'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      title: Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _edit(t),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminCalculatorQuestionsScreen extends StatefulWidget {
  const AdminCalculatorQuestionsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminCalculatorQuestionsScreen> createState() =>
      _AdminCalculatorQuestionsScreenState();
}

class _AdminCalculatorQuestionsScreenState
    extends State<AdminCalculatorQuestionsScreen> {
  final _repo = CalculatorRepository();
  final _catalog = ShopCatalogRepository();
  List<CalculatorTemplate> _templates = [];
  List<CalculatorQuestion> _questions = [];
  List<ShopAttributeMaster> _calcAttributes = [];
  String? _templateId;
  bool _loading = true;

  static const _uiTypes = <String>['number', 'text', 'select', 'bool'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _templates = await _repo.listTemplates(publishedOnly: false);
    _templateId = _templates.isNotEmpty ? _templates.first.id : null;
    _calcAttributes = await _catalog.listCalculatorAttributes();
    await _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (_templateId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    _questions = await _repo.listQuestions(_templateId!);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    if (_templateId == null) return;
    final saved = await _showQuestionEditor();
    if (saved == true) await _loadQuestions();
  }

  Future<void> _edit(CalculatorQuestion q) async {
    final saved = await _showQuestionEditor(existing: q);
    if (saved == true) await _loadQuestions();
  }

  Future<bool?> _showQuestionEditor({CalculatorQuestion? existing}) async {
    final key = TextEditingController(text: existing?.questionKey ?? '');
    final label = TextEditingController(text: existing?.label ?? '');
    final sortCtrl = TextEditingController(
      text: '${existing?.sortOrder ?? _questions.length}',
    );
    final customOptCtrl = TextEditingController();
    var uiType = existing?.uiType ?? 'number';
    var visible = existing?.defaultVisibility ?? true;
    String? linkedAttrId;
    final selectedOptions = <String>{...(existing?.options ?? const [])};
    // Full catalog of options available to toggle (shop + existing).
    final availableOptions = <String>[...?existing?.options];
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEdit ? 'Edit question' : 'New question'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pick a shop attribute to load its options. Remove any option you do not want customers to see.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_calcAttributes.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue: linkedAttrId,
                      decoration: const InputDecoration(
                        labelText: 'Shop attribute (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Custom key (manual)'),
                        ),
                        for (final a in _calcAttributes)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.label} (${a.key})'),
                          ),
                      ],
                      onChanged: (v) {
                        setD(() {
                          linkedAttrId = v;
                          if (v != null) {
                            final a = _calcAttributes.firstWhere(
                              (e) => e.id == v,
                            );
                            key.text = a.key;
                            if (label.text.isEmpty || !isEdit)
                              label.text = a.label;
                            uiType = switch (a.dataType) {
                              AttributeDataType.number => 'number',
                              AttributeDataType.boolean => 'bool',
                              AttributeDataType.select ||
                              AttributeDataType.multiSelect => 'select',
                              _ =>
                                a.effectiveOptions.isNotEmpty
                                    ? 'select'
                                    : 'text',
                            };
                            final shopOpts = a.effectiveOptions;
                            if (shopOpts.isNotEmpty) {
                              uiType = 'select';
                              availableOptions
                                ..clear()
                                ..addAll(shopOpts);
                              selectedOptions
                                ..clear()
                                ..addAll(shopOpts);
                            }
                          }
                        });
                      },
                    ),
                  if (_calcAttributes.isEmpty)
                    Card(
                      color: Colors.amber.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No shop attributes with “Use in Calculator” enabled. '
                          'Create them in Shop → Attributes, or use a custom key here.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: key,
                    decoration: const InputDecoration(
                      labelText: 'Question key',
                      helperText: 'Used in rules — e.g. qty_key, days_key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(
                      labelText: 'Label (shown to customers)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('ui-$uiType'),
                    initialValue: _uiTypes.contains(uiType) ? uiType : 'number',
                    decoration: const InputDecoration(
                      labelText: 'Input type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in _uiTypes)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setD(() => uiType = v ?? 'number'),
                  ),
                  if (uiType == 'select') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Customer options (remove any you do not want shown)',
                      style: Theme.of(ctx).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    if (availableOptions.isEmpty && selectedOptions.isEmpty)
                      Text(
                        'Select a shop attribute, or add a custom option below.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final opt in {
                            ...availableOptions,
                            ...selectedOptions,
                          })
                            FilterChip(
                              label: Text(opt),
                              selected: selectedOptions.contains(opt),
                              showCheckmark: true,
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selectedOptions.contains(opt)
                                    ? Colors.white
                                    : const Color(0xFF1D1D1F),
                              ),
                              selectedColor: const Color(0xFF1D1D1F),
                              backgroundColor: const Color(0xFFF5F5F7),
                              checkmarkColor: Colors.white,
                              onSelected: (on) {
                                setD(() {
                                  if (on) {
                                    selectedOptions.add(opt);
                                  } else {
                                    selectedOptions.remove(opt);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customOptCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Add custom option',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (v) {
                              final t = v.trim();
                              if (t.isEmpty) return;
                              setD(() {
                                if (!availableOptions.contains(t)) {
                                  availableOptions.add(t);
                                }
                                selectedOptions.add(t);
                                customOptCtrl.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            final t = customOptCtrl.text.trim();
                            if (t.isEmpty) return;
                            setD(() {
                              if (!availableOptions.contains(t)) {
                                availableOptions.add(t);
                              }
                              selectedOptions.add(t);
                              customOptCtrl.clear();
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: sortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sort order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible by default'),
                    value: visible,
                    onChanged: (v) => setD(() => visible = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || key.text.trim().isEmpty) {
      key.dispose();
      label.dispose();
      sortCtrl.dispose();
      customOptCtrl.dispose();
      return false;
    }

    final options = uiType == 'select'
        ? [
            for (final o in availableOptions)
              if (selectedOptions.contains(o)) o,
            for (final o in selectedOptions)
              if (!availableOptions.contains(o)) o,
          ]
        : null;
    final sortOrder = int.tryParse(sortCtrl.text.trim()) ?? 0;
    final resolvedLabel = label.text.trim().isEmpty
        ? key.text.trim()
        : label.text.trim();

    try {
      if (isEdit) {
        await _repo.updateQuestion(
          id: existing.id,
          questionKey: key.text.trim(),
          label: resolvedLabel,
          uiType: uiType,
          options: options,
          sortOrder: sortOrder,
          defaultVisibility: visible,
        );
      } else {
        await _repo.createQuestion(
          templateId: _templateId!,
          questionKey: key.text.trim(),
          label: resolvedLabel,
          uiType: uiType,
          options: options,
          sortOrder: sortOrder,
          defaultVisibility: visible,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Question updated' : 'Question created'),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
      return false;
    } finally {
      key.dispose();
      label.dispose();
      sortCtrl.dispose();
      customOptCtrl.dispose();
    }
  }

  Future<void> _delete(CalculatorQuestion q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text('Delete "${q.label}" (${q.questionKey})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteQuestion(q.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Question deleted')));
      }
      await _loadQuestions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Calculator questions',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _templateId == null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Question'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Select a template, then tap + Question. Shop attributes are helpers for keys and options '
              '(Shop → Attributes, Use in Calculator ON).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_templates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: DropdownButtonFormField<String>(
                initialValue: _templateId,
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final t in _templates)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) async {
                  setState(() => _templateId = v);
                  await _loadQuestions();
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Create a template first (Calculator → Templates).'),
            ),
          if (_calcAttributes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ExpansionTile(
                  initiallyExpanded: false,
                  title: const Text('Shop attributes for calculator'),
                  subtitle: Text(
                    '${_calcAttributes.length} available · expand to preview',
                  ),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text(
                              'From Attribute Master. Add new ones in Shop → Attributes with '
                              'Use in Calculator ON. They appear in the Question add dialog.',
                            ),
                          ),
                          for (final a in _calcAttributes)
                            ListTile(
                              dense: true,
                              title: Text(a.label),
                              subtitle: Text(
                                '${a.key} · ${AttributeDataType.labelFor(a.dataType)}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                ? const Center(
                    child: Text(
                      'No questions on this template yet. Tap + Question to add one.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                    itemCount: _questions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final q = _questions[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${q.sortOrder}')),
                          title: Text(q.label),
                          subtitle: Text(
                            [
                              q.questionKey,
                              q.uiType,
                              q.defaultVisibility ? 'Visible' : 'Hidden',
                              if ((q.options ?? const []).isNotEmpty)
                                'opts: ${q.options!.join(', ')}',
                            ].join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _edit(q);
                              if (v == 'delete') _delete(q);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edit'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _edit(q),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminCalculatorRuleProductsScreen extends StatefulWidget {
  const AdminCalculatorRuleProductsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminCalculatorRuleProductsScreen> createState() =>
      _AdminCalculatorRuleProductsScreenState();
}

class _AdminCalculatorRuleProductsScreenState
    extends State<AdminCalculatorRuleProductsScreen> {
  final _repo = CalculatorRepository();
  List<CalculatorRule> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final templates = await _repo.listTemplates(publishedOnly: false);
    _rules = [];
    for (final t in templates) {
      _rules.addAll(await _repo.listRules(t.id));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Rule product links',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _rules.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(_rules[i].name ?? _rules[i].ruleType),
                subtitle: const Text(
                  'Link products in Supabase calculator_rule_products',
                ),
              ),
            ),
    );
  }
}

class AdminCalculatorQuotationBuilderScreen extends StatefulWidget {
  const AdminCalculatorQuotationBuilderScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<AdminCalculatorQuotationBuilderScreen> createState() =>
      _AdminCalculatorQuotationBuilderScreenState();
}

class _AdminCalculatorQuotationBuilderScreenState
    extends State<AdminCalculatorQuotationBuilderScreen> {
  final _repo = CalculatorRepository();
  final _engine = CalculatorEngine();
  List<CalculatorTemplate> _templates = [];
  String? _templateId;
  final _answers = <String, dynamic>{
    'camera_qty': 4,
    'resolution': '4MP',
    'storage_days': 15,
  };
  CalculatorResult? _result;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    _templates = await _repo.listTemplates(publishedOnly: false);
    _templateId = _templates.isNotEmpty ? _templates.first.id : null;
  }

  Future<void> _run() async {
    if (_templateId == null) return;
    setState(() => _loading = true);
    final questions = await _repo.listQuestions(_templateId!);
    final rules = await _repo.listRules(_templateId!);
    _result = await _engine.evaluate(
      questions: questions,
      rules: rules,
      answers: _answers,
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AdminEmbeddedScaffold(
      title: 'Quotation builder (test)',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _run,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Run engine'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_templates.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _templateId,
              decoration: const InputDecoration(
                labelText: 'Template',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in _templates)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _templateId = v),
            ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(labelText: 'camera_qty'),
            keyboardType: TextInputType.number,
            controller: TextEditingController(
              text: '${_answers['camera_qty']}',
            ),
            onSubmitted: (v) => _answers['camera_qty'] = int.tryParse(v) ?? 0,
          ),
          if (r != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Suggested',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final line in r.suggestedLines)
              ListTile(title: Text(line.label), trailing: Text('x${line.qty}')),
            const Text(
              'Formulas',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final f in r.formulas)
              ListTile(title: Text(f.key), trailing: Text('${f.value}')),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../../shop/domain/shop_attribute.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_models.dart';
import 'calculator_admin_family_context.dart';
import 'calculator_admin_ui.dart';

/// Options & follow-up questions for the selected calculator family.
class AdminCalculatorOptionsScreen extends StatefulWidget {
  const AdminCalculatorOptionsScreen({
    super.key,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminCalculatorOptionsScreen> createState() =>
      _AdminCalculatorOptionsScreenState();
}

class _AdminCalculatorOptionsScreenState
    extends State<AdminCalculatorOptionsScreen> {
  final _ctx = CalculatorAdminFamilyContext.instance;
  final _repo = CalculatorRepository();
  String? _expandedAttrId;
  String? _expandedOption;
  bool _saving = false;

  // Draft: attrId -> ordered selected options; attrId -> option -> questions
  final _selectedOptions = <String, List<String>>{};
  final _pathQuestions =
      <String, Map<String, List<CalculatorFamilyOptionPathQuestion>>>{};
  /// Old question_key → new key (so template + rules stay in sync on rename).
  final _questionKeyRenames = <String, String>{};

  @override
  void initState() {
    super.initState();
    _ctx.addListener(_onCtx);
    _bootstrap();
  }

  @override
  void dispose() {
    _ctx.removeListener(_onCtx);
    super.dispose();
  }

  void _onCtx() {
    if (mounted) {
      _hydrateDraft();
      setState(() {});
    }
  }

  Future<void> _bootstrap() async {
    await _ctx.ensureLoaded();
    _hydrateDraft();
    if (mounted) setState(() {});
  }

  void _hydrateDraft() {
    _selectedOptions.clear();
    _pathQuestions.clear();
    _questionKeyRenames.clear();
    final family = _ctx.selectedFamily;
    if (family == null) return;
    for (final link in _ctx.selectedLinks) {
      final master = _ctx.attributeById(link.attributeId);
      if (master == null) continue;
      final all = master.effectiveOptions;
      final paths = _ctx.selectedPaths
          .where((p) => p.parentAttributeId == link.attributeId)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (link.selectedOptions != null && link.selectedOptions!.isNotEmpty) {
        _selectedOptions[link.attributeId] = [
          for (final o in link.selectedOptions!)
            if (all.contains(o)) o,
        ];
      } else if (paths.isNotEmpty) {
        _selectedOptions[link.attributeId] = [
          for (final p in paths)
            if (all.contains(p.optionLabel)) p.optionLabel,
        ];
      } else {
        _selectedOptions[link.attributeId] = [...all];
      }
    }
    for (final p in _ctx.selectedPaths) {
      _pathQuestions.putIfAbsent(p.parentAttributeId, () => {});
      final qs = [...p.questions]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _pathQuestions[p.parentAttributeId]![p.optionLabel] = qs;
    }
  }

  void _moveOption(String attrId, int index, int delta) {
    final list = _selectedOptions[attrId];
    if (list == null) return;
    final next = index + delta;
    if (next < 0 || next >= list.length) return;
    setState(() {
      final item = list.removeAt(index);
      list.insert(next, item);
    });
  }

  void _moveQuestion(String attrId, String opt, int index, int delta) {
    final list = _pathQuestions[attrId]?[opt];
    if (list == null) return;
    final next = index + delta;
    if (next < 0 || next >= list.length) return;
    setState(() {
      final item = list.removeAt(index);
      list.insert(next, item);
    });
  }

  void _goFamilies() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminCalculatorFamilies);
    } else {
      context.go(RouteNames.adminCalculatorFamilies);
    }
  }

  Future<void> _save() async {
    final family = _ctx.selectedFamily;
    if (family == null) return;
    setState(() => _saving = true);
    try {
      final links = <CalculatorFamilyAttributeLink>[
        for (final link in _ctx.selectedLinks)
          CalculatorFamilyAttributeLink(
            attributeId: link.attributeId,
            sortOrder: link.sortOrder,
            questionMode: link.questionMode,
            groupId: link.groupId,
            selectedOptions: () {
              final chosen = _selectedOptions[link.attributeId];
              final master = _ctx.attributeById(link.attributeId);
              if (chosen == null) {
                return link.selectedOptions ?? master?.effectiveOptions;
              }
              return [...chosen];
            }(),
          ),
      ];
      await _repo.setFamilyAttributes(familyId: family.id, links: links);

      final paths = <CalculatorFamilyOptionPath>[];
      for (final link in links) {
        final opts = _selectedOptions[link.attributeId] ?? const <String>[];
        for (var oi = 0; oi < opts.length; oi++) {
          final opt = opts[oi];
          final rawQs =
              _pathQuestions[link.attributeId]?[opt] ?? const [];
          paths.add(
            CalculatorFamilyOptionPath(
              familyId: family.id,
              parentAttributeId: link.attributeId,
              optionLabel: opt,
              sortOrder: oi,
              questions: [
                for (var qi = 0; qi < rawQs.length; qi++)
                  CalculatorFamilyOptionPathQuestion(
                    id: rawQs[qi].id,
                    questionKey: rawQs[qi].questionKey,
                    label: rawQs[qi].label,
                    uiType: rawQs[qi].uiType,
                    options: rawQs[qi].options,
                    sourceAttributeId: rawQs[qi].sourceAttributeId,
                    sortOrder: qi,
                    groupId: rawQs[qi].groupId,
                  ),
              ],
            ),
          );
        }
      }
      await _repo.setFamilyOptionPaths(
        familyId: family.id,
        paths: paths,
        questionKeyRenames: Map<String, String>.from(_questionKeyRenames),
      );
      _questionKeyRenames.clear();
      await _ctx.refreshSelectedFamily();
      _hydrateDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Options & questions saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editQuestion({
    required ShopAttributeMaster attr,
    required String option,
    CalculatorFamilyOptionPathQuestion? existing,
    int? index,
  }) async {
    final key = TextEditingController(text: existing?.questionKey ?? '');
    final label = TextEditingController(text: existing?.label ?? '');
    final optionsCtrl = TextEditingController(
      text: (existing?.options ?? const []).join(', '),
    );
    var uiType = existing?.uiType ?? 'number';
    String? groupId = existing?.groupId;
    if (groupId == null) {
      final parentLink = _ctx.selectedLinks
          .where((l) => l.attributeId == attr.id)
          .firstOrNull;
      groupId = parentLink?.groupId;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Add question' : 'Edit question'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: key,
                  decoration: const InputDecoration(
                    labelText: 'Question key',
                    helperText: 'Used in rules — e.g. qty_key',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: uiType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'number', child: Text('Number')),
                    DropdownMenuItem(value: 'select', child: Text('Select')),
                    DropdownMenuItem(value: 'text', child: Text('Text')),
                  ],
                  onChanged: (v) => setD(() => uiType = v ?? 'number'),
                ),
                if (uiType == 'select') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: optionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Options',
                      helperText: 'Comma-separated choices',
                    ),
                  ),
                ],
                if (_ctx.selectedGroups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: groupId,
                    decoration: const InputDecoration(labelText: 'Question group'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final g in _ctx.selectedGroups)
                        DropdownMenuItem(value: g.id, child: Text(g.name)),
                    ],
                    onChanged: (v) => setD(() => groupId = v),
                  ),
                ],
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final qKey = key.text.trim();
    final qLabel = label.text.trim();
    final optList = [
      for (final p in optionsCtrl.text.split(','))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    key.dispose();
    label.dispose();
    optionsCtrl.dispose();
    if (ok != true || qKey.isEmpty || qLabel.isEmpty) return;

    final oldKey = existing?.questionKey.trim() ?? '';
    if (oldKey.isNotEmpty && oldKey != qKey) {
      // Chain renames: A→B then B→C becomes A→C.
      final prior = [
        for (final e in _questionKeyRenames.entries)
          if (e.value == oldKey) e.key,
      ];
      for (final k in prior) {
        _questionKeyRenames[k] = qKey;
      }
      _questionKeyRenames.removeWhere((_, v) => v == oldKey);
      _questionKeyRenames[oldKey] = qKey;
    }

    final q = CalculatorFamilyOptionPathQuestion(
      id: existing?.id ?? '',
      questionKey: qKey,
      label: qLabel,
      uiType: uiType,
      options: uiType == 'select'
          ? (optList.isEmpty ? existing?.options : optList)
          : null,
      sourceAttributeId: existing?.sourceAttributeId,
      sortOrder: existing?.sortOrder ??
          (_pathQuestions[attr.id]?[option]?.length ?? 0),
      groupId: groupId,
    );
    setState(() {
      _pathQuestions.putIfAbsent(attr.id, () => {});
      final list = _pathQuestions[attr.id]!.putIfAbsent(option, () => []);
      if (index != null && index >= 0 && index < list.length) {
        list[index] = q;
      } else {
        list.add(q);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = _ctx.selectedFamily;
    return AdminEmbeddedScaffold(
      title: 'Options & questions',
      embedded: widget.embedded,
      floatingActionButton: family == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: CalcAdminUi.ink,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
      body: _ctx.loading && _ctx.families.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : family == null
              ? CalcAdminPickFamilyEmpty(
                  onChooseFamily: _goFamilies,
                  families: [
                    for (final f in _ctx.families)
                      CalculatorFamilyLite(id: f.id, name: f.name),
                  ],
                  onSelectFamily: (id) {
                    _ctx.selectFamily(id);
                    _hydrateDraft();
                    setState(() {});
                  },
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  children: [
                    Text('Options & questions', style: CalcAdminUi.largeTitle)
                        .calcPageEnter(),
                    const SizedBox(height: 6),
                    Text(
                      'Turn on customer choices, then add follow-up questions under each option.',
                      style: CalcAdminUi.body,
                    ).calcPageEnter(delayMs: 40),
                    const SizedBox(height: 16),
                    CalcAdminFamilySwitcher(
                      families: [
                        for (final f in _ctx.families)
                          CalculatorFamilyLite(id: f.id, name: f.name),
                      ],
                      selectedId: family.id,
                      onSelect: (id) {
                        _ctx.selectFamily(id);
                        _hydrateDraft();
                        setState(() {});
                      },
                    ).calcPageEnter(delayMs: 60),
                    const SizedBox(height: 20),
                    if (_ctx.selectedLinks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: CalcAdminUi.softCardDeco,
                        child: Text(
                          'This family has no attributes yet. Add them under Families first.',
                          style: CalcAdminUi.body,
                        ),
                      ).calcStagger(0)
                    else
                      for (var i = 0; i < _ctx.selectedLinks.length; i++)
                        _attrCard(_ctx.selectedLinks[i], i),
                  ],
                ),
    );
  }

  Widget _attrCard(CalculatorFamilyAttributeLink link, int index) {
    final attr = _ctx.attributeById(link.attributeId);
    if (attr == null) return const SizedBox.shrink();
    final allOpts = attr.effectiveOptions;
    final selected = _selectedOptions.putIfAbsent(
      attr.id,
      () => [...(link.selectedOptions ?? allOpts)],
    );
    final expanded = _expandedAttrId == attr.id;
    final offOpts = [
      for (final o in allOpts)
        if (!selected.contains(o)) o,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: CalcAdminUi.cardDeco,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedAttrId = expanded ? null : attr.id;
              _expandedOption = null;
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attr.label, style: CalcAdminUi.sectionTitle),
                        const SizedBox(height: 2),
                        Text(
                          '${selected.length} of ${allOpts.length} options on · drag order with ↑ ↓',
                          style: CalcAdminUi.body,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: CalcAdminUi.subtle,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Text('Customer choices', style: CalcAdminUi.sectionTitle),
                        const SizedBox(height: 4),
                        Text(
                          'Order here is the order customers see. Use ↑ ↓ to rearrange.',
                          style: CalcAdminUi.body,
                        ),
                        const SizedBox(height: 10),
                        if (selected.isEmpty)
                          Text(
                            'No options on. Tap chips below to enable.',
                            style: CalcAdminUi.body,
                          )
                        else
                          for (var oi = 0; oi < selected.length; oi++)
                            _orderedOptionRow(attr, selected, oi),
                        if (offOpts.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Turn on', style: CalcAdminUi.body),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final opt in offOpts)
                                ActionChip(
                                  label: Text(opt),
                                  onPressed: () {
                                    setState(() {
                                      selected.add(opt);
                                      _pathQuestions
                                          .putIfAbsent(attr.id, () => {})
                                          .putIfAbsent(opt, () => []);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Follow-up questions',
                          style: CalcAdminUi.sectionTitle,
                        ),
                        const SizedBox(height: 8),
                        for (final opt in selected) _optionBlock(attr, opt),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ).calcStagger(index + 1);
  }

  Widget _orderedOptionRow(
    ShopAttributeMaster attr,
    List<String> selected,
    int oi,
  ) {
    final opt = selected[oi];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: CalcAdminUi.softBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: CalcAdminUi.border.withValues(alpha: 0.85)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CalcAdminUi.ink,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${oi + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  opt,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: CalcAdminUi.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: oi == 0 ? null : () => _moveOption(attr.id, oi, -1),
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: oi >= selected.length - 1
                    ? null
                    : () => _moveOption(attr.id, oi, 1),
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Turn off',
                onPressed: () {
                  setState(() {
                    selected.removeAt(oi);
                    _pathQuestions[attr.id]?.remove(opt);
                    if (_expandedOption == '${attr.id}|$opt') {
                      _expandedOption = null;
                    }
                  });
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionBlock(ShopAttributeMaster attr, String opt) {
    final open = _expandedOption == '${attr.id}|$opt';
    final qs = _pathQuestions[attr.id]?[opt] ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
      color: CalcAdminUi.softBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: CalcAdminUi.border.withValues(alpha: 0.85)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              opt,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: CalcAdminUi.ink,
              ),
            ),
            subtitle: Text(
              '${qs.length} question${qs.length == 1 ? '' : 's'}',
              style: CalcAdminUi.body,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Add question',
                  onPressed: () => _editQuestion(attr: attr, option: opt),
                  icon: const Icon(Icons.add_rounded),
                ),
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ],
            ),
            onTap: () => setState(() {
              _expandedOption = open ? null : '${attr.id}|$opt';
            }),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      children: [
                        if (qs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No questions yet. Tap + to add. Use ↑ ↓ to set order.',
                              style: CalcAdminUi.body,
                            ),
                          )
                        else
                          for (var qi = 0; qi < qs.length; qi++)
                            ListTile(
                              dense: true,
                              title: Text(qs[qi].label),
                              subtitle: Text(
                                '${qi + 1}. ${qs[qi].questionKey} · ${qs[qi].uiType}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Move up',
                                    onPressed: qi == 0
                                        ? null
                                        : () => _moveQuestion(
                                              attr.id,
                                              opt,
                                              qi,
                                              -1,
                                            ),
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Move down',
                                    onPressed: qi >= qs.length - 1
                                        ? null
                                        : () => _moveQuestion(
                                              attr.id,
                                              opt,
                                              qi,
                                              1,
                                            ),
                                    icon: const Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _editQuestion(
                                      attr: attr,
                                      option: opt,
                                      existing: qs[qi],
                                      index: qi,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _pathQuestions[attr.id]![opt]!
                                            .removeAt(qi);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
    );
  }
}

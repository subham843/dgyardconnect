import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_models.dart';
import 'calculator_admin_family_context.dart';
import 'calculator_admin_ui.dart';

/// Manage quotation / question groups for the selected calculator family.
class AdminCalculatorQuestionGroupsScreen extends StatefulWidget {
  const AdminCalculatorQuestionGroupsScreen({
    super.key,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminCalculatorQuestionGroupsScreen> createState() =>
      _AdminCalculatorQuestionGroupsScreenState();
}

class _AdminCalculatorQuestionGroupsScreenState
    extends State<AdminCalculatorQuestionGroupsScreen> {
  final _ctx = CalculatorAdminFamilyContext.instance;
  final _repo = CalculatorRepository();
  final _draft = <CalculatorQuestionGroup>[];
  /// attributeId → question group id (or null = ungrouped)
  final _attrGroupId = <String, String?>{};
  /// groupId → ordered follow-up question keys (Camera qty before Resolution, etc.)
  final _groupQuestionOrder = <String, List<String>>{};
  final _questionLabelByKey = <String, String>{};
  String? _expandedGroupId;
  var _saving = false;
  var _dirty = false;

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
    if (!mounted) return;
    if (_dirty) {
      setState(() {});
      return;
    }
    _hydrate();
    setState(() {});
  }

  Future<void> _bootstrap() async {
    await _ctx.ensureLoaded();
    if (!_dirty) _hydrate();
    if (mounted) setState(() {});
  }

  void _hydrate() {
    _draft
      ..clear()
      ..addAll(
        [..._ctx.selectedGroups]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
    _attrGroupId
      ..clear()
      ..addEntries([
        for (final l in _ctx.selectedLinks) MapEntry(l.attributeId, l.groupId),
      ]);
    _rebuildGroupQuestionOrder();
    _dirty = false;
  }

  /// Collect unique path questions per group, ordered by current sort_order.
  void _rebuildGroupQuestionOrder({bool keepDraftOrder = false}) {
    final prev = keepDraftOrder
        ? {
            for (final e in _groupQuestionOrder.entries) e.key: [...e.value],
          }
        : const <String, List<String>>{};
    _groupQuestionOrder.clear();
    _questionLabelByKey.clear();

    final scored = <String, Map<String, int>>{};
    for (final p in _ctx.selectedPaths) {
      final parentG = _attrGroupId[p.parentAttributeId];
      for (final q in p.questions) {
        final key = q.questionKey.trim();
        if (key.isEmpty) continue;
        final gid = (q.groupId != null && q.groupId!.isNotEmpty)
            ? q.groupId!
            : parentG;
        if (gid == null || gid.isEmpty) continue;
        _questionLabelByKey[key] =
            q.label.trim().isEmpty ? key : q.label.trim();
        final byKey = scored.putIfAbsent(gid, () => {});
        final prevSort = byKey[key];
        if (prevSort == null || q.sortOrder < prevSort) {
          byKey[key] = q.sortOrder;
        }
      }
    }

    for (final g in _draft) {
      final scores = scored[g.id] ?? {};
      final keys = scores.keys.toList()
        ..sort((a, b) => (scores[a] ?? 0).compareTo(scores[b] ?? 0));
      if (keepDraftOrder && prev[g.id] != null) {
        final kept = <String>[
          for (final k in prev[g.id]!)
            if (scores.containsKey(k)) k,
        ];
        for (final k in keys) {
          if (!kept.contains(k)) kept.add(k);
        }
        _groupQuestionOrder[g.id] = kept;
      } else {
        _groupQuestionOrder[g.id] = keys;
      }
    }
  }

  void _moveGroupQuestion(String groupId, int index, int delta) {
    final list = _groupQuestionOrder[groupId];
    if (list == null) return;
    final next = index + delta;
    if (next < 0 || next >= list.length) return;
    _markDirty(() {
      final item = list.removeAt(index);
      list.insert(next, item);
    });
  }

  void _markDirty(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  void _reindexDraft() {
    for (var i = 0; i < _draft.length; i++) {
      final g = _draft[i];
      if (g.sortOrder == i) continue;
      _draft[i] = CalculatorQuestionGroup(
        id: g.id,
        familyId: g.familyId,
        name: g.name,
        description: g.description,
        sortOrder: i,
        isActive: g.isActive,
      );
    }
  }

  void _moveGroup(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _draft.length) return;
    _markDirty(() {
      final item = _draft.removeAt(index);
      _draft.insert(next, item);
      _reindexDraft();
    });
  }

  void _goFamilies() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminCalculatorFamilies);
    } else {
      context.go(RouteNames.adminCalculatorFamilies);
    }
  }

  Future<void> _addGroup() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New question group'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            helperText: 'e.g. Camera, Storage, Accessories',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final trimmed = name.text.trim();
    name.dispose();
    if (ok != true || trimmed.isEmpty) return;
    _markDirty(() {
      _draft.add(
        CalculatorQuestionGroup(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          familyId: _ctx.selectedFamilyId ?? '',
          name: trimmed,
          sortOrder: _draft.length,
        ),
      );
    });
  }

  Future<void> _rename(int index) async {
    final ctrl = TextEditingController(text: _draft[index].name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
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
    );
    final trimmed = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || trimmed.isEmpty) return;
    _markDirty(() {
      final g = _draft[index];
      _draft[index] = CalculatorQuestionGroup(
        id: g.id,
        familyId: g.familyId,
        name: trimmed,
        description: g.description,
        sortOrder: g.sortOrder,
        isActive: g.isActive,
      );
    });
  }

  Future<void> _save() async {
    final family = _ctx.selectedFamily;
    if (family == null) return;
    setState(() => _saving = true);
    try {
      final idMap = await _repo.setQuestionGroups(
        familyId: family.id,
        groups: [
          for (var i = 0; i < _draft.length; i++)
            CalculatorQuestionGroup(
              id: _draft[i].id,
              familyId: family.id,
              name: _draft[i].name,
              description: _draft[i].description,
              sortOrder: i,
              isActive: _draft[i].isActive,
            ),
        ],
      );

      String? mapGroupId(String? id) {
        if (id == null || id.isEmpty) return null;
        return idMap[id] ?? id;
      }

      final links = [
        for (final l in _ctx.selectedLinks)
          CalculatorFamilyAttributeLink(
            attributeId: l.attributeId,
            sortOrder: l.sortOrder,
            selectedOptions: l.selectedOptions,
            questionMode: l.questionMode,
            groupId: mapGroupId(_attrGroupId[l.attributeId] ?? l.groupId),
          ),
      ];
      await _repo.setFamilyAttributes(familyId: family.id, links: links);

      // Keep follow-up questions in the same group; apply in-group question order.
      final paths = _ctx.selectedPaths;
      if (paths.isNotEmpty) {
        final parentGroup = <String, String?>{
          for (final l in links) l.attributeId: l.groupId,
        };
        final keyOrder = <String, int>{};
        for (final e in _groupQuestionOrder.entries) {
          for (var i = 0; i < e.value.length; i++) {
            keyOrder.putIfAbsent(e.value[i], () => i);
          }
        }
        await _repo.setFamilyOptionPaths(
          familyId: family.id,
          paths: [
            for (final p in paths)
              CalculatorFamilyOptionPath(
                id: p.id,
                familyId: family.id,
                parentAttributeId: p.parentAttributeId,
                optionLabel: p.optionLabel,
                sortOrder: p.sortOrder,
                attributes: p.attributes,
                questions: [
                  for (final q in p.questions)
                    CalculatorFamilyOptionPathQuestion(
                      id: q.id,
                      questionKey: q.questionKey,
                      label: q.label,
                      uiType: q.uiType,
                      options: q.options,
                      sourceAttributeId: q.sourceAttributeId,
                      sortOrder: keyOrder[q.questionKey] ?? q.sortOrder,
                      groupId: mapGroupId(
                        q.groupId ?? parentGroup[p.parentAttributeId],
                      ),
                    ),
                ],
              ),
          ],
        );
      }

      _dirty = false;
      await _ctx.refreshSelectedFamily();
      if (!mounted) return;
      _hydrate();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question groups saved')),
      );
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

  @override
  Widget build(BuildContext context) {
    final family = _ctx.selectedFamily;
    return AdminEmbeddedScaffold(
      title: 'Question groups',
      embedded: widget.embedded,
      floatingActionButton: family == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Group'),
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
                    _dirty = false;
                    _ctx.selectFamily(id);
                    _hydrate();
                    setState(() {});
                  },
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          Text('Question groups', style: CalcAdminUi.largeTitle)
                              .calcPageEnter(),
                          const SizedBox(height: 6),
                          Text(
                            'Create sections, assign attributes, then use ↑ ↓ under '
                            'each group to decide question order '
                            '(e.g. quantity before resolution).',
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
                              _dirty = false;
                              _ctx.selectFamily(id);
                              _hydrate();
                              setState(() {});
                            },
                          ).calcPageEnter(delayMs: 60),
                          const SizedBox(height: 20),
                          if (_draft.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: CalcAdminUi.softCardDeco,
                              child: Text(
                                'No groups yet. Tap + Group to add one.',
                                style: CalcAdminUi.body,
                              ),
                            ).calcStagger(0)
                          else
                            for (var i = 0; i < _draft.length; i++)
                              _groupTile(i),
                          if (_ctx.selectedLinks.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Assign attributes',
                              style: CalcAdminUi.sectionTitle,
                            ).calcStagger(_draft.length + 1),
                            const SizedBox(height: 6),
                            Text(
                              'Each family attribute (and its follow-up questions) '
                              'appears under the group you pick.',
                              style: CalcAdminUi.body,
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < _ctx.selectedLinks.length; i++)
                              _attrAssignTile(_ctx.selectedLinks[i], i),
                          ],
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white,
                      elevation: 8,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: Row(
                            children: [
                              if (_dirty)
                                Text(
                                  'Unsaved changes',
                                  style: CalcAdminUi.body.copyWith(
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              const Spacer(),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: CalcAdminUi.ink,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded, size: 18),
                                label: Text(_saving ? 'Saving…' : 'Save'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _attrAssignTile(CalculatorFamilyAttributeLink link, int index) {
    final attr = _ctx.attributeById(link.attributeId);
    if (attr == null) return const SizedBox.shrink();
    final current = _attrGroupId[link.attributeId];
    final validCurrent = current != null &&
            _draft.any((g) => g.id == current)
        ? current
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: CalcAdminUi.cardDeco,
      child: Row(
        children: [
          Expanded(
            child: Text(attr.label, style: CalcAdminUi.sectionTitle),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              initialValue: validCurrent,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Group',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ungrouped'),
                ),
                for (final g in _draft)
                  DropdownMenuItem<String?>(
                    value: g.id,
                    child: Text(g.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => _markDirty(() {
                _attrGroupId[link.attributeId] = v;
                _rebuildGroupQuestionOrder(keepDraftOrder: true);
              }),
            ),
          ),
        ],
      ),
    ).calcStagger(_draft.length + 2 + index);
  }

  Widget _groupTile(int i) {
    final g = _draft[i];
    final memberCount = _attrGroupId.values.where((id) => id == g.id).length;
    final questions = _groupQuestionOrder[g.id] ?? const <String>[];
    final expanded = _expandedGroupId == g.id;
    return Container(
      key: ValueKey('qg-${g.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CalcAdminUi.cardDeco,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CalcAdminUi.ink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _expandedGroupId = expanded ? null : g.id;
                    }),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name, style: CalcAdminUi.sectionTitle),
                        Text(
                          [
                            if (memberCount == 0)
                              i == 0
                                  ? 'Shows first · no attributes yet'
                                  : 'No attributes assigned'
                            else
                              '$memberCount attribute${memberCount == 1 ? '' : 's'}',
                            if (questions.isNotEmpty)
                              '${questions.length} question${questions.length == 1 ? '' : 's'} · tap to reorder',
                          ].join(' · '),
                          style: CalcAdminUi.body,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: expanded ? 'Collapse' : 'Reorder questions',
                  onPressed: () => setState(() {
                    _expandedGroupId = expanded ? null : g.id;
                  }),
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: i == 0 ? null : () => _moveGroup(i, -1),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: i >= _draft.length - 1 ? null : () => _moveGroup(i, 1),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Rename',
                  onPressed: () => _rename(i),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _markDirty(() {
                    final removedId = _draft[i].id;
                    _draft.removeAt(i);
                    _groupQuestionOrder.remove(removedId);
                    for (final e in _attrGroupId.entries.toList()) {
                      if (e.value == removedId) _attrGroupId[e.key] = null;
                    }
                    if (_expandedGroupId == removedId) _expandedGroupId = null;
                    _reindexDraft();
                  }),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                ),
              ],
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              color: CalcAdminUi.softBg,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
              child: questions.isEmpty
                  ? Text(
                      'No follow-up questions in this group yet. '
                      'Assign an attribute, then add questions under Options.',
                      style: CalcAdminUi.body,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question order in this group',
                          style: CalcAdminUi.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: CalcAdminUi.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (var qi = 0; qi < questions.length; qi++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '${qi + 1}',
                                    style: CalcAdminUi.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: CalcAdminUi.ink,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _questionLabelByKey[questions[qi]] ??
                                        questions[qi],
                                    style: CalcAdminUi.sectionTitle.copyWith(
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move up',
                                  onPressed: qi == 0
                                      ? null
                                      : () => _moveGroupQuestion(g.id, qi, -1),
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move down',
                                  onPressed: qi >= questions.length - 1
                                      ? null
                                      : () => _moveGroupQuestion(g.id, qi, 1),
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

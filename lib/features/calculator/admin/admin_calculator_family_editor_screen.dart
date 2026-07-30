import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_models.dart';
import 'calculator_admin_family_context.dart';
import 'calculator_admin_ui.dart';

/// Embedded family create/edit — same right-panel pattern as shop product editor.
class AdminCalculatorFamilyEditorScreen extends StatefulWidget {
  const AdminCalculatorFamilyEditorScreen({
    super.key,
    this.familyId,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final String? familyId;
  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  bool get isCreate => familyId == null || familyId!.isEmpty;

  @override
  State<AdminCalculatorFamilyEditorScreen> createState() =>
      _AdminCalculatorFamilyEditorScreenState();
}

class _AdminCalculatorFamilyEditorScreenState
    extends State<AdminCalculatorFamilyEditorScreen> {
  final _ctx = CalculatorAdminFamilyContext.instance;
  final _repo = CalculatorRepository();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _sortOrder = TextEditingController(text: '0');

  final _selectedAttrIds = <String>{};
  final _selectedOptionsByAttr = <String, Set<String>>{};
  final _groupIdByAttr = <String, String?>{};
  final _pathQuestions =
      <String, Map<String, List<CalculatorFamilyOptionPathQuestion>>>{};

  var _isActive = true;
  var _loading = true;
  var _saving = false;
  String? _slug;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _ctx.ensureLoaded();
    if (!widget.isCreate) {
      final family =
          _ctx.families.where((f) => f.id == widget.familyId).firstOrNull;
      if (family != null) {
        _name.text = family.name;
        _description.text = family.description ?? '';
        _sortOrder.text = '${family.sortOrder}';
        _isActive = family.isActive;
        _slug = family.slug;
        _ctx.selectFamily(family.id);
        final links = _ctx.linksByFamily[family.id] ?? const [];
        for (final l in links) {
          _selectedAttrIds.add(l.attributeId);
          final master = _ctx.attributeById(l.attributeId);
          _selectedOptionsByAttr[l.attributeId] = {
            ...(l.selectedOptions ?? master?.effectiveOptions ?? const <String>[]),
          };
          _groupIdByAttr[l.attributeId] = l.groupId;
        }
        for (final p in _ctx.pathsByFamily[family.id] ?? const []) {
          _pathQuestions.putIfAbsent(p.parentAttributeId, () => {});
          _pathQuestions[p.parentAttributeId]![p.optionLabel] = [...p.questions];
        }
      }
    } else {
      _sortOrder.text = '${_ctx.families.length}';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _go(String route) {
    if (widget.embedded && widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
      return;
    }
    context.go(route);
  }

  void _goBack() {
    const route = RouteNames.adminCalculatorFamilies;
    if (widget.embedded && widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(route);
    }
  }

  Future<void> _showNextStepsSheet(String familyName) async {
    if (!mounted) return;
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Family ready', style: CalcAdminUi.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  '"$familyName" is saved. Next: organize groups, turn on options, then add rules.',
                  style: CalcAdminUi.body.copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CalcAdminUi.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(
                    RouteNames.adminCalculatorQuestionGroups,
                  ),
                  child: const Text('Next: Question groups'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CalcAdminUi.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.of(ctx).pop(RouteNames.adminCalculatorOptions),
                  child: const Text('Options & questions'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CalcAdminUi.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.of(ctx).pop(RouteNames.adminCalculatorRules),
                  child: const Text('Rules'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('families'),
                  child: const Text('Back to families'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (next == null || next == 'families') {
      _goBack();
      return;
    }
    _go(next);
  }

  InputDecoration _field(String label, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      filled: true,
      fillColor: CalcAdminUi.softBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CalcAdminUi.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CalcAdminUi.accent, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _save() async {
    final familyName = _name.text.trim();
    if (familyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final desc = _description.text.trim();
      final order = int.tryParse(_sortOrder.text.trim()) ?? 0;
      late final String familyId;

      if (widget.isCreate) {
        final id = await _repo.createFamily(
          name: familyName,
          description: desc.isEmpty ? null : desc,
          sortOrder: order,
        );
        if (id == null) throw StateError('Family create failed');
        familyId = id;
      } else {
        familyId = widget.familyId!;
        await _repo.updateFamily(
          id: familyId,
          name: familyName,
          description: desc.isEmpty ? null : desc,
          sortOrder: order,
          isActive: _isActive,
        );
      }

      final links = <CalculatorFamilyAttributeLink>[
        for (final a in _ctx.calcAttributes)
          if (_selectedAttrIds.contains(a.id))
            CalculatorFamilyAttributeLink(
              attributeId: a.id,
              questionMode: CalculatorFamilyQuestionMode.select,
              groupId: _groupIdByAttr[a.id],
              selectedOptions: () {
                final chosen = _selectedOptionsByAttr[a.id];
                if (chosen == null) return a.effectiveOptions;
                return [
                  for (final o in a.effectiveOptions)
                    if (chosen.contains(o)) o,
                ];
              }(),
            ),
      ];

      final optionPaths = <CalculatorFamilyOptionPath>[
        for (final a in _ctx.calcAttributes)
          if (_selectedAttrIds.contains(a.id))
            for (final opt in a.effectiveOptions)
              if (_selectedOptionsByAttr[a.id]?.contains(opt) ?? false)
                CalculatorFamilyOptionPath(
                  familyId: familyId,
                  parentAttributeId: a.id,
                  optionLabel: opt,
                  questions: [
                    ...(_pathQuestions[a.id]?[opt] ??
                        const <CalculatorFamilyOptionPathQuestion>[]),
                  ],
                ),
      ];

      await _repo.setFamilyAttributes(familyId: familyId, links: links);
      await _repo.setFamilyOptionPaths(familyId: familyId, paths: optionPaths);

      _ctx.selectFamily(familyId);
      await _ctx.ensureLoaded(force: true);

      if (!mounted) return;
      if (widget.isCreate) {
        await _showNextStepsSheet(familyName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family updated')),
        );
        _goBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.isCreate
        ? const <CalculatorQuestionGroup>[]
        : (_ctx.groupsByFamily[widget.familyId] ?? const []);

    return AdminEmbeddedScaffold(
      title: widget.isCreate ? 'New family' : 'Edit family',
      embedded: widget.embedded,
      onBack: _goBack,
      floatingActionButton: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: CalcAdminUi.ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _saving || _loading ? null : _save,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Text(
                  widget.isCreate ? 'New family' : 'Edit family',
                  style: CalcAdminUi.largeTitle,
                ).calcPageEnter(),
                const SizedBox(height: 6),
                Text(
                  'Basics and which shop attributes belong to this calculator.',
                  style: CalcAdminUi.body,
                ).calcPageEnter(delayMs: 40),
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Basics',
                  index: 0,
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        autofocus: widget.isCreate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CalcAdminUi.ink,
                        ),
                        decoration: _field(
                          'Name',
                          helper: 'Shown to customers on the calculator',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        maxLines: 2,
                        decoration: _field(
                          'Description',
                          helper: 'Short summary under the family name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sortOrder,
                        keyboardType: TextInputType.number,
                        decoration: _field('Sort order'),
                      ),
                      if (!widget.isCreate) ...[
                        const SizedBox(height: 12),
                        Material(
                          color: CalcAdminUi.softBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: CalcAdminUi.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            title: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CalcAdminUi.ink,
                              ),
                            ),
                            subtitle: const Text(
                              'Inactive families stay hidden on the public calculator',
                              style: TextStyle(
                                fontSize: 12,
                                color: CalcAdminUi.subtle,
                              ),
                            ),
                            value: _isActive,
                            activeThumbColor: CalcAdminUi.accent,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        ),
                        if ((_slug ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Slug: $_slug',
                            style: CalcAdminUi.body,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                _sectionCard(
                  title: 'Shop attributes',
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pick attributes for this family. Turn options on under Options & questions.',
                        style: CalcAdminUi.body,
                      ),
                      const SizedBox(height: 12),
                      if (_ctx.calcAttributes.isEmpty)
                        Text(
                          'No calculator attributes yet. Add them in Shop → Attributes.',
                          style: CalcAdminUi.body,
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final a in _ctx.calcAttributes)
                              FilterChip(
                                selected: _selectedAttrIds.contains(a.id),
                                showCheckmark: false,
                                label: Text(
                                  a.effectiveOptions.isNotEmpty
                                      ? '${a.label} · ${a.effectiveOptions.length}'
                                      : a.label,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _selectedAttrIds.contains(a.id)
                                      ? Colors.white
                                      : CalcAdminUi.ink,
                                ),
                                selectedColor: CalcAdminUi.ink,
                                backgroundColor: CalcAdminUi.softBg,
                                side: BorderSide(
                                  color: _selectedAttrIds.contains(a.id)
                                      ? CalcAdminUi.ink
                                      : CalcAdminUi.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(980),
                                ),
                                onSelected: (on) {
                                  setState(() {
                                    if (on) {
                                      _selectedAttrIds.add(a.id);
                                      _selectedOptionsByAttr[a.id] = {
                                        ...a.effectiveOptions,
                                      };
                                      _groupIdByAttr[a.id] = groups.isNotEmpty
                                          ? groups.first.id
                                          : null;
                                      _pathQuestions.putIfAbsent(a.id, () => {});
                                      for (final opt in a.effectiveOptions) {
                                        _pathQuestions[a.id]!
                                            .putIfAbsent(opt, () => []);
                                      }
                                    } else {
                                      _selectedAttrIds.remove(a.id);
                                      _selectedOptionsByAttr.remove(a.id);
                                      _groupIdByAttr.remove(a.id);
                                      _pathQuestions.remove(a.id);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      if (_selectedAttrIds.isNotEmpty && groups.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        for (final a in _ctx.calcAttributes)
                          if (_selectedAttrIds.contains(a.id))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: DropdownButtonFormField<String?>(
                                initialValue: _groupIdByAttr[a.id] != null &&
                                        groups.any(
                                          (g) => g.id == _groupIdByAttr[a.id],
                                        )
                                    ? _groupIdByAttr[a.id]
                                    : null,
                                decoration: _field('${a.label} · question group'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Ungrouped'),
                                  ),
                                  for (final g in groups)
                                    DropdownMenuItem<String?>(
                                      value: g.id,
                                      child: Text(g.name),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _groupIdByAttr[a.id] = v),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required int index,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: CalcAdminUi.cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: CalcAdminUi.sectionTitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ).calcStagger(index);
  }
}

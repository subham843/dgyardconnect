import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../../shop/data/shop_catalog_repository.dart';
import '../../shop/domain/shop_attribute.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_models.dart';
import 'calculator_admin_family_context.dart';
import 'calculator_admin_ui.dart';
import 'option_rule_editor.dart';

/// Per-family option rules (groups + When/Then) for the selected family.
class AdminCalculatorFamilyRulesScreen extends StatefulWidget {
  const AdminCalculatorFamilyRulesScreen({
    super.key,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminCalculatorFamilyRulesScreen> createState() =>
      _AdminCalculatorFamilyRulesScreenState();
}

class _AdminCalculatorFamilyRulesScreenState
    extends State<AdminCalculatorFamilyRulesScreen> {
  final _ctx = CalculatorAdminFamilyContext.instance;
  final _repo = CalculatorRepository();
  final _catalog = ShopCatalogRepository();

  /// attrId -> option -> rules
  final _rules = <String, Map<String, List<CalculatorRule>>>{};
  final _ruleGroups = <String, Map<String, List<CalculatorRuleGroup>>>{};
  String? _expandedKey;
  bool _loadingRules = false;

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
      _loadRulesForSelected();
      setState(() {});
    }
  }

  Future<void> _bootstrap() async {
    await _ctx.ensureLoaded();
    await _loadRulesForSelected();
  }

  Future<void> _loadRulesForSelected() async {
    final family = _ctx.selectedFamily;
    if (family == null) {
      _rules.clear();
      _ruleGroups.clear();
      return;
    }
    setState(() => _loadingRules = true);
    _rules.clear();
    _ruleGroups.clear();
    for (final link in _ctx.selectedLinks) {
      final master = _ctx.attributeById(link.attributeId);
      if (master == null) continue;
      final opts = link.selectedOptions ?? master.effectiveOptions;
      for (final opt in opts) {
        final rules = await _repo.listRulesForOptionScope(
          familyId: family.id,
          attributeId: link.attributeId,
          optionLabel: opt,
        );
        final groups = await _repo.listRuleGroupsForOptionScope(
          familyId: family.id,
          attributeId: link.attributeId,
          optionLabel: opt,
        );
        _rules.putIfAbsent(link.attributeId, () => {})[opt] = rules;
        _ruleGroups.putIfAbsent(link.attributeId, () => {})[opt] = groups;
      }
    }
    if (mounted) setState(() => _loadingRules = false);
  }

  void _goFamilies() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminCalculatorFamilies);
    } else {
      context.go(RouteNames.adminCalculatorFamilies);
    }
  }

  Future<void> _addGroup(ShopAttributeMaster attr, String opt) async {
    final family = _ctx.selectedFamily;
    if (family == null) return;
    final name = await OptionRuleEditor.promptGroupName(context);
    if (name == null || name.isEmpty) return;
    await _repo.createRuleGroup(
      familyId: family.id,
      name: name,
      optionScopeAttributeId: attr.id,
      optionScopeLabel: opt,
      sortOrder: (_ruleGroups[attr.id]?[opt]?.length ?? 0) * 10,
    );
    await _loadRulesForSelected();
  }

  Future<List<CalculatorQuestion>> _familyQuestions(String familyId) async {
    final tid = await _repo.ensureTemplateForFamily(familyId);
    return _repo.listQuestionsForFamily(
      familyId: familyId,
      templateId: tid,
    );
  }

  Future<void> _openRuleEditor({
    required ShopAttributeMaster attr,
    required String opt,
    CalculatorRule? existing,
    String? ruleGroupId,
    String? ruleGroupName,
  }) async {
    final family = _ctx.selectedFamily;
    if (family == null) return;
    final questions = await _familyQuestions(family.id);
    if (!mounted) return;
    final saved = await OptionRuleEditor.show(
      context: context,
      repo: _repo,
      catalog: _catalog,
      subCategories: _ctx.subCategories,
      calcAttributes: _ctx.calcAttributes,
      familyId: family.id,
      attribute: attr,
      optionLabel: opt,
      existing: existing,
      ruleGroupId: ruleGroupId ?? existing?.ruleGroupId,
      ruleGroupName: ruleGroupName ?? existing?.ruleGroupName,
      links: _ctx.selectedLinks,
      paths: _ctx.selectedPaths,
      groups: _ctx.selectedGroups,
      familyQuestions: questions,
      defaultPriority:
          ((_rules[attr.id]?[opt]?.length ?? 0) + 1) * 10,
    );
    if (saved == true) await _loadRulesForSelected();
  }

  @override
  Widget build(BuildContext context) {
    final family = _ctx.selectedFamily;
    return AdminEmbeddedScaffold(
      title: 'Rules',
      embedded: widget.embedded,
      body: _ctx.loading && _ctx.families.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : family == null
              ? CalcAdminPickFamilyEmpty(
                  onChooseFamily: _goFamilies,
                  families: [
                    for (final f in _ctx.families)
                      CalculatorFamilyLite(id: f.id, name: f.name),
                  ],
                  onSelectFamily: (id) async {
                    _ctx.selectFamily(id);
                    setState(() {});
                    await _loadRulesForSelected();
                  },
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                  children: [
                    Text('Rules', style: CalcAdminUi.largeTitle).calcPageEnter(),
                    const SizedBox(height: 6),
                    Text(
                      'Group rules by product line, then add suggest / quantity rules per option.',
                      style: CalcAdminUi.body,
                    ).calcPageEnter(delayMs: 40),
                    const SizedBox(height: 16),
                    CalcAdminFamilySwitcher(
                      families: [
                        for (final f in _ctx.families)
                          CalculatorFamilyLite(id: f.id, name: f.name),
                      ],
                      selectedId: family.id,
                      onSelect: (id) async {
                        _ctx.selectFamily(id);
                        await _loadRulesForSelected();
                      },
                    ).calcPageEnter(delayMs: 60),
                    const SizedBox(height: 20),
                    if (_loadingRules)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_ctx.selectedLinks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: CalcAdminUi.softCardDeco,
                        child: Text(
                          'Add attributes and options under Families / Options first.',
                          style: CalcAdminUi.body,
                        ),
                      )
                    else
                      for (var i = 0; i < _ctx.selectedLinks.length; i++)
                        ..._attrSections(_ctx.selectedLinks[i], i),
                  ],
                ),
    );
  }

  List<Widget> _attrSections(CalculatorFamilyAttributeLink link, int index) {
    final attr = _ctx.attributeById(link.attributeId);
    if (attr == null) return const [];
    final opts = link.selectedOptions ?? attr.effectiveOptions;
    if (opts.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(attr.label, style: CalcAdminUi.sectionTitle),
      ).calcStagger(index),
      for (final opt in opts) _optionRulesCard(attr, opt, index),
    ];
  }

  Widget _optionRulesCard(ShopAttributeMaster attr, String opt, int index) {
    final key = '${attr.id}|$opt';
    final open = _expandedKey == key;
    final rules = _rules[attr.id]?[opt] ?? const <CalculatorRule>[];
    final groups = _ruleGroups[attr.id]?[opt] ?? const <CalculatorRuleGroup>[];
    final family = _ctx.selectedFamily!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CalcAdminUi.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              title: Text(
                opt,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: CalcAdminUi.ink,
                ),
              ),
              subtitle: Text(
                '${groups.length} groups · ${rules.length} rules',
                style: CalcAdminUi.body,
              ),
              trailing: Icon(
                open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              onTap: () => setState(() => _expandedKey = open ? null : key),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _addGroup(attr, opt),
                                icon: const Icon(Icons.create_new_folder_outlined),
                                label: const Text('Add group'),
                              ),
                              const Spacer(),
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: CalcAdminUi.softBg,
                                  foregroundColor: CalcAdminUi.ink,
                                ),
                                onPressed: () => _openRuleEditor(
                                  attr: attr,
                                  opt: opt,
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add rule'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...OptionRuleEditor.buildGroupedRules(
                            context: context,
                            family: family,
                            attribute: attr,
                            optionLabel: opt,
                            rules: rules,
                            groups: groups,
                            accent: CalcAdminUi.ink,
                            subtle: CalcAdminUi.subtle,
                            softBg: CalcAdminUi.softBg,
                            repo: _repo,
                            onChanged: _loadRulesForSelected,
                            onEditRule: (rule) => _openRuleEditor(
                              attr: attr,
                              opt: opt,
                              existing: rule,
                              ruleGroupId: rule.ruleGroupId,
                              ruleGroupName: rule.ruleGroupName,
                            ),
                            onAddInGroup: (g) => _openRuleEditor(
                              attr: attr,
                              opt: opt,
                              ruleGroupId: g.id,
                              ruleGroupName: g.name,
                            ),
                            catalog: _catalog,
                            subCategories: _ctx.subCategories,
                            calcAttributes: _ctx.calcAttributes,
                            links: _ctx.selectedLinks,
                            paths: _ctx.selectedPaths,
                            questionGroups: _ctx.selectedGroups,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ).calcStagger(index + 1);
  }
}

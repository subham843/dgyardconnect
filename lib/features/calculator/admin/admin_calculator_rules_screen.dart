import 'package:flutter/material.dart';

import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../../shop/data/shop_catalog_repository.dart';
import '../../shop/domain/shop_attribute.dart';
import '../../shop/domain/shop_category.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_models.dart';

/// Form-based calculator rules editor (no raw JSON required).
class AdminCalculatorRulesScreen extends StatefulWidget {
  const AdminCalculatorRulesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminCalculatorRulesScreen> createState() =>
      _AdminCalculatorRulesScreenState();
}

class _AdminCalculatorRulesScreenState extends State<AdminCalculatorRulesScreen> {
  final _repo = CalculatorRepository();
  final _catalog = ShopCatalogRepository();

  List<CalculatorTemplate> _templates = [];
  List<CalculatorRule> _rules = [];
  List<CalculatorQuestion> _questions = [];
  List<ShopAttributeMaster> _calcAttributes = [];
  List<ShopSubCategory> _subCategories = [];
  String? _templateId;
  bool _loading = true;

  static const _ops = <(String, String)>[
    ('eq', 'Equals'),
    ('neq', 'Not equals'),
    ('gte', '≥'),
    ('gt', '>'),
    ('lte', '≤'),
    ('lt', '<'),
  ];

  static const _ruleTypes = <(String, String)>[
    ('suggest', 'Suggest product'),
    ('formula', 'Formula (quantity)'),
    ('visibility', 'Show / hide questions'),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _templates = await _repo.listTemplates(publishedOnly: false);
    _templateId = _templates.isNotEmpty ? _templates.first.id : null;
    _calcAttributes = await _catalog.listCalculatorAttributes();
    _subCategories = await _catalog.listAllSubCategories(activeOnly: true);
    await _loadRules();
  }

  Future<void> _loadRules() async {
    if (_templateId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final template = _templates.where((t) => t.id == _templateId).firstOrNull;
    _rules = await _repo.listRules(_templateId!);
    if (template != null) {
      _questions = await _repo.listQuestionsForFamily(
        familyId: template.familyId,
        templateId: template.id,
      );
    } else {
      _questions = await _repo.listQuestions(_templateId!);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _questionKeys {
    final keys = <String>{
      for (final q in _questions) q.questionKey,
      for (final a in _calcAttributes) a.key,
    };
    final list = keys.where((k) => k.isNotEmpty).toList()..sort();
    return list;
  }

  Future<void> _add() async {
    if (_templateId == null) return;
    final saved = await _showRuleEditor();
    if (saved == true) await _loadRules();
  }

  Future<void> _edit(CalculatorRule rule) async {
    final saved = await _showRuleEditor(existing: rule);
    if (saved == true) await _loadRules();
  }

  Future<void> _delete(CalculatorRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Delete "${rule.name ?? rule.ruleType}"?'),
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
      await _repo.deleteRule(rule.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule deleted')),
        );
      }
      await _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<bool?> _showRuleEditor({
    CalculatorRule? existing,
    String? optionScopeFamilyId,
    String? optionScopeAttributeId,
    String? optionScopeLabel,
    String? lockedConditionKey,
    String? lockedConditionValue,
    String? templateIdOverride,
    int? defaultPriority,
  }) async {
    final templateId = templateIdOverride ?? _templateId;
    if (templateId == null) return false;

    final scopeFamilyId = optionScopeFamilyId ?? existing?.optionScopeFamilyId;
    final scopeAttributeId =
        optionScopeAttributeId ?? existing?.optionScopeAttributeId;
    final scopeLabel = optionScopeLabel ?? existing?.optionScopeLabel;
    final lockedKey = lockedConditionKey;
    final lockedValue = lockedConditionValue;

    final isEdit = existing != null;
    final name = TextEditingController(text: existing?.name ?? '');
    final priority = TextEditingController(
      text: '${existing?.priority ?? defaultPriority ?? (_rules.length + 1) * 10}',
    );
    var ruleType = existing?.ruleType ?? 'suggest';
    if (ruleType == 'recommendation') ruleType = 'suggest';
    if (ruleType == 'dependency') ruleType = 'visibility';
    var isActive = existing?.isActive ?? true;

    // Conditions
    final clauses = <_RuleClause>[
      ..._parseClauses(existing?.condition),
    ];
    if (lockedKey != null &&
        lockedValue != null &&
        !clauses.any(
          (c) =>
              c.varKey == lockedKey &&
              c.op == 'eq' &&
              c.value == lockedValue,
        )) {
      clauses.insert(
        0,
        _RuleClause(varKey: lockedKey, op: 'eq', value: lockedValue),
      );
    }
    if (clauses.isEmpty) {
      clauses.add(_RuleClause(varKey: _questionKeys.isNotEmpty ? _questionKeys.first : 'qty_key'));
    }

    // Formula action
    final outputKey = TextEditingController(
      text: existing?.action['output_key']?.toString() ?? 'qty',
    );
    final expression = TextEditingController(
      text: existing?.action['expression']?.toString() ?? 'qty_key * 1',
    );

    // Suggest action
    final match = existing?.action['match'] as Map<String, dynamic>? ?? {};
    var subSlug = match['sub_category_slug']?.toString() ??
        (_subCategories.isNotEmpty ? _subCategories.first.slug : '');
    final nameContains = TextEditingController(
      text: match['name_contains']?.toString() ?? '',
    );
    final qtyFormula = TextEditingController(
      text: existing?.action['qty_formula']?.toString() ?? '1',
    );

    // Visibility action
    final showKeys = <String>{
      ...?((existing?.action['show'] as List?)?.map((e) => e.toString())),
    };
    final hideKeys = <String>{
      ...?((existing?.action['hide'] as List?)?.map((e) => e.toString())),
    };

    const accent = Color(0xFF1D1D1F);
    const softBg = Color(0xFFF5F5F7);
    const border = Color(0xFFE5E5EA);
    const subtle = Color(0xFF6E6E73);

    InputDecoration deco(String label, {String? helper}) => InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          filled: true,
          fillColor: softBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 1.4),
          ),
        );

    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.36),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondary) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                            color: softBg,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEdit
                                            ? (scopeLabel != null
                                                ? 'Edit rule for “$scopeLabel”'
                                                : 'Edit rule')
                                            : (scopeLabel != null
                                                ? 'New rule for “$scopeLabel”'
                                                : 'New rule'),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.4,
                                          color: accent,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        scopeLabel != null
                                            ? 'This rule runs only when the customer selects “$scopeLabel”.'
                                            : 'Build conditions and actions with form fields — no JSON.',
                                        style: const TextStyle(fontSize: 13, color: subtle),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  icon: const Icon(Icons.close_rounded),
                                  color: subtle,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: name,
                                    decoration: deco(
                                      'Name',
                                      helper: 'e.g. Suggest recorder, cable qty',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('type-$ruleType'),
                                    initialValue: _ruleTypes.any((e) => e.$1 == ruleType)
                                        ? ruleType
                                        : 'suggest',
                                    decoration: deco('Rule type'),
                                    items: [
                                      for (final t in _ruleTypes)
                                        DropdownMenuItem(
                                          value: t.$1,
                                          child: Text(t.$2),
                                        ),
                                    ],
                                    onChanged: (v) =>
                                        setLocal(() => ruleType = v ?? 'suggest'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: priority,
                                    keyboardType: TextInputType.number,
                                    decoration: deco(
                                      'Priority',
                                      helper: 'Lower runs first (10, 20, 30…)',
                                    ),
                                  ),
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Active'),
                                    value: isActive,
                                    onChanged: (v) => setLocal(() => isActive = v),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'When (conditions)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'All conditions must match. Leave one empty row with no value for “always”.',
                                    style: TextStyle(fontSize: 12, color: subtle),
                                  ),
                                  const SizedBox(height: 10),
                                  for (var i = 0; i < clauses.length; i++) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: softBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: border),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  key: ValueKey('var-$i-${clauses[i].varKey}'),
                                                  initialValue: _questionKeys.contains(clauses[i].varKey)
                                                      ? clauses[i].varKey
                                                      : (_questionKeys.isNotEmpty
                                                          ? _questionKeys.first
                                                          : clauses[i].varKey),
                                                  decoration: deco('Question key'),
                                                  isExpanded: true,
                                                  items: [
                                                    for (final k in _questionKeys.isEmpty
                                                        ? [clauses[i].varKey]
                                                        : _questionKeys)
                                                      DropdownMenuItem(
                                                        value: k,
                                                        child: Text(k, overflow: TextOverflow.ellipsis),
                                                      ),
                                                  ],
                                                  onChanged: (v) => setLocal(() {
                                                    clauses[i].varKey = v ?? clauses[i].varKey;
                                                  }),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Remove',
                                                onPressed: clauses.length <= 1
                                                    ? null
                                                    : () => setLocal(() => clauses.removeAt(i)),
                                                icon: const Icon(Icons.delete_outline),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: DropdownButtonFormField<String>(
                                                  key: ValueKey('op-$i-${clauses[i].op}'),
                                                  initialValue: clauses[i].op,
                                                  decoration: deco('Operator'),
                                                  items: [
                                                    for (final o in _ops)
                                                      DropdownMenuItem(
                                                        value: o.$1,
                                                        child: Text(o.$2),
                                                      ),
                                                  ],
                                                  onChanged: (v) => setLocal(() {
                                                    clauses[i].op = v ?? 'eq';
                                                  }),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 3,
                                                child: TextFormField(
                                                  initialValue: clauses[i].value,
                                                  decoration: deco('Value'),
                                                  onChanged: (v) => clauses[i].value = v,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => setLocal(() {
                                        clauses.add(
                                          _RuleClause(
                                            varKey: _questionKeys.isNotEmpty
                                                ? _questionKeys.first
                                                : 'qty_key',
                                          ),
                                        );
                                      }),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add condition'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Then (action)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (ruleType == 'formula') ...[
                                    TextField(
                                      controller: outputKey,
                                      decoration: deco(
                                        'Output key',
                                        helper: 'Shown on quotation — e.g. line_qty',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: expression,
                                      decoration: deco(
                                        'Expression',
                                        helper: 'Use question keys — e.g. qty_key * 2',
                                      ),
                                    ),
                                  ] else if (ruleType == 'suggest') ...[
                                    DropdownButtonFormField<String>(
                                      key: ValueKey('slug-$subSlug'),
                                      initialValue: _subCategories.any((s) => s.slug == subSlug)
                                          ? subSlug
                                          : (_subCategories.isNotEmpty
                                              ? _subCategories.first.slug
                                              : null),
                                      decoration: deco('Shop subcategory'),
                                      isExpanded: true,
                                      items: [
                                        for (final s in _subCategories)
                                          DropdownMenuItem(
                                            value: s.slug,
                                            child: Text(
                                              '${s.name} (${s.slug})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) =>
                                          setLocal(() => subSlug = v ?? subSlug),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: nameContains,
                                      decoration: deco(
                                        'Product name contains (optional)',
                                        helper: 'e.g. product name keyword',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: qtyFormula,
                                      decoration: deco(
                                        'Quantity formula',
                                        helper: 'e.g. 1 or qty_key or qty_key / 4',
                                      ),
                                    ),
                                  ] else ...[
                                    const Text(
                                      'Show these questions',
                                      style: TextStyle(fontSize: 12, color: subtle),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final k in _questionKeys)
                                          FilterChip(
                                            label: Text(k),
                                            selected: showKeys.contains(k),
                                            showCheckmark: false,
                                            labelStyle: TextStyle(
                                              color: showKeys.contains(k)
                                                  ? Colors.white
                                                  : accent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            selectedColor: accent,
                                            backgroundColor: softBg,
                                            onSelected: (on) => setLocal(() {
                                              if (on) {
                                                showKeys.add(k);
                                                hideKeys.remove(k);
                                              } else {
                                                showKeys.remove(k);
                                              }
                                            }),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Hide these questions',
                                      style: TextStyle(fontSize: 12, color: subtle),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final k in _questionKeys)
                                          FilterChip(
                                            label: Text(k),
                                            selected: hideKeys.contains(k),
                                            showCheckmark: false,
                                            labelStyle: TextStyle(
                                              color: hideKeys.contains(k)
                                                  ? Colors.white
                                                  : accent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            selectedColor: Colors.red.shade700,
                                            backgroundColor: softBg,
                                            onSelected: (on) => setLocal(() {
                                              if (on) {
                                                hideKeys.add(k);
                                                showKeys.remove(k);
                                              } else {
                                                hideKeys.remove(k);
                                              }
                                            }),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            color: softBg,
                            child: Row(
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                const Spacer(),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(isEdit ? 'Save changes' : 'Create rule'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    final shouldSave = ok == true;
    final resolvedName =
        name.text.trim().isEmpty ? ruleType : name.text.trim();
    final pri = int.tryParse(priority.text.trim()) ?? 100;
    final condition = shouldSave ? _buildCondition(clauses) : <String, dynamic>{};
    final action = shouldSave
        ? switch (ruleType) {
            'formula' => <String, dynamic>{
                'type': 'formula',
                'output_key': outputKey.text.trim().isEmpty
                    ? 'qty'
                    : outputKey.text.trim(),
                'expression': expression.text.trim().isEmpty
                    ? '1'
                    : expression.text.trim(),
              },
            'visibility' => <String, dynamic>{
                'show': showKeys.toList(),
                'hide': hideKeys.toList(),
              },
            _ => <String, dynamic>{
                'type': 'suggest_product',
                'match': {
                  'sub_category_slug': subSlug,
                  if (nameContains.text.trim().isNotEmpty)
                    'name_contains': nameContains.text.trim(),
                },
                'qty_formula':
                    qtyFormula.text.trim().isEmpty ? '1' : qtyFormula.text.trim(),
              },
          }
        : <String, dynamic>{};

    await Future<void>.delayed(const Duration(milliseconds: 240));
    name.dispose();
    priority.dispose();
    outputKey.dispose();
    expression.dispose();
    nameContains.dispose();
    qtyFormula.dispose();

    if (!shouldSave) {
      return false;
    }

    try {
      if (isEdit) {
        await _repo.updateRule(
          id: existing.id,
          ruleType: ruleType,
          name: resolvedName,
          priority: pri,
          condition: condition,
          action: action,
          isActive: isActive,
          optionScopeFamilyId: scopeFamilyId,
          optionScopeAttributeId: scopeAttributeId,
          optionScopeLabel: scopeLabel,
        );
      } else {
        await _repo.createRule(
          templateId: templateId,
          ruleType: ruleType,
          name: resolvedName,
          priority: pri,
          condition: condition,
          action: action,
          isActive: isActive,
          optionScopeFamilyId: scopeFamilyId,
          optionScopeAttributeId: scopeAttributeId,
          optionScopeLabel: scopeLabel,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Rule updated' : 'Rule created')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
      return false;
    }
  }

  static List<_RuleClause> _parseClauses(Map<String, dynamic>? condition) {
    if (condition == null || condition.isEmpty) return [];
    final all = condition['all'];
    if (all is List) {
      return [
        for (final c in all)
          if (c is Map)
            _RuleClause(
              varKey: c['var']?.toString() ?? 'qty_key',
              op: c['op']?.toString() ?? 'eq',
              value: c['value']?.toString() ?? '',
            ),
      ];
    }
    if (condition['var'] != null) {
      return [
        _RuleClause(
          varKey: condition['var']?.toString() ?? 'qty_key',
          op: condition['op']?.toString() ?? 'eq',
          value: condition['value']?.toString() ?? '',
        ),
      ];
    }
    return [];
  }

  static Map<String, dynamic> _buildCondition(List<_RuleClause> clauses) {
    final usable = [
      for (final c in clauses)
        if (c.varKey.trim().isNotEmpty && c.value.trim().isNotEmpty)
          {
            'var': c.varKey.trim(),
            'op': c.op,
            'value': _smartValue(c.value.trim()),
          },
    ];
    if (usable.isEmpty) return {'all': <Map<String, dynamic>>[]};
    return {'all': usable};
  }

  static dynamic _smartValue(String raw) {
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(raw);
    if (asDouble != null) return asDouble;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Calculator rules',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _templateId == null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Rule'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Rules turn calculator answers into product suggestions and quantities. '
              'Select a template, then add suggest / formula / visibility rules.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_templates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _templateId,
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final t in _templates)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) async {
                  setState(() => _templateId = v);
                  await _loadRules();
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Create a template first (Calculator → Templates).'),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rules.isEmpty
                    ? const Center(
                        child: Text('No rules yet. Tap + Rule to create one.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                        itemCount: _rules.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (_, i) {
                          final r = _rules[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  switch (r.ruleType) {
                                    'formula' => Icons.functions,
                                    'visibility' || 'dependency' => Icons.visibility_outlined,
                                    _ => Icons.shopping_bag_outlined,
                                  },
                                  size: 20,
                                ),
                              ),
                              title: Text(r.name ?? r.ruleType),
                              subtitle: Text(
                                [
                                  r.ruleType,
                                  'priority ${r.priority}',
                                  r.isActive ? 'Active' : 'Inactive',
                                  if (r.hasOptionScope) 'Option: ${r.optionScopeLabel}',
                                  _summarizeRule(r),
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _edit(r);
                                  if (v == 'delete') _delete(r);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _edit(r),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _summarizeRule(CalculatorRule r) {
    if (r.ruleType == 'formula') {
      return '${r.action['output_key'] ?? '?'} = ${r.action['expression'] ?? '?'}';
    }
    if (r.ruleType == 'suggest' || r.ruleType == 'recommendation') {
      final match = r.action['match'] as Map?;
      return '${match?['sub_category_slug'] ?? '?'}'
          '${match?['name_contains'] != null ? ' · ${match!['name_contains']}' : ''}';
    }
    final show = (r.action['show'] as List?)?.length ?? 0;
    final hide = (r.action['hide'] as List?)?.length ?? 0;
    return 'show $show · hide $hide';
  }
}

class _RuleClause {
  _RuleClause({
    required this.varKey,
    this.op = 'eq',
    this.value = '',
  });

  String varKey;
  String op;
  String value;
}

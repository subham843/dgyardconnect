import 'package:flutter/material.dart';

import '../../shop/data/shop_catalog_repository.dart';
import '../../shop/domain/shop_attribute.dart';
import '../../shop/domain/shop_category.dart';
import '../data/calculator_repository.dart';
import '../domain/calculator_models.dart';

/// Editor dialog for option-based calculator rules.
///
/// Allows creating/editing rules that trigger when a family option is selected,
/// with optional additional question/answer conditions (When), and actions to
/// suggest products, calculate quantities, or run formulas (Then).
class OptionRuleEditor {
  OptionRuleEditor._();

  /// Shows the option rule editor dialog.
  ///
  /// Returns `true` if the rule was saved, `false` if cancelled, `null` on error.
  static Future<bool?> show({
    required BuildContext context,
    required CalculatorRepository repo,
    required ShopCatalogRepository catalog,
    required List<ShopSubCategory> subCategories,
    required List<ShopAttributeMaster> calcAttributes,
    required String familyId,
    required ShopAttributeMaster attribute,
    required String optionLabel,
    CalculatorRule? existing,
    int defaultPriority = 10,
    String? ruleGroupId,
    String? ruleGroupName,
    List<CalculatorFamilyAttributeLink> links = const [],
    List<CalculatorFamilyOptionPath> paths = const [],
    List<CalculatorQuestionGroup> groups = const [],
    List<CalculatorQuestion> familyQuestions = const [],
  }) async {
    if (!context.mounted) return false;

    final templateId = await repo.ensureTemplateForFamily(familyId);
    if (templateId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create a template for this family.'),
          ),
        );
      }
      return false;
    }

    final numberQuestions = <(String key, String label)>[];
    final seenNumKeys = <String>{};
    void addNumQ(String key, String label) {
      if (key.isEmpty || !seenNumKeys.add(key)) return;
      numberQuestions.add((
        key,
        label.trim().isEmpty ? key : '$label ($key)',
      ));
    }

    for (final q in familyQuestions) {
      if (q.uiType == 'number' || q.uiType == 'slider' || q.uiType == 'integer') {
        addNumQ(q.questionKey, q.label);
      }
    }
    for (final p in paths) {
      for (final q in p.questions) {
        if (q.uiType == 'number' || q.uiType == 'slider' || q.uiType == 'integer') {
          addNumQ(q.questionKey, q.label);
        }
      }
    }
    final groupNameById = <String, String>{
      for (final g in groups) g.id: g.name,
    };

    ShopAttributeMaster? masterById(String id) =>
        calcAttributes.where((a) => a.id == id).firstOrNull;
    ShopAttributeMaster? masterByKey(String key) =>
        calcAttributes.where((a) => a.key == key).firstOrNull;

    final rootAttrs = <ShopAttributeMaster>[
      for (final l in links)
        if (masterById(l.attributeId) != null) masterById(l.attributeId)!,
    ];
    if (rootAttrs.isEmpty) {
      rootAttrs.add(attribute);
    }

    var selectedAttrId = attribute.id;
    if (!rootAttrs.any((a) => a.id == selectedAttrId)) {
      selectedAttrId = rootAttrs.first.id;
    }
    var selectedOption = optionLabel;

    List<String> optionsForAttr(String attrId) {
      final master = masterById(attrId);
      if (master == null) return const [];
      final link = links.where((l) => l.attributeId == attrId).firstOrNull;
      final selected = link?.selectedOptions;
      if (selected != null && selected.isNotEmpty) return selected;
      return master.effectiveOptions;
    }

    List<CalculatorFamilyOptionPathQuestion> pathQsFor(
      String attrId,
      String option,
    ) {
      for (final p in paths) {
        if (p.parentAttributeId == attrId && p.optionLabel == option) {
          if (p.questions.isNotEmpty) return p.questions;
          // Legacy: path attributes as questions
          return [
            for (final a in p.attributes)
              if (masterById(a.attributeId) != null)
                CalculatorFamilyOptionPathQuestion(
                  questionKey: masterById(a.attributeId)!.key,
                  label: masterById(a.attributeId)!.label,
                  uiType: masterById(a.attributeId)!
                          .effectiveOptions
                          .isNotEmpty
                      ? 'select'
                      : 'number',
                  options: a.selectedOptions ??
                      masterById(a.attributeId)!.effectiveOptions,
                  sourceAttributeId: a.attributeId,
                  sortOrder: a.sortOrder,
                  groupId: a.groupId,
                ),
          ];
        }
      }
      return const [];
    }

    String? groupLabelFor({String? groupId, String? attrId}) {
      if (groupId != null && groupNameById[groupId] != null) {
        return groupNameById[groupId];
      }
      if (attrId != null) {
        final link = links.where((l) => l.attributeId == attrId).firstOrNull;
        final gid = link?.groupId;
        if (gid != null) return groupNameById[gid];
      }
      return null;
    }

    List<_WhenAnswerRow> buildAnswerRows({
      required String attrId,
      required String option,
      Map<String, _WhenAnswerRow>? keep,
    }) {
      final rows = <_WhenAnswerRow>[];
      final seen = <String>{};
      final parent = masterById(attrId) ?? attribute;

      void addRow(_WhenAnswerRow row) {
        if (row.key.isEmpty || seen.contains(row.key)) return;
        seen.add(row.key);
        final prev = keep?[row.key];
        if (prev != null) {
          rows.add(
            prev.copyWith(
              label: row.label,
              uiType: row.uiType,
              options: row.options,
              groupName: row.groupName,
              section: row.section,
            ),
          );
        } else {
          rows.add(row);
        }
      }

      // 1) Path questions saved under this option (HD / IP / …)
      for (final q in pathQsFor(attrId, option)) {
        final opts = [
          for (final o in q.options ?? const <String>[])
            if (o.trim().isNotEmpty) o.trim(),
        ];
        final gName = groupLabelFor(groupId: q.groupId);
        final isNumber = q.uiType == 'number' ||
            q.uiType == 'slider' ||
            q.uiType == 'integer';
        addRow(
          _WhenAnswerRow(
            key: q.questionKey,
            label: q.label.trim().isEmpty ? q.questionKey : q.label.trim(),
            uiType: q.uiType,
            options: opts,
            groupName: gName,
            section: gName == null
                ? 'Under "$option"'
                : 'Under "$option" · $gName',
            enabled: false,
            op: isNumber ? 'gte' : (opts.isNotEmpty ? 'eq' : 'eq'),
            value: opts.isNotEmpty ? opts.first : '',
            valueMax: '',
          ),
        );
      }

      // 2) All family / template questions (custom qty, group questions, etc.)
      //    — not only shop attributes.
      for (final q in familyQuestions) {
        if (q.questionKey == parent.key) continue;
        final depKey = (q.showWhenKey ?? '').trim();
        if (depKey.isNotEmpty) {
          // Other option's path question (e.g. IP when editing HD) → skip
          if (depKey != parent.key) continue;
          final expected = (q.showWhenValue ?? '').toString();
          if (expected.isNotEmpty && expected != option) continue;
        }
        final opts = [
          for (final o in q.options ?? const <String>[])
            if (o.trim().isNotEmpty) o.trim(),
        ];
        final gName = (q.groupName ?? '').trim().isNotEmpty
            ? q.groupName!.trim()
            : groupLabelFor(groupId: q.groupId);
        final underOption = depKey.isNotEmpty;
        final isNumber = q.uiType == 'number' ||
            q.uiType == 'slider' ||
            q.uiType == 'integer';
        addRow(
          _WhenAnswerRow(
            key: q.questionKey,
            label: q.label.trim().isEmpty ? q.questionKey : q.label.trim(),
            uiType: q.uiType,
            options: opts,
            groupName: gName,
            section: underOption
                ? (gName == null
                    ? 'Under "$option"'
                    : 'Under "$option" · $gName')
                : (gName == null ? 'Other questions' : 'Group: $gName'),
            enabled: false,
            op: isNumber ? 'gte' : (opts.isNotEmpty ? 'eq' : 'eq'),
            value: opts.isNotEmpty ? opts.first : '',
            valueMax: '',
          ),
        );
      }

      // 3) Remaining family-linked shop attributes (any group)
      for (final l in links) {
        if (l.attributeId == attrId) continue;
        final m = masterById(l.attributeId);
        if (m == null) continue;
        final opts = [
          for (final o in (l.selectedOptions ?? m.effectiveOptions))
            if (o.trim().isNotEmpty) o.trim(),
        ];
        final gName = groupLabelFor(groupId: l.groupId, attrId: m.id);
        addRow(
          _WhenAnswerRow(
            key: m.key,
            label: m.label.trim().isEmpty ? m.key : m.label.trim(),
            uiType: opts.isNotEmpty ? 'select' : 'number',
            options: opts,
            groupName: gName,
            section: gName == null ? 'Family attributes' : 'Group: $gName',
            enabled: false,
            op: opts.isNotEmpty ? 'eq' : 'gte',
            value: opts.isNotEmpty ? opts.first : '',
            valueMax: '',
          ),
        );
      }

      return rows;
    }

    // Seed from existing rule conditions
    final parsed = _parseOptionRuleClauses(existing?.condition);
    var answerRows = buildAnswerRows(
      attrId: selectedAttrId,
      option: selectedOption,
    );
    if (parsed.isNotEmpty) {
      // Infer selected option from parent attr condition if present
      final parentKey = (masterById(selectedAttrId) ?? attribute).key;
      for (final c in parsed) {
        if (c.varKey == parentKey && c.op == 'eq' && c.value.isNotEmpty) {
          selectedOption = c.value;
          break;
        }
      }
      // Also try matching option from any root attr
      for (final c in parsed) {
        final m = masterByKey(c.varKey);
        if (m != null &&
            rootAttrs.any((a) => a.id == m.id) &&
            c.op == 'eq' &&
            optionsForAttr(m.id).contains(c.value)) {
          selectedAttrId = m.id;
          selectedOption = c.value;
          break;
        }
      }
      answerRows = buildAnswerRows(
        attrId: selectedAttrId,
        option: selectedOption,
      );

      // Apply gte/lte pairs and single clauses onto rows
      final byKey = <String, List<_OptionRuleClause>>{};
      for (final c in parsed) {
        final parent = masterById(selectedAttrId) ?? attribute;
        if (c.varKey == parent.key) continue;
        byKey.putIfAbsent(c.varKey, () => []).add(c);
      }
      for (var i = 0; i < answerRows.length; i++) {
        final list = byKey[answerRows[i].key];
        if (list == null || list.isEmpty) continue;
        final gte = list.where((c) => c.op == 'gte').firstOrNull;
        final lte = list.where((c) => c.op == 'lte').firstOrNull;
        if (gte != null && lte != null) {
          answerRows[i] = answerRows[i].copyWith(
            enabled: true,
            op: 'between',
            value: gte.value,
            valueMax: lte.value,
          );
        } else {
          final c = list.first;
          answerRows[i] = answerRows[i].copyWith(
            enabled: true,
            op: c.op,
            value: c.value,
          );
        }
      }

      // Orphan conditions (not in path/family list) → add as custom rows
      final known = {for (final r in answerRows) r.key};
      for (final c in parsed) {
        final parent = masterById(selectedAttrId) ?? attribute;
        if (c.varKey == parent.key || known.contains(c.varKey)) continue;
        answerRows.add(
          _WhenAnswerRow(
            key: c.varKey,
            label: c.varKey,
            uiType: 'text',
            options: const [],
            section: 'Custom',
            enabled: true,
            op: c.op,
            value: c.value,
            valueMax: '',
          ),
        );
        known.add(c.varKey);
      }
    }

    final opts = optionsForAttr(selectedAttrId);
    if (opts.isNotEmpty && !opts.contains(selectedOption)) {
      selectedOption = opts.first;
      answerRows = buildAnswerRows(
        attrId: selectedAttrId,
        option: selectedOption,
      );
    }

    final resolvedGroupId =
        (existing?.ruleGroupId ?? ruleGroupId ?? '').trim();
    final resolvedGroupName =
        (existing?.ruleGroupName ?? ruleGroupName ?? '').trim();

    final name = TextEditingController(text: existing?.name ?? '');
    final priority = TextEditingController(
      text: '${existing?.priority ?? defaultPriority}',
    );
    var ruleType = existing?.ruleType ?? 'suggest';
    if (ruleType == 'recommendation') ruleType = 'suggest';
    if (ruleType == 'dependency' || ruleType == 'visibility') {
      ruleType = 'suggest';
    }
    if ((existing?.action['type']?.toString() ?? '') == 'qty_from_question') {
      ruleType = 'qty_scale';
    }
    if ((existing?.action['type']?.toString() ?? '') == 'charge_line') {
      ruleType = 'charge_line';
    }
    var isActive = existing?.isActive ?? true;
    var editorStep = 0; // 0 = When, 1 = Then
    var qtyQuestionKey = existing?.action['question_key']?.toString() ??
        (numberQuestions.isNotEmpty ? numberQuestions.first.$1 : '');
    if (qtyQuestionKey.isNotEmpty &&
        numberQuestions.isNotEmpty &&
        !numberQuestions.any((q) => q.$1 == qtyQuestionKey)) {
      qtyQuestionKey = numberQuestions.first.$1;
    }
    var qtyMatchGroupId =
        existing?.action['match_group_id']?.toString().trim() ?? '';
    // Suggest-product: which question group shows the product cards (optional).
    var suggestShowGroupId =
        (existing?.action['type']?.toString() == 'suggest_product'
                ? existing?.action['match_group_id']?.toString().trim()
                : null) ??
            '';
    // Suggest-product: pin cards directly under a question (e.g. indoor_qty).
    var suggestShowUnderQuestion =
        (existing?.action['show_under_question']?.toString().trim().isNotEmpty ==
                true
            ? existing!.action['show_under_question'].toString().trim()
            : (existing?.action['qty_var']?.toString().trim() ?? ''));
    // Legacy field — product match filter is the real target now.
    const qtyApplyTo = 'attribute_matches';

    final match = existing?.action['match'] as Map<String, dynamic>? ?? {};
    var subSlug = match['sub_category_slug']?.toString() ??
        (subCategories.isNotEmpty ? subCategories.first.slug : '');
    final nameContains = TextEditingController(
      text: match['name_contains']?.toString() ?? '',
    );
    final qtyFormula = TextEditingController(
      text: existing?.action['qty_formula']?.toString() ??
          existing?.action['expression']?.toString() ??
          '1',
    );
    final outputKey = TextEditingController(
      text: existing?.action['output_key']?.toString() ?? 'qty',
    );
    final chargeLabel = TextEditingController(
      text: existing?.action['label']?.toString() ??
          existing?.name ??
          'Installation charge',
    );
    final chargeUnitPrice = TextEditingController(
      text: existing?.action['unit_price']?.toString() ?? '300',
    );
    var chargeQtyVar = existing?.action['qty_var']?.toString().trim() ??
        (numberQuestions.isNotEmpty ? numberQuestions.first.$1 : '');
    var chargeShowUnder = existing?.action['show_under_question']?.toString().trim() ??
        '';

    final existingAttrMatch = <String, String>{};
    final rawMatchAttrs = match['attributes'];
    if (rawMatchAttrs is Map) {
      for (final e in rawMatchAttrs.entries) {
        final k = e.key.toString().trim();
        final v = e.value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) existingAttrMatch[k] = v;
      }
    }

    var thenAttrRows = <_ThenAttrFilter>[];
    var thenAttrsLoading = false;
    var thenProducts = <({String id, String label})>[];
    var selectedProductId = match['product_id']?.toString().trim() ?? '';

    Future<void> loadThenAttrs(
      String slug, {
      Map<String, String>? keep,
    }) async {
      final sub = subCategories.where((s) => s.slug == slug).firstOrNull;
      if (sub == null) {
        thenAttrRows = [];
        return;
      }
      final attrs = await catalog.listAttributesForSubCategory(sub.id);
      thenAttrRows = [
        for (final a in attrs)
          _ThenAttrFilter(
            key: a.key,
            label: a.label.trim().isEmpty ? a.key : a.label.trim(),
            options: [
              for (final o in a.effectiveOptions)
                if (o.trim().isNotEmpty) o.trim(),
            ],
            enabled: keep?.containsKey(a.key) ?? false,
            value: keep?[a.key] ??
                (a.effectiveOptions.isNotEmpty
                    ? a.effectiveOptions.first
                    : ''),
          ),
      ];
    }

    Future<void> loadThenProducts(String slug) async {
      final sub = subCategories.where((s) => s.slug == slug).firstOrNull;
      if (sub == null) {
        thenProducts = [];
        selectedProductId = '';
        return;
      }
      final products = await catalog.listProducts(
        subCategoryId: sub.id,
        activeOnly: true,
        limit: 500,
      );
      thenProducts = [
        for (final p in products)
          (
            id: p.id,
            label: p.sku.trim().isEmpty
                ? p.name
                : '${p.name} (${p.sku})',
          ),
      ]..sort((a, b) => a.label.compareTo(b.label));
      if (selectedProductId.isNotEmpty &&
          !thenProducts.any((p) => p.id == selectedProductId)) {
        selectedProductId = '';
      }
    }

    Future<void> loadThenSubData(
      String slug, {
      Map<String, String>? keepAttrs,
      bool clearProduct = false,
    }) async {
      if (clearProduct) selectedProductId = '';
      await Future.wait([
        loadThenAttrs(slug, keep: keepAttrs),
        loadThenProducts(slug),
      ]);
    }

    thenAttrsLoading = true;
    await loadThenSubData(subSlug, keepAttrs: existingAttrMatch);
    thenAttrsLoading = false;

    const accent = Color(0xFF1D1D1F);
    const subtle = Color(0xFF6E6E73);
    const border = Color(0xFFE5E5EA);
    const softBg = Color(0xFFF5F5F7);
    const whenBg = Color(0xFFF0F7FF);
    const thenBg = Color(0xFFF3FBF4);

    InputDecoration deco(String label, {String? helper}) => InputDecoration(
          labelText: label,
          helperText: helper,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        );

    const compareOps = <(String, String)>[
      ('eq', 'Equals'),
      ('neq', 'Not equals'),
      ('gte', 'At least (≥)'),
      ('lte', 'At most (≤)'),
      ('gt', 'More than (>)'),
      ('lt', 'Less than (<)'),
      ('between', 'Between'),
    ];

    void disposeAll() {
      name.dispose();
      priority.dispose();
      nameContains.dispose();
      qtyFormula.dispose();
      outputKey.dispose();
      chargeLabel.dispose();
      chargeUnitPrice.dispose();
    }

    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final optionChoices = optionsForAttr(selectedAttrId);

          // Group answer rows by section for display
          final sectionOrder = <String>[];
          final bySection = <String, List<int>>{};
          for (var i = 0; i < answerRows.length; i++) {
            final s = answerRows[i].section;
            if (!bySection.containsKey(s)) {
              sectionOrder.add(s);
              bySection[s] = [];
            }
            bySection[s]!.add(i);
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            title: Text(
              existing != null
                  ? 'Edit rule'
                  : (resolvedGroupName.isNotEmpty
                      ? 'Add rule in "$resolvedGroupName"'
                      : 'Add rule'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (resolvedGroupName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: softBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          'Group: $resolvedGroupName — name is optional; leave blank to auto-label.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: subtle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Step chrome: When → Then
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setD(() => editorStep = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: editorStep == 0
                                    ? whenBg
                                    : softBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: editorStep == 0
                                      ? const Color(0xFFD6E8FF)
                                      : border,
                                ),
                              ),
                              child: Text(
                                '1 · When',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: editorStep == 0 ? accent : subtle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, size: 16, color: subtle),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setD(() => editorStep = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: editorStep == 1
                                    ? thenBg
                                    : softBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: editorStep == 1
                                      ? const Color(0xFFCDEBD3)
                                      : border,
                                ),
                              ),
                              child: Text(
                                '2 · Then',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: editorStep == 1 ? accent : subtle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── WHEN ──
                    if (editorStep == 0)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: whenBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD6E8FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'When',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'If the customer picks this family option — and optionally these answers — then run the action below. Works for CCTV, PC, EPABX, solar, or any family.',
                            style: TextStyle(fontSize: 12, height: 1.35, color: subtle),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '1. Family option',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('attr-$selectedAttrId'),
                                  initialValue: selectedAttrId,
                                  decoration: deco('Attribute'),
                                  isExpanded: true,
                                  items: [
                                    for (final a in rootAttrs)
                                      DropdownMenuItem(
                                        value: a.id,
                                        child: Text(
                                          a.label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setD(() {
                                      selectedAttrId = v;
                                      final nextOpts = optionsForAttr(v);
                                      selectedOption = nextOpts.isNotEmpty
                                          ? nextOpts.first
                                          : '';
                                      answerRows = buildAnswerRows(
                                        attrId: selectedAttrId,
                                        option: selectedOption,
                                      );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'opt-$selectedAttrId-$selectedOption',
                                  ),
                                  initialValue: optionChoices.contains(selectedOption)
                                      ? selectedOption
                                      : (optionChoices.isNotEmpty
                                          ? optionChoices.first
                                          : null),
                                  decoration: deco('Option'),
                                  isExpanded: true,
                                  items: [
                                    for (final o in optionChoices)
                                      DropdownMenuItem(
                                        value: o,
                                        child: Text(
                                          o,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setD(() {
                                      final keep = {
                                        for (final r in answerRows)
                                          if (r.enabled) r.key: r,
                                      };
                                      selectedOption = v;
                                      answerRows = buildAnswerRows(
                                        attrId: selectedAttrId,
                                        option: selectedOption,
                                        keep: keep,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '2. Questions / attributes to match (optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            answerRows.isEmpty
                                ? 'No follow-up questions yet. Add path questions or group questions on the family — custom number fields (qty) and attributes both appear here.'
                                : 'Turn on any question under "$selectedOption", any group question (even without shop attributes), or other family attributes. All turned-on rows must match (AND).',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: subtle,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (answerRows.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: const Text(
                                'Tip: In Family master, open this option and add questions — they will appear here for When.',
                                style: TextStyle(fontSize: 12, color: subtle),
                              ),
                            )
                          else
                            for (final section in sectionOrder) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 6),
                                child: Text(
                                  section,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: subtle,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              for (final i in bySection[section]!) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: answerRows[i].enabled
                                          ? const Color(0xFF7EB6FF)
                                          : border,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: Text(
                                          answerRows[i].label,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: accent,
                                          ),
                                        ),
                                        subtitle: Text(
                                          answerRows[i].key,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: subtle,
                                          ),
                                        ),
                                        value: answerRows[i].enabled,
                                        onChanged: (v) => setD(() {
                                          answerRows[i] =
                                              answerRows[i].copyWith(enabled: v);
                                        }),
                                      ),
                                      if (answerRows[i].enabled) ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: DropdownButtonFormField<String>(
                                                key: ValueKey(
                                                  'op-$i-${answerRows[i].op}',
                                                ),
                                                initialValue: answerRows[i].op,
                                                decoration: deco('Match'),
                                                items: [
                                                  for (final o in compareOps)
                                                    if (answerRows[i]
                                                            .options
                                                            .isNotEmpty
                                                        ? (o.$1 == 'eq' ||
                                                            o.$1 == 'neq')
                                                        : true)
                                                      DropdownMenuItem(
                                                        value: o.$1,
                                                        child: Text(o.$2),
                                                      ),
                                                ],
                                                onChanged: (v) => setD(() {
                                                  answerRows[i] =
                                                      answerRows[i].copyWith(
                                                    op: v ?? 'eq',
                                                  );
                                                }),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: answerRows[i]
                                                          .options
                                                          .isNotEmpty &&
                                                      (answerRows[i].op ==
                                                              'eq' ||
                                                          answerRows[i].op ==
                                                              'neq')
                                                  ? DropdownButtonFormField<
                                                      String>(
                                                      key: ValueKey(
                                                        'val-$i-${answerRows[i].value}',
                                                      ),
                                                      initialValue: answerRows[i]
                                                              .options
                                                              .contains(
                                                        answerRows[i].value,
                                                      )
                                                          ? answerRows[i].value
                                                          : answerRows[i]
                                                              .options
                                                              .first,
                                                      decoration: deco('Value'),
                                                      isExpanded: true,
                                                      items: [
                                                        for (final o
                                                            in answerRows[i]
                                                                .options)
                                                          DropdownMenuItem(
                                                            value: o,
                                                            child: Text(
                                                              o,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                      ],
                                                      onChanged: (v) => setD(() {
                                                        answerRows[i] =
                                                            answerRows[i]
                                                                .copyWith(
                                                          value: v ??
                                                              answerRows[i]
                                                                  .value,
                                                        );
                                                      }),
                                                    )
                                                  : TextFormField(
                                                      key: ValueKey(
                                                        'valt-$i-${answerRows[i].key}',
                                                      ),
                                                      initialValue:
                                                          answerRows[i].value,
                                                      decoration: deco(
                                                        answerRows[i].op ==
                                                                'between'
                                                            ? 'Min'
                                                            : 'Value',
                                                      ),
                                                      onChanged: (v) =>
                                                          answerRows[i] =
                                                              answerRows[i]
                                                                  .copyWith(
                                                        value: v,
                                                      ),
                                                    ),
                                            ),
                                            if (answerRows[i].op ==
                                                'between') ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: TextFormField(
                                                  key: ValueKey(
                                                    'vmax-$i-${answerRows[i].key}',
                                                  ),
                                                  initialValue:
                                                      answerRows[i].valueMax,
                                                  decoration: deco('Max'),
                                                  onChanged: (v) =>
                                                      answerRows[i] =
                                                          answerRows[i]
                                                              .copyWith(
                                                    valueMax: v,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── THEN ──
                    if (editorStep == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: thenBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCDEBD3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Then',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'What should the calculator show or calculate when When matches.',
                            style: TextStyle(fontSize: 12, height: 1.35, color: subtle),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('rtype-$ruleType'),
                            initialValue: ruleType == 'formula'
                                ? 'formula'
                                : (ruleType == 'qty_scale'
                                    ? 'qty_scale'
                                    : (ruleType == 'charge_line'
                                        ? 'charge_line'
                                        : 'suggest')),
                            decoration: deco('Action'),
                            items: const [
                              DropdownMenuItem(
                                value: 'suggest',
                                child: Text('Suggest a shop product'),
                              ),
                              DropdownMenuItem(
                                value: 'qty_scale',
                                child: Text(
                                  'Multiply product price by a number answer',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'charge_line',
                                child: Text(
                                  'Installation / labour charge (rate × qty)',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'formula',
                                child: Text('Calculate a quantity / formula'),
                              ),
                            ],
                            onChanged: (v) =>
                                setD(() => ruleType = v ?? 'suggest'),
                          ),
                          const SizedBox(height: 12),
                          if (ruleType == 'qty_scale') ...[
                            const Text(
                              'Only ONE target product (subcategory + attributes) gets price x number answer. Other quotation items stay unchanged.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: subtle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (numberQuestions.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: border),
                                ),
                                child: const Text(
                                  'No number questions in this family yet. Add a custom number question (e.g. Quantity) on the option path, then come back.',
                                  style: TextStyle(fontSize: 12, color: subtle),
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                key: ValueKey('qtyq-$qtyQuestionKey'),
                                initialValue: numberQuestions
                                        .any((q) => q.$1 == qtyQuestionKey)
                                    ? qtyQuestionKey
                                    : numberQuestions.first.$1,
                                decoration: deco(
                                  'Number question',
                                  helper:
                                      'User types 3 → only the target product x 3',
                                ),
                                isExpanded: true,
                                items: [
                                  for (final q in numberQuestions)
                                    DropdownMenuItem(
                                      value: q.$1,
                                      child: Text(
                                        q.$2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setD(() {
                                  qtyQuestionKey = v ?? qtyQuestionKey;
                                }),
                              ),
                            const SizedBox(height: 14),
                            const Text(
                              'Target product',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pick a specific product to multiply its price by the number answer. Attributes are optional — if the product has no attributes, just select the product.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: subtle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey('qty-slug-$subSlug'),
                              initialValue:
                                  subCategories.any((s) => s.slug == subSlug)
                                      ? subSlug
                                      : (subCategories.isNotEmpty
                                          ? subCategories.first.slug
                                          : null),
                              decoration: deco('Shop subcategory'),
                              isExpanded: true,
                              items: [
                                for (final s in subCategories)
                                  DropdownMenuItem(
                                    value: s.slug,
                                    child: Text(
                                      '${s.name} (${s.slug})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) async {
                                final next = v ?? subSlug;
                                setD(() {
                                  subSlug = next;
                                  thenAttrsLoading = true;
                                });
                                final keep = {
                                  for (final r in thenAttrRows)
                                    if (r.enabled && r.value.trim().isNotEmpty)
                                      r.key: r.value.trim(),
                                };
                                await loadThenSubData(
                                  next,
                                  keepAttrs: keep,
                                  clearProduct: true,
                                );
                                if (ctx.mounted) {
                                  setD(() => thenAttrsLoading = false);
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            if (thenAttrsLoading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'qty-prod-$subSlug-$selectedProductId-${thenProducts.length}',
                              ),
                              initialValue: selectedProductId.isEmpty
                                  ? ''
                                  : (thenProducts.any(
                                          (p) => p.id == selectedProductId)
                                      ? selectedProductId
                                      : ''),
                              decoration: deco(
                                'Specific product',
                                helper: selectedProductId.isEmpty
                                    ? (thenAttrRows.isEmpty
                                        ? 'Recommended: pick one product (no attributes on this subcategory)'
                                        : 'Or leave empty and filter by attributes below')
                                    : 'Only this product price x number answer',
                              ),
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    thenAttrRows.isEmpty
                                        ? 'Select a product...'
                                        : 'Any matching product (use attributes)',
                                  ),
                                ),
                                for (final p in thenProducts)
                                  DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      p.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setD(() {
                                selectedProductId = v ?? '';
                              }),
                            ),
                            if (selectedProductId.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: border),
                                ),
                                child: Text(
                                  'Specific product selected — attributes are not needed. Estimate uses this product unit price x the number answer.',
                                  style: TextStyle(fontSize: 12, color: subtle),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              if (thenAttrsLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              else if (thenAttrRows.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: border),
                                  ),
                                  child: Text(
                                    'No attributes on this subcategory. Select a specific product above to multiply only that product price.',
                                    style: TextStyle(fontSize: 12, color: subtle),
                                  ),
                                )
                              else ...[
                                const Text(
                                  'Or filter by attributes (optional)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: subtle,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (var i = 0; i < thenAttrRows.length; i++)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      2,
                                      8,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: thenAttrRows[i].enabled
                                            ? const Color(0xFF8FCF9A)
                                            : border,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        SwitchListTile.adaptive(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(
                                            thenAttrRows[i].label,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: accent,
                                            ),
                                          ),
                                          subtitle: Text(
                                            thenAttrRows[i].key,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: subtle,
                                            ),
                                          ),
                                          value: thenAttrRows[i].enabled,
                                          onChanged: (v) => setD(() {
                                            thenAttrRows[i] = thenAttrRows[i]
                                                .copyWith(enabled: v);
                                          }),
                                        ),
                                        if (thenAttrRows[i].enabled)
                                          thenAttrRows[i].options.isNotEmpty
                                              ? DropdownButtonFormField<String>(
                                                  key: ValueKey(
                                                    'qta-$i-${thenAttrRows[i].value}',
                                                  ),
                                                  initialValue: thenAttrRows[i]
                                                          .options
                                                          .contains(
                                                        thenAttrRows[i].value,
                                                      )
                                                      ? thenAttrRows[i].value
                                                      : thenAttrRows[i]
                                                          .options
                                                          .first,
                                                  decoration: deco('Value'),
                                                  isExpanded: true,
                                                  items: [
                                                    for (final o
                                                        in thenAttrRows[i]
                                                            .options)
                                                      DropdownMenuItem(
                                                        value: o,
                                                        child: Text(
                                                          o,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                  onChanged: (v) => setD(() {
                                                    thenAttrRows[i] =
                                                        thenAttrRows[i]
                                                            .copyWith(
                                                      value: v ??
                                                          thenAttrRows[i]
                                                              .value,
                                                    );
                                                  }),
                                                )
                                              : TextFormField(
                                                  key: ValueKey(
                                                    'qtat-$i-${thenAttrRows[i].key}',
                                                  ),
                                                  initialValue:
                                                      thenAttrRows[i].value,
                                                  decoration: deco('Value'),
                                                  onChanged: (v) =>
                                                      thenAttrRows[i] =
                                                          thenAttrRows[i]
                                                              .copyWith(
                                                    value: v,
                                                  ),
                                                ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameContains,
                              decoration: deco(
                                'Product name contains (optional)',
                                helper: 'Further narrow to one product title',
                              ),
                            ),
                            if (groups.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey('qty-group-$qtyMatchGroupId'),
                                initialValue: qtyMatchGroupId.isEmpty
                                    ? ''
                                    : (groups.any((g) => g.id == qtyMatchGroupId)
                                        ? qtyMatchGroupId
                                        : ''),
                                decoration: deco(
                                  'Question group (optional)',
                                  helper:
                                      'Only the product under this group (e.g. Camera)',
                                ),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Any group'),
                                  ),
                                  for (final g in groups)
                                    DropdownMenuItem(
                                      value: g.id,
                                      child: Text(
                                        g.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setD(() {
                                  qtyMatchGroupId = v ?? '';
                                }),
                              ),
                            ],
                          ] else if (ruleType == 'charge_line') ...[
                            const Text(
                              'Adds a priced line to the estimate: unit rate × a number answer (cable meters or camera count).',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: subtle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: chargeLabel,
                              decoration: deco('Line label'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: chargeUnitPrice,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: deco(
                                'Rate (₹ per unit)',
                                helper: 'e.g. 300 per meter, or 500 per camera',
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey('charge-qty-$chargeQtyVar'),
                              initialValue: () {
                                final keys = <String>{
                                  for (final q in numberQuestions) q.$1,
                                  for (final q in familyQuestions)
                                    if (q.uiType == 'number' ||
                                        q.uiType == 'slider' ||
                                        q.uiType == 'integer')
                                      q.questionKey,
                                  'Number of Camers',
                                  'Cable Lenght In Meter',
                                };
                                return keys.contains(chargeQtyVar)
                                    ? chargeQtyVar
                                    : (keys.isNotEmpty ? keys.first : '');
                              }(),
                              decoration: deco(
                                'Quantity from question',
                                helper:
                                    'Meters or cameras — total = rate × this answer',
                              ),
                              isExpanded: true,
                              items: [
                                for (final q in {
                                  for (final n in numberQuestions)
                                    n.$1: n.$2.trim().isEmpty ? n.$1 : '${n.$2} (${n.$1})',
                                  for (final q in familyQuestions)
                                    if (q.uiType == 'number' ||
                                        q.uiType == 'slider' ||
                                        q.uiType == 'integer')
                                      q.questionKey:
                                          '${q.label} (${q.questionKey})',
                                  'Number of Camers':
                                      'Total cameras (indoor+outdoor)',
                                  'Cable Lenght In Meter':
                                      'Cable length (meters)',
                                }.entries)
                                  DropdownMenuItem(
                                    value: q.key,
                                    child: Text(
                                      q.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setD(() => chargeQtyVar = v ?? ''),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey('charge-under-$chargeShowUnder'),
                              initialValue: () {
                                final keys = <String>{
                                  for (final q in familyQuestions) q.questionKey,
                                  'wiring_type',
                                };
                                return keys.contains(chargeShowUnder)
                                    ? chargeShowUnder
                                    : '';
                              }(),
                              decoration: deco(
                                'Show under question (optional)',
                                helper:
                                    'e.g. Wiring type — charge appears below that field',
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Section footer / estimate only'),
                                ),
                                for (final q in familyQuestions)
                                  DropdownMenuItem(
                                    value: q.questionKey,
                                    child: Text(
                                      q.label.trim().isEmpty
                                          ? q.questionKey
                                          : '${q.label} (${q.questionKey})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (!familyQuestions
                                    .any((q) => q.questionKey == 'wiring_type'))
                                  const DropdownMenuItem(
                                    value: 'wiring_type',
                                    child: Text('Wiring type (wiring_type)'),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setD(() => chargeShowUnder = v ?? ''),
                            ),
                            if (groups.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey('charge-group-$suggestShowGroupId'),
                                initialValue: suggestShowGroupId.isEmpty
                                    ? ''
                                    : (groups.any((g) => g.id == suggestShowGroupId)
                                        ? suggestShowGroupId
                                        : ''),
                                decoration: deco('Show under group (optional)'),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('None'),
                                  ),
                                  for (final g in groups)
                                    DropdownMenuItem(
                                      value: g.id,
                                      child: Text(
                                        g.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setD(() {
                                  suggestShowGroupId = v ?? '';
                                }),
                              ),
                            ],
                          ] else if (ruleType == 'formula') ...[
                            TextField(
                              controller: outputKey,
                              decoration: deco(
                                'Output key',
                                helper: 'Shown on quotation — e.g. cable_qty',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: qtyFormula,
                              decoration: deco(
                                'Expression',
                                helper:
                                    'Use a question key — e.g. qty_key * 2',
                              ),
                            ),
                          ] else ...[
                            DropdownButtonFormField<String>(
                              key: ValueKey('slug-$subSlug'),
                              initialValue:
                                  subCategories.any((s) => s.slug == subSlug)
                                      ? subSlug
                                      : (subCategories.isNotEmpty
                                          ? subCategories.first.slug
                                          : null),
                              decoration: deco('Shop subcategory'),
                              isExpanded: true,
                              items: [
                                for (final s in subCategories)
                                  DropdownMenuItem(
                                    value: s.slug,
                                    child: Text(
                                      '${s.name} (${s.slug})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) async {
                                final next = v ?? subSlug;
                                setD(() {
                                  subSlug = next;
                                  thenAttrsLoading = true;
                                });
                                final keep = {
                                  for (final r in thenAttrRows)
                                    if (r.enabled && r.value.trim().isNotEmpty)
                                      r.key: r.value.trim(),
                                };
                                await loadThenSubData(
                                  next,
                                  keepAttrs: keep,
                                  clearProduct: true,
                                );
                                if (ctx.mounted) {
                                  setD(() => thenAttrsLoading = false);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'sug-prod-$subSlug-$selectedProductId-${thenProducts.length}',
                              ),
                              initialValue: selectedProductId.isEmpty
                                  ? ''
                                  : (thenProducts.any(
                                          (p) => p.id == selectedProductId)
                                      ? selectedProductId
                                      : ''),
                              decoration: deco(
                                'Specific product (optional)',
                                helper: selectedProductId.isEmpty
                                    ? 'Empty = show all matching products in this subcategory'
                                    : 'Only this product will be suggested',
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    'Any product in this subcategory',
                                  ),
                                ),
                                for (final p in thenProducts)
                                  DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      p.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setD(() {
                                selectedProductId = v ?? '';
                              }),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Match product attributes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Turn on attributes from this subcategory so only matching products are suggested.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: subtle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (thenAttrsLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            else if (thenAttrRows.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: border),
                                ),
                                child: const Text(
                                  'No attributes linked to this subcategory yet. Link attribute groups on the subcategory in Shop.',
                                  style: TextStyle(fontSize: 12, color: subtle),
                                ),
                              )
                            else
                              for (var i = 0; i < thenAttrRows.length; i++)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    2,
                                    8,
                                    10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: thenAttrRows[i].enabled
                                          ? const Color(0xFF8FCF9A)
                                          : border,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: Text(
                                          thenAttrRows[i].label,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: accent,
                                          ),
                                        ),
                                        subtitle: Text(
                                          thenAttrRows[i].key,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: subtle,
                                          ),
                                        ),
                                        value: thenAttrRows[i].enabled,
                                        onChanged: (v) => setD(() {
                                          thenAttrRows[i] = thenAttrRows[i]
                                              .copyWith(enabled: v);
                                        }),
                                      ),
                                      if (thenAttrRows[i].enabled)
                                        thenAttrRows[i].options.isNotEmpty
                                            ? DropdownButtonFormField<String>(
                                                key: ValueKey(
                                                  'ta-$i-${thenAttrRows[i].value}',
                                                ),
                                                initialValue: thenAttrRows[i]
                                                        .options
                                                        .contains(
                                                      thenAttrRows[i].value,
                                                    )
                                                    ? thenAttrRows[i].value
                                                    : thenAttrRows[i]
                                                        .options
                                                        .first,
                                                decoration: deco('Value'),
                                                isExpanded: true,
                                                items: [
                                                  for (final o
                                                      in thenAttrRows[i]
                                                          .options)
                                                    DropdownMenuItem(
                                                      value: o,
                                                      child: Text(
                                                        o,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                ],
                                                onChanged: (v) => setD(() {
                                                  thenAttrRows[i] =
                                                      thenAttrRows[i].copyWith(
                                                    value: v ??
                                                        thenAttrRows[i].value,
                                                  );
                                                }),
                                              )
                                            : TextFormField(
                                                key: ValueKey(
                                                  'tat-$i-${thenAttrRows[i].key}',
                                                ),
                                                initialValue:
                                                    thenAttrRows[i].value,
                                                decoration: deco('Value'),
                                                onChanged: (v) =>
                                                    thenAttrRows[i] =
                                                        thenAttrRows[i]
                                                            .copyWith(
                                                  value: v,
                                                ),
                                              ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nameContains,
                              decoration: deco(
                                'Product name contains (optional)',
                                helper:
                                    'Extra name filter — e.g. Wi‑Fi, Pro, Lite',
                              ),
                            ),
                            if (groups.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey('sug-group-$suggestShowGroupId'),
                                initialValue: suggestShowGroupId.isEmpty
                                    ? ''
                                    : (groups.any(
                                            (g) => g.id == suggestShowGroupId)
                                        ? suggestShowGroupId
                                        : ''),
                                decoration: deco(
                                  'Show product cards under group',
                                  helper:
                                      'Section footer under this group. Prefer “under question” for Indoor/Outdoor qty.',
                                ),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text(
                                      'Suggested products section (default)',
                                    ),
                                  ),
                                  for (final g in groups)
                                    DropdownMenuItem(
                                      value: g.id,
                                      child: Text(
                                        g.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setD(() {
                                  suggestShowGroupId = v ?? '';
                                }),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final underChoices = <({String key, String label})>[
                                  for (final q in familyQuestions)
                                    if (q.questionKey.trim().isNotEmpty)
                                      (
                                        key: q.questionKey.trim(),
                                        label: q.label.trim().isEmpty
                                            ? q.questionKey.trim()
                                            : '${q.label.trim()} (${q.questionKey.trim()})',
                                      ),
                                  for (final q in numberQuestions)
                                    if (q.$1.trim().isNotEmpty &&
                                        !familyQuestions.any(
                                          (fq) => fq.questionKey == q.$1,
                                        ))
                                      (
                                        key: q.$1.trim(),
                                        label: q.$2.trim().isEmpty
                                            ? q.$1.trim()
                                            : '${q.$2.trim()} (${q.$1.trim()})',
                                      ),
                                ];
                                // Dedupe by key
                                final seen = <String>{};
                                final unique = <({String key, String label})>[
                                  for (final c in underChoices)
                                    if (seen.add(c.key)) c,
                                ]..sort((a, b) => a.label.compareTo(b.label));
                                final validUnder = unique.any(
                                      (c) => c.key == suggestShowUnderQuestion,
                                    )
                                    ? suggestShowUnderQuestion
                                    : '';
                                return DropdownButtonFormField<String>(
                                  key: ValueKey('sug-under-$validUnder'),
                                  initialValue: validUnder,
                                  decoration: deco(
                                    'Show product cards under question',
                                    helper:
                                        'e.g. Indoor qty — cards appear right below that field on the public calculator.',
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('None (use group / default)'),
                                    ),
                                    for (final c in unique)
                                      DropdownMenuItem(
                                        value: c.key,
                                        child: Text(
                                          c.label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setD(() {
                                    suggestShowUnderQuestion = v ?? '';
                                    // Keep qty in sync when pinning under a number question.
                                    if (suggestShowUnderQuestion.isNotEmpty &&
                                        (qtyFormula.text.trim().isEmpty ||
                                            qtyFormula.text.trim() == '1' ||
                                            unique.any(
                                              (c) =>
                                                  c.key ==
                                                  qtyFormula.text.trim(),
                                            ))) {
                                      qtyFormula.text = suggestShowUnderQuestion;
                                    }
                                  }),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: qtyFormula,
                              decoration: deco(
                                'Quantity formula',
                                helper:
                                    'Per unit x answer — e.g. indoor_qty or outdoor_qty * 1',
                              ),
                            ),
                            if (() {
                              final keys = <String>{
                                for (final q in numberQuestions) q.$1,
                                for (final r in answerRows)
                                  if (r.uiType == 'number' ||
                                      r.uiType == 'slider' ||
                                      r.uiType == 'integer')
                                    r.key,
                              };
                              return keys.isNotEmpty;
                            }()) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Tap to insert (scales with a number answer):',
                                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final key in {
                                    for (final q in numberQuestions) q.$1,
                                    for (final r in answerRows)
                                      if (r.uiType == 'number' ||
                                          r.uiType == 'slider' ||
                                          r.uiType == 'integer')
                                        r.key,
                                  })
                                    ActionChip(
                                      label: Text('$key * 2'),
                                      onPressed: () => setD(() {
                                        qtyFormula.text = '$key * 2';
                                        qtyFormula.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                            offset: qtyFormula.text.length,
                                          ),
                                        );
                                      }),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 4),
                        title: const Text(
                          'Advanced',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        subtitle: const Text(
                          'Name, priority, active',
                          style: TextStyle(fontSize: 12, color: subtle),
                        ),
                        children: [
                          TextField(
                            controller: name,
                            decoration: deco(
                              'Rule name (optional)',
                              helper: resolvedGroupName.isNotEmpty
                                  ? 'Blank → short auto label under this group'
                                  : 'Leave blank to auto-name from When / Then',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: priority,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      deco('Priority', helper: 'Lower first'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Active'),
                                  value: isActive,
                                  onChanged: (v) =>
                                      setD(() => isActive = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              if (editorStep == 1)
                TextButton(
                  onPressed: () => setD(() => editorStep = 0),
                  child: const Text('Back'),
                ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: () {
                  if (editorStep == 0) {
                    setD(() => editorStep = 1);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(
                  editorStep == 0
                      ? 'Next: Then'
                      : (existing != null ? 'Save' : 'Create'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      disposeAll();
      return false;
    }

    final parent = masterById(selectedAttrId) ?? attribute;
    final conditionAll = <Map<String, dynamic>>[
      {
        'var': parent.key,
        'op': 'eq',
        'value': selectedOption,
      },
    ];
    for (final r in answerRows) {
      if (!r.enabled) continue;
      if (r.key.trim().isEmpty) continue;
      if (r.op == 'between') {
        final min = r.value.trim();
        final max = r.valueMax.trim();
        if (min.isNotEmpty) {
          conditionAll.add({
            'var': r.key.trim(),
            'op': 'gte',
            'value': _smartOptionRuleValue(min),
          });
        }
        if (max.isNotEmpty) {
          conditionAll.add({
            'var': r.key.trim(),
            'op': 'lte',
            'value': _smartOptionRuleValue(max),
          });
        }
      } else if (r.value.trim().isNotEmpty) {
        conditionAll.add({
          'var': r.key.trim(),
          'op': r.op,
          'value': _smartOptionRuleValue(r.value.trim()),
        });
      }
    }

    final condition = {'all': conditionAll};
    final action = ruleType == 'formula'
        ? <String, dynamic>{
            'type': 'formula',
            'output_key':
                outputKey.text.trim().isEmpty ? 'qty' : outputKey.text.trim(),
            'expression':
                qtyFormula.text.trim().isEmpty ? '1' : qtyFormula.text.trim(),
          }
        : ruleType == 'charge_line'
            ? <String, dynamic>{
                'type': 'charge_line',
                'label': chargeLabel.text.trim().isEmpty
                    ? 'Installation charge'
                    : chargeLabel.text.trim(),
                'unit_price':
                    double.tryParse(chargeUnitPrice.text.trim()) ?? 0,
                'qty_var': chargeQtyVar.trim().isEmpty
                    ? 'Cable Lenght In Meter'
                    : chargeQtyVar.trim(),
                if (chargeShowUnder.trim().isNotEmpty)
                  'show_under_question': chargeShowUnder.trim(),
                if (suggestShowGroupId.isNotEmpty) ...{
                  'match_group_id': suggestShowGroupId,
                  'match_group_name': groups
                          .where((g) => g.id == suggestShowGroupId)
                          .map((g) => g.name)
                          .firstOrNull ??
                      'Installation',
                },
              }
        : ruleType == 'qty_scale'
            ? <String, dynamic>{
                'type': 'qty_from_question',
                'question_key': qtyQuestionKey.isNotEmpty
                    ? qtyQuestionKey
                    : (numberQuestions.isNotEmpty
                        ? numberQuestions.first.$1
                        : 'qty'),
                'apply_to': qtyApplyTo,
                if (qtyMatchGroupId.isNotEmpty)
                  'match_group_id': qtyMatchGroupId,
                'match': {
                  'sub_category_slug': subSlug,
                  if (selectedProductId.trim().isNotEmpty)
                    'product_id': selectedProductId.trim(),
                  // When a specific product is chosen, attributes are not needed.
                  if (selectedProductId.trim().isEmpty &&
                      nameContains.text.trim().isNotEmpty)
                    'name_contains': nameContains.text.trim(),
                  if (selectedProductId.trim().isEmpty &&
                      {
                        for (final r in thenAttrRows)
                          if (r.enabled && r.value.trim().isNotEmpty)
                            r.key: r.value.trim(),
                      }.isNotEmpty)
                    'attributes': {
                      for (final r in thenAttrRows)
                        if (r.enabled && r.value.trim().isNotEmpty)
                          r.key: r.value.trim(),
                    },
                },
              }
            : <String, dynamic>{
                'type': 'suggest_product',
                if (suggestShowGroupId.isNotEmpty) ...{
                  'match_group_id': suggestShowGroupId,
                  'match_group_name': groups
                          .where((g) => g.id == suggestShowGroupId)
                          .map((g) => g.name)
                          .firstOrNull ??
                      'Suggested products',
                },
                if (suggestShowUnderQuestion.trim().isNotEmpty)
                  'show_under_question': suggestShowUnderQuestion.trim(),
                // When cards sit under a qty question, also drive line qty from it.
                if (suggestShowUnderQuestion.trim().isNotEmpty)
                  'qty_var': suggestShowUnderQuestion.trim()
                else if (qtyFormula.text.trim().isNotEmpty &&
                    RegExp(r'^[A-Za-z_][\w]*$').hasMatch(qtyFormula.text.trim()))
                  'qty_var': qtyFormula.text.trim(),
                'match': {
                  'sub_category_slug': subSlug,
                  if (selectedProductId.trim().isNotEmpty)
                    'product_id': selectedProductId.trim(),
                  if (nameContains.text.trim().isNotEmpty)
                    'name_contains': nameContains.text.trim(),
                  if ({
                    for (final r in thenAttrRows)
                      if (r.enabled && r.value.trim().isNotEmpty)
                        r.key: r.value.trim(),
                  }.isNotEmpty)
                    'attributes': {
                      for (final r in thenAttrRows)
                        if (r.enabled && r.value.trim().isNotEmpty)
                          r.key: r.value.trim(),
                    },
                },
                'qty_formula':
                    qtyFormula.text.trim().isEmpty ? '1' : qtyFormula.text.trim(),
              };

    final enabledLabels = [
      for (final r in answerRows)
        if (r.enabled) r.label,
    ];
    final shortAction = ruleType == 'qty_scale'
        ? 'x ${qtyQuestionKey.isEmpty ? 'qty' : qtyQuestionKey}'
        : (ruleType == 'charge_line'
            ? 'charge'
            : (ruleType == 'formula' ? 'formula' : 'suggest product'));
    final resolvedName = name.text.trim().isEmpty
        ? (resolvedGroupName.isNotEmpty
            ? shortAction
            : [
                selectedOption,
                if (enabledLabels.isNotEmpty) enabledLabels.join(' + '),
                shortAction,
              ].join(' · '))
        : name.text.trim();
    final pri = int.tryParse(priority.text.trim()) ?? defaultPriority;
    // DB enum has no qty_scale / charge_line — store as suggest + action.type.
    final dbRuleType =
        (ruleType == 'qty_scale' || ruleType == 'charge_line')
            ? 'suggest'
            : ruleType;

    await Future<void>.delayed(const Duration(milliseconds: 100));
    disposeAll();

    try {
      if (existing != null) {
        await repo.updateRule(
          id: existing.id,
          ruleType: dbRuleType,
          name: resolvedName,
          priority: pri,
          condition: condition,
          action: action,
          isActive: isActive,
          optionScopeFamilyId: familyId,
          optionScopeAttributeId: selectedAttrId,
          optionScopeLabel: selectedOption,
          ruleGroupId: resolvedGroupId.isEmpty
              ? existing.ruleGroupId
              : resolvedGroupId,
        );
      } else {
        await repo.createRule(
          templateId: templateId,
          ruleType: dbRuleType,
          name: resolvedName,
          priority: pri,
          condition: condition,
          action: action,
          isActive: isActive,
          optionScopeFamilyId: familyId,
          optionScopeAttributeId: selectedAttrId,
          optionScopeLabel: selectedOption,
          ruleGroupId:
              resolvedGroupId.isEmpty ? null : resolvedGroupId,
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rule: $e')),
        );
      }
      return false;
    }
  }

  static List<_OptionRuleClause> _parseOptionRuleClauses(
    Map<String, dynamic>? condition,
  ) {
    if (condition == null || condition.isEmpty) return [];
    final all = condition['all'];
    if (all is List) {
      return [
        for (final c in all)
          if (c is Map)
            _OptionRuleClause(
              varKey: c['var']?.toString() ?? '',
              op: c['op']?.toString() ?? 'eq',
              value: c['value']?.toString() ?? '',
            ),
      ];
    }
    if (condition['var'] != null) {
      return [
        _OptionRuleClause(
          varKey: condition['var']?.toString() ?? '',
          op: condition['op']?.toString() ?? 'eq',
          value: condition['value']?.toString() ?? '',
        ),
      ];
    }
    return [];
  }

  static dynamic _smartOptionRuleValue(String raw) {
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(raw);
    if (asDouble != null) return asDouble;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return raw;
  }

  static Future<String?> promptGroupName(
    BuildContext context, {
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? 'New rule group' : 'Rename group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Group name',
            helperText: 'e.g. Recorders, Power, Cabling, Accessories',
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
            child: Text(initial.isEmpty ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return null;
    return name;
  }

  static List<Widget> buildGroupedRules({
    required BuildContext context,
    required CalculatorFamily family,
    required ShopAttributeMaster attribute,
    required String optionLabel,
    required List<CalculatorRule> rules,
    required List<CalculatorRuleGroup> groups,
    required Color accent,
    required Color subtle,
    required Color softBg,
    required CalculatorRepository repo,
    required Future<void> Function() onChanged,
    required void Function(CalculatorRule rule) onEditRule,
    required void Function(CalculatorRuleGroup group) onAddInGroup,
    required ShopCatalogRepository catalog,
    required List<ShopSubCategory> subCategories,
    required List<ShopAttributeMaster> calcAttributes,
    required List<CalculatorFamilyAttributeLink> links,
    required List<CalculatorFamilyOptionPath> paths,
    required List<CalculatorQuestionGroup> questionGroups,
  }) {
    final byGroup = <String?, List<CalculatorRule>>{};
    for (final r in rules) {
      final gid = (r.ruleGroupId ?? '').isEmpty ? null : r.ruleGroupId;
      byGroup.putIfAbsent(gid, () => []).add(r);
    }
    final out = <Widget>[];

    Widget tile(CalculatorRule rule) {
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 8),
        dense: true,
        leading: Icon(
          rule.ruleType == 'formula'
              ? Icons.functions
              : ((rule.action['type']?.toString() ?? '') == 'qty_from_question'
                  ? Icons.pin
                  : Icons.shopping_bag_outlined),
          size: 20,
          color: accent,
        ),
        title: Text(
          rule.name ?? rule.ruleType,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: accent,
          ),
        ),
        subtitle: Text(
          [
            rule.ruleType,
            'priority ${rule.priority}',
            rule.isActive ? 'Active' : 'Inactive',
          ].join(' · '),
          style: TextStyle(fontSize: 11, color: subtle),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => onEditRule(rule),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete rule?'),
                    content: Text('Delete "${rule.name ?? rule.ruleType}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                await repo.deleteRule(rule.id);
                await onChanged();
              },
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            ),
          ],
        ),
      );
    }

    for (final g in groups) {
      final groupRules = byGroup.remove(g.id) ?? const <CalculatorRule>[];
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: softBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE5E5EA)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: accent,
                      ),
                    ),
                  ),
                  Text('${groupRules.length}',
                      style: TextStyle(fontSize: 11, color: subtle)),
                  IconButton(
                    tooltip: 'Add rule in group',
                    onPressed: () => onAddInGroup(g),
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Rename',
                    onPressed: () async {
                      final name =
                          await promptGroupName(context, initial: g.name);
                      if (name == null) return;
                      await repo.updateRuleGroup(id: g.id, name: name);
                      await onChanged();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Delete group',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Delete group?'),
                          content: Text(
                            'Delete "${g.name}"? Rules inside become ungrouped.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                              ),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      await repo.deleteRuleGroup(g.id);
                      await onChanged();
                    },
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                  ),
                ],
              ),
              if (groupRules.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    'No rules yet — tap + to add.',
                    style: TextStyle(fontSize: 12, color: subtle),
                  ),
                )
              else
                for (final rule in groupRules) tile(rule),
            ],
          ),
            ),
          ),
        ),
      );
    }

    final ungrouped = byGroup[null] ?? const <CalculatorRule>[];
    if (ungrouped.isEmpty && groups.isEmpty && rules.isEmpty) {
      out.add(
        Text(
          'No rules yet. Add a group or a rule.',
          style: TextStyle(fontSize: 12, color: subtle),
        ),
      );
    } else if (ungrouped.isNotEmpty) {
      if (groups.isNotEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Ungrouped',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtle,
              ),
            ),
          ),
        );
      }
      for (final rule in ungrouped) {
        out.add(tile(rule));
      }
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper data classes for the editor
// ─────────────────────────────────────────────────────────────────────────────

class _ThenAttrFilter {
  const _ThenAttrFilter({
    required this.key,
    required this.label,
    required this.options,
    required this.enabled,
    required this.value,
  });

  final String key;
  final String label;
  final List<String> options;
  final bool enabled;
  final String value;

  _ThenAttrFilter copyWith({
    String? key,
    String? label,
    List<String>? options,
    bool? enabled,
    String? value,
  }) {
    return _ThenAttrFilter(
      key: key ?? this.key,
      label: label ?? this.label,
      options: options ?? this.options,
      enabled: enabled ?? this.enabled,
      value: value ?? this.value,
    );
  }
}

class _WhenAnswerRow {
  const _WhenAnswerRow({
    required this.key,
    required this.label,
    required this.uiType,
    required this.options,
    this.groupName,
    required this.section,
    required this.enabled,
    required this.op,
    required this.value,
    required this.valueMax,
  });

  final String key;
  final String label;
  final String uiType;
  final List<String> options;
  final String? groupName;
  final String section;
  final bool enabled;
  final String op;
  final String value;
  final String valueMax;

  _WhenAnswerRow copyWith({
    String? key,
    String? label,
    String? uiType,
    List<String>? options,
    String? groupName,
    String? section,
    bool? enabled,
    String? op,
    String? value,
    String? valueMax,
  }) {
    return _WhenAnswerRow(
      key: key ?? this.key,
      label: label ?? this.label,
      uiType: uiType ?? this.uiType,
      options: options ?? this.options,
      groupName: groupName ?? this.groupName,
      section: section ?? this.section,
      enabled: enabled ?? this.enabled,
      op: op ?? this.op,
      value: value ?? this.value,
      valueMax: valueMax ?? this.valueMax,
    );
  }
}

class _OptionRuleClause {
  _OptionRuleClause({
    required this.varKey,
    this.op = 'eq',
    this.value = '',
  });

  String varKey;
  String op;
  String value;
}

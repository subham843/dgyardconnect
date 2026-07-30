class CalculatorFamily {
  const CalculatorFamily({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.sortOrder,
    required this.isActive,
    this.attributeIds = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final List<String> attributeIds;

  factory CalculatorFamily.fromRow(Map<String, dynamic> row) {
    return CalculatorFamily(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      description: row['description'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

/// Named section for calculator questions (Camera, Storage, Accessories, …).
class CalculatorQuestionGroup {
  const CalculatorQuestionGroup({
    required this.id,
    required this.familyId,
    required this.name,
    this.description,
    required this.sortOrder,
    this.isActive = true,
  });

  final String id;
  final String familyId;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isActive;

  factory CalculatorQuestionGroup.fromRow(Map<String, dynamic> row) {
    return CalculatorQuestionGroup(
      id: row['id'] as String? ?? '',
      familyId: row['family_id'] as String? ?? '',
      name: (row['name'] as String?)?.trim() ?? '',
      description: row['description'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

/// Shop attribute linked to a calculator family, with optional option subset.
class CalculatorFamilyAttributeLink {
  const CalculatorFamilyAttributeLink({
    required this.attributeId,
    this.sortOrder = 0,
    this.selectedOptions,
    this.questionMode = CalculatorFamilyQuestionMode.select,
    this.groupId,
  });

  final String attributeId;
  final int sortOrder;
  /// Null = all Shop options; non-null = only these labels for users.
  final List<String>? selectedOptions;
  /// `select` = one dropdown; `per_option` = one number question per option.
  final String questionMode;
  final String? groupId;

  factory CalculatorFamilyAttributeLink.fromRow(Map<String, dynamic> row) {
    List<String>? selected;
    final raw = row['selected_options'];
    if (raw is List) {
      selected = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final mode = row['question_mode'] as String? ?? CalculatorFamilyQuestionMode.select;
    return CalculatorFamilyAttributeLink(
      attributeId: row['attribute_id'] as String? ?? '',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      selectedOptions: selected,
      questionMode: CalculatorFamilyQuestionMode.isValid(mode)
          ? mode
          : CalculatorFamilyQuestionMode.select,
      groupId: row['group_id'] as String?,
    );
  }
}

abstract final class CalculatorFamilyQuestionMode {
  static const select = 'select';
  /// @Deprecated — use option quotation paths instead of qty-per-option.
  static const perOption = 'per_option';

  static bool isValid(String mode) => mode == select || mode == perOption;
}

/// Follow-up questions when a parent attribute option is chosen (e.g. HD → HDD question).
class CalculatorFamilyOptionPathQuestion {
  const CalculatorFamilyOptionPathQuestion({
    this.id,
    required this.questionKey,
    required this.label,
    this.uiType = 'select',
    this.options,
    this.sourceAttributeId,
    this.sortOrder = 0,
    this.groupId,
  });

  final String? id;
  final String questionKey;
  final String label;
  final String uiType;
  final List<String>? options;
  final String? sourceAttributeId;
  final int sortOrder;
  /// Optional question group (Camera / Storage / …). Overrides parent attribute group when set.
  final String? groupId;

  factory CalculatorFamilyOptionPathQuestion.fromRow(Map<String, dynamic> row) {
    List<String>? opts;
    final raw = row['options'];
    if (raw is List) {
      opts = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return CalculatorFamilyOptionPathQuestion(
      id: row['id']?.toString(),
      questionKey: row['question_key'] as String? ?? '',
      label: row['label'] as String? ?? '',
      uiType: row['ui_type'] as String? ?? 'select',
      options: opts,
      sourceAttributeId: row['source_attribute_id']?.toString(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      groupId: row['group_id']?.toString(),
    );
  }
}

/// Quotation path for one option of a root attribute (e.g. Camera Type = HD).
class CalculatorFamilyOptionPath {
  const CalculatorFamilyOptionPath({
    this.id,
    required this.familyId,
    required this.parentAttributeId,
    required this.optionLabel,
    this.sortOrder = 0,
    this.attributes = const [],
    this.questions = const [],
  });

  final String? id;
  final String familyId;
  final String parentAttributeId;
  final String optionLabel;
  final int sortOrder;
  final List<CalculatorFamilyAttributeLink> attributes;
  final List<CalculatorFamilyOptionPathQuestion> questions;
}

class CalculatorTemplate {
  const CalculatorTemplate({
    required this.id,
    required this.familyId,
    required this.name,
    required this.slug,
    required this.version,
    required this.isPublished,
    required this.isActive,
  });

  final String id;
  final String familyId;
  final String name;
  final String slug;
  final int version;
  final bool isPublished;
  final bool isActive;

  factory CalculatorTemplate.fromRow(Map<String, dynamic> row) {
    return CalculatorTemplate(
      id: row['id'] as String,
      familyId: row['family_id'] as String,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      version: (row['version'] as num?)?.toInt() ?? 1,
      isPublished: row['is_published'] as bool? ?? false,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

class CalculatorQuestion {
  const CalculatorQuestion({
    required this.id,
    required this.templateId,
    required this.questionKey,
    required this.label,
    required this.uiType,
    this.options,
    required this.sortOrder,
    required this.defaultVisibility,
    this.showWhenKey,
    this.showWhenValue,
    this.groupId,
    this.groupName,
    this.groupSortOrder = 0,
  });

  final String id;
  final String templateId;
  final String questionKey;
  final String label;
  final String uiType;
  final List<String>? options;
  final int sortOrder;
  final bool defaultVisibility;
  /// Show only when [answers][showWhenKey] equals [showWhenValue] (option path).
  final String? showWhenKey;
  final String? showWhenValue;
  final String? groupId;
  final String? groupName;
  final int groupSortOrder;

  bool isVisibleGiven(Map<String, dynamic> answers) {
    if (!defaultVisibility && showWhenKey == null) return false;
    final depKey = showWhenKey;
    if (depKey == null || depKey.isEmpty) return defaultVisibility;
    final expected = (showWhenValue ?? '').toString().trim();
    final actual = (answers[depKey]?.toString() ?? '').trim();
    if (expected.isEmpty) return actual.isNotEmpty;
    // Option labels can differ by casing / spacing from admin vs shop.
    return actual.toLowerCase() == expected.toLowerCase();
  }

  CalculatorQuestion copyWith({
    String? id,
    String? templateId,
    String? questionKey,
    String? label,
    String? uiType,
    List<String>? options,
    int? sortOrder,
    bool? defaultVisibility,
    String? showWhenKey,
    String? showWhenValue,
    String? groupId,
    String? groupName,
    int? groupSortOrder,
  }) {
    return CalculatorQuestion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      questionKey: questionKey ?? this.questionKey,
      label: label ?? this.label,
      uiType: uiType ?? this.uiType,
      options: options ?? this.options,
      sortOrder: sortOrder ?? this.sortOrder,
      defaultVisibility: defaultVisibility ?? this.defaultVisibility,
      showWhenKey: showWhenKey ?? this.showWhenKey,
      showWhenValue: showWhenValue ?? this.showWhenValue,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupSortOrder: groupSortOrder ?? this.groupSortOrder,
    );
  }

  /// Prefer saved question options; fill from Shop only when empty.
  static List<CalculatorQuestion> enrichWithShopOptions(
    List<CalculatorQuestion> questions,
    Map<String, List<String>> optionsByKey,
  ) {
    if (optionsByKey.isEmpty) return questions;
    return [
      for (final q in questions) _enrichOne(q, optionsByKey),
    ];
  }

  /// Template sync stores path questions as default_visibility=false but drops
  /// show_when. Rebuild visibility from option-scoped rules so follow-ups open
  /// after the family attribute (e.g. HD Camera) is selected.
  static List<CalculatorQuestion> attachOptionScopeVisibility(
    List<CalculatorQuestion> questions,
    List<CalculatorRule> rules,
  ) {
    if (questions.isEmpty || rules.isEmpty) return questions;

    final rootSelectKeys = <String>{
      for (final q in questions)
        if ((q.showWhenKey == null || q.showWhenKey!.isEmpty) &&
            q.defaultVisibility &&
            (q.uiType == 'select' ||
                q.uiType == 'chips' ||
                q.uiType == 'radio' ||
                (q.options?.isNotEmpty ?? false)))
          q.questionKey,
    };
    if (rootSelectKeys.isEmpty) return questions;

    ({String parent, String label})? scopeOf(CalculatorRule rule) {
      final label = (rule.optionScopeLabel ?? '').trim();
      if (label.isEmpty) return null;
      final parent = _parentKeyFromCondition(rule.condition, rootSelectKeys) ??
          rootSelectKeys.first;
      return (parent: parent, label: label);
    }

    final allScopes = <String, ({String parent, String label})>{};
    for (final rule in rules) {
      final s = scopeOf(rule);
      if (s != null) allScopes['${s.parent}|${s.label}'] = s;
    }
    if (allScopes.isEmpty) return questions;

    final out = <CalculatorQuestion>[];
    for (final q in questions) {
      if (q.defaultVisibility || (q.showWhenKey ?? '').isNotEmpty) {
        out.add(q);
        continue;
      }

      final matched = <String, ({String parent, String label})>{};
      for (final rule in rules) {
        final s = scopeOf(rule);
        if (s == null) continue;
        if (_ruleMentionsQuestion(rule, q.questionKey)) {
          matched['${s.parent}|${s.label}'] = s;
        }
      }
      final scopes = matched.isNotEmpty
          ? matched.values.toList()
          : (allScopes.length == 1 ? allScopes.values.toList() : const []);

      if (scopes.isEmpty) {
        out.add(q);
        continue;
      }
      for (var i = 0; i < scopes.length; i++) {
        final s = scopes[i];
        out.add(
          q.copyWith(
            id: scopes.length == 1 ? q.id : '${q.id}__${s.parent}_${s.label}_$i',
            showWhenKey: s.parent,
            showWhenValue: s.label,
            defaultVisibility: false,
          ),
        );
      }
    }
    return out;
  }

  static String? _parentKeyFromCondition(
    Map<String, dynamic> condition,
    Set<String> rootSelectKeys,
  ) {
    final clauses = <Map<String, dynamic>>[];
    final all = condition['all'];
    if (all is List) {
      for (final c in all) {
        if (c is Map) clauses.add(Map<String, dynamic>.from(c));
      }
    } else if (condition.isNotEmpty) {
      clauses.add(condition);
    }
    for (final c in clauses) {
      final op = c['op']?.toString() ?? 'eq';
      if (op != 'eq') continue;
      final key = c['var']?.toString() ?? '';
      if (rootSelectKeys.contains(key)) return key;
    }
    return null;
  }

  static bool _ruleMentionsQuestion(CalculatorRule rule, String questionKey) {
    if (_mapMentionsKey(rule.condition, questionKey)) return true;
    if (_mapMentionsKey(rule.action, questionKey)) return true;
    final qk = rule.action['question_key']?.toString();
    return qk == questionKey;
  }

  static bool _mapMentionsKey(Map<String, dynamic> map, String key) {
    for (final e in map.entries) {
      if (e.key == 'var' && e.value?.toString() == key) return true;
      if (e.key == 'question_key' && e.value?.toString() == key) return true;
      final v = e.value;
      if (v is Map && _mapMentionsKey(Map<String, dynamic>.from(v), key)) {
        return true;
      }
      if (v is List) {
        for (final item in v) {
          if (item is Map &&
              _mapMentionsKey(Map<String, dynamic>.from(item), key)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static CalculatorQuestion _enrichOne(
    CalculatorQuestion q,
    Map<String, List<String>> optionsByKey,
  ) {
    if (q.options != null && q.options!.isNotEmpty) return q;
    final shopOpts = optionsByKey[q.questionKey];
    if (shopOpts == null || shopOpts.isEmpty) return q;
    return q.copyWith(uiType: 'select', options: shopOpts);
  }

  factory CalculatorQuestion.fromRow(Map<String, dynamic> row) {
    final opt = row['options'];
    List<String>? options;
    if (opt is List) options = opt.map((e) => e.toString()).toList();
    final group = row['calculator_question_groups'];
    String? groupName;
    int groupSort = 0;
    if (group is Map) {
      groupName = (group['name'] as String?)?.trim();
      groupSort = (group['sort_order'] as num?)?.toInt() ?? 0;
    }
    return CalculatorQuestion(
      id: row['id'] as String,
      templateId: row['template_id'] as String,
      questionKey: row['question_key'] as String? ?? '',
      label: row['label'] as String? ?? '',
      uiType: row['ui_type'] as String? ?? 'text',
      options: options,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      defaultVisibility: row['default_visibility'] as bool? ?? true,
      groupId: row['group_id'] as String?,
      groupName: groupName,
      groupSortOrder: groupSort,
    );
  }
}

class CalculatorRuleGroup {
  const CalculatorRuleGroup({
    required this.id,
    required this.familyId,
    required this.name,
    this.optionScopeAttributeId,
    this.optionScopeLabel,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String familyId;
  final String name;
  final String? optionScopeAttributeId;
  final String? optionScopeLabel;
  final int sortOrder;
  final bool isActive;

  factory CalculatorRuleGroup.fromRow(Map<String, dynamic> row) {
    return CalculatorRuleGroup(
      id: row['id'] as String? ?? '',
      familyId: row['family_id'] as String? ?? '',
      name: (row['name'] as String?)?.trim() ?? '',
      optionScopeAttributeId: row['option_scope_attribute_id'] as String?,
      optionScopeLabel: row['option_scope_label'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

class CalculatorRule {
  const CalculatorRule({
    required this.id,
    required this.templateId,
    required this.ruleType,
    required this.name,
    required this.priority,
    required this.condition,
    required this.action,
    required this.isActive,
    this.optionScopeFamilyId,
    this.optionScopeAttributeId,
    this.optionScopeLabel,
    this.ruleGroupId,
    this.ruleGroupName,
  });

  final String id;
  final String templateId;
  final String ruleType;
  final String? name;
  final int priority;
  final Map<String, dynamic> condition;
  final Map<String, dynamic> action;
  final bool isActive;
  final String? optionScopeFamilyId;
  final String? optionScopeAttributeId;
  final String? optionScopeLabel;
  final String? ruleGroupId;
  final String? ruleGroupName;

  bool get hasOptionScope =>
      (optionScopeFamilyId ?? '').isNotEmpty &&
      (optionScopeAttributeId ?? '').isNotEmpty &&
      (optionScopeLabel ?? '').isNotEmpty;

  factory CalculatorRule.fromRow(Map<String, dynamic> row) {
    String? groupName;
    final g = row['calculator_rule_groups'];
    if (g is Map) {
      groupName = (g['name'] as String?)?.trim();
    }
    return CalculatorRule(
      id: row['id'] as String,
      templateId: row['template_id'] as String,
      ruleType: row['rule_type'] as String? ?? 'suggest',
      name: row['name'] as String?,
      priority: (row['priority'] as num?)?.toInt() ?? 100,
      condition: Map<String, dynamic>.from(row['condition'] as Map? ?? {}),
      action: Map<String, dynamic>.from(row['action'] as Map? ?? {}),
      isActive: row['is_active'] as bool? ?? true,
      optionScopeFamilyId: row['option_scope_family_id'] as String?,
      optionScopeAttributeId: row['option_scope_attribute_id'] as String?,
      optionScopeLabel: row['option_scope_label'] as String?,
      ruleGroupId: row['rule_group_id'] as String?,
      ruleGroupName: groupName,
    );
  }
}

class CalculatorSuggestedLine {
  const CalculatorSuggestedLine({
    required this.label,
    required this.qty,
    this.productId,
    this.sku,
    this.unitPrice,
    this.sourceRuleId,
    this.selectionKey,
    this.matchGroupId,
    this.matchGroupName,
    this.showUnderQuestionKey,
    this.alternatives = const [],
  });

  final String label;
  final double qty;
  final String? productId;
  final String? sku;
  final double? unitPrice;
  final String? sourceRuleId;

  /// Stable key for attribute-matched groups (user can pick another product).
  final String? selectionKey;

  /// Question group this attribute-match belongs to (for UI under that section).
  final String? matchGroupId;
  final String? matchGroupName;

  /// When set, public calculator shows this pickable line under that question
  /// (e.g. directly below `indoor_qty` / `outdoor_qty`).
  final String? showUnderQuestionKey;

  /// Other products that match the same attribute answers (cheapest is selected by default).
  final List<CalculatorProductOption> alternatives;

  bool get hasAlternatives => alternatives.length > 1;

  CalculatorSuggestedLine copyWithProduct(CalculatorProductOption option) {
    return CalculatorSuggestedLine(
      label: option.label,
      qty: qty,
      productId: option.productId,
      sku: option.sku,
      unitPrice: option.unitPrice,
      sourceRuleId: sourceRuleId,
      selectionKey: selectionKey,
      matchGroupId: matchGroupId,
      matchGroupName: matchGroupName,
      showUnderQuestionKey: showUnderQuestionKey,
      alternatives: alternatives,
    );
  }

  CalculatorSuggestedLine copyWith({
    String? label,
    double? qty,
    String? productId,
    String? sku,
    double? unitPrice,
    String? sourceRuleId,
    String? selectionKey,
    String? matchGroupId,
    String? matchGroupName,
    String? showUnderQuestionKey,
    List<CalculatorProductOption>? alternatives,
  }) {
    return CalculatorSuggestedLine(
      label: label ?? this.label,
      qty: qty ?? this.qty,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      unitPrice: unitPrice ?? this.unitPrice,
      sourceRuleId: sourceRuleId ?? this.sourceRuleId,
      selectionKey: selectionKey ?? this.selectionKey,
      matchGroupId: matchGroupId ?? this.matchGroupId,
      matchGroupName: matchGroupName ?? this.matchGroupName,
      showUnderQuestionKey: showUnderQuestionKey ?? this.showUnderQuestionKey,
      alternatives: alternatives ?? this.alternatives,
    );
  }
}

class CalculatorProductOption {
  const CalculatorProductOption({
    required this.productId,
    required this.label,
    this.sku,
    this.unitPrice,
    this.imageUrl,
  });

  final String productId;
  final String label;
  final String? sku;
  final double? unitPrice;
  final String? imageUrl;
}

class CalculatorFormulaOutput {
  const CalculatorFormulaOutput({required this.key, required this.value});

  final String key;
  final double value;
}

class CalculatorResult {
  const CalculatorResult({
    required this.suggestedLines,
    required this.formulas,
    this.warnings = const [],
    this.visibleQuestionKeys = const [],
  });

  final List<CalculatorSuggestedLine> suggestedLines;
  final List<CalculatorFormulaOutput> formulas;
  final List<String> warnings;
  final List<String> visibleQuestionKeys;

  CalculatorResult withLines(List<CalculatorSuggestedLine> lines) {
    return CalculatorResult(
      suggestedLines: lines,
      formulas: formulas,
      warnings: warnings,
      visibleQuestionKeys: visibleQuestionKeys,
    );
  }
}

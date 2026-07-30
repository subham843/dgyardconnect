import '../../shop/data/shop_catalog_repository.dart';
import 'calculator_models.dart';

/// Lightweight catalog hit used by the calculator engine (public or admin).
class CalculatorProductHit {
  const CalculatorProductHit({
    required this.id,
    required this.name,
    this.sku,
    this.unitPrice,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? sku;
  final double? unitPrice;
  final String? imageUrl;
}

typedef CalculatorProductLookup = Future<List<CalculatorProductHit>> Function(
  String subCategorySlug, {
  String? nameContains,
  Map<String, String>? attributes,
});

typedef CalculatorAttributeProductLookup = Future<List<CalculatorProductHit>> Function(
  Map<String, String> attributeKeyToValue,
);

/// Evaluates no-code calculator rules (conditions + actions).
class CalculatorEngine {
  CalculatorEngine({
    CalculatorProductLookup? productLookup,
    CalculatorAttributeProductLookup? attributeProductLookup,
    ShopCatalogRepository? catalog,
  })  : _productLookup = productLookup ?? _defaultLookup(catalog ?? ShopCatalogRepository()),
        _attributeProductLookup = attributeProductLookup;

  final CalculatorProductLookup _productLookup;
  final CalculatorAttributeProductLookup? _attributeProductLookup;

  /// Per-evaluate cache so the same subcategory is fetched once.
  final Map<String, List<CalculatorProductHit>> _slugCache = {};

  static CalculatorProductLookup _defaultLookup(ShopCatalogRepository catalog) {
    return (slug, {String? nameContains, Map<String, String>? attributes}) async {
      try {
        final products = await catalog.findProductsBySubCategorySlug(
          slug,
          attributes: attributes,
        );
        var hits = [
          for (final p in products)
            CalculatorProductHit(
              id: p.id,
              name: p.name,
              sku: p.sku,
              unitPrice: p.basePrice,
            ),
        ];
        final hint = nameContains?.trim().toLowerCase();
        if (hint != null && hint.isNotEmpty) {
          final filtered = hits
              .where((h) => h.name.toLowerCase().contains(hint))
              .toList();
          if (filtered.isNotEmpty) hits = filtered;
        }
        return hits;
      } catch (_) {
        return const [];
      }
    };
  }

  Future<CalculatorResult> evaluate({
    required List<CalculatorQuestion> questions,
    required List<CalculatorRule> rules,
    required Map<String, dynamic> answers,
  }) async {
    _slugCache.clear();
    // Indoor + Outdoor qty replaced legacy "Number of Camers" — keep DVR/SMPS/BNC
    // rules working without editing every When clause.
    final enriched = _withDerivedCameraTotals(Map<String, dynamic>.from(answers));
    final sortedRules = [...rules]..sort((a, b) => a.priority.compareTo(b.priority));

    var visibleKeys = questions
        .where((q) => q.isVisibleGiven(enriched))
        .map((q) => q.questionKey)
        .toSet();

    // Re-apply dependency fields after answer-driven showWhen.
    for (final q in questions) {
      if (q.showWhenKey != null && q.isVisibleGiven(enriched)) {
        visibleKeys.add(q.questionKey);
      } else if (q.showWhenKey != null) {
        visibleKeys.remove(q.questionKey);
      }
    }

    final warnings = <String>[];
    final formulas = <CalculatorFormulaOutput>[];
    final suggestRules = <CalculatorRule>[];
    final qtyScaleRules = <CalculatorRule>[];

    for (final rule in sortedRules) {
      if (!rule.isActive) continue;

      switch (rule.ruleType) {
        case 'visibility':
        case 'dependency':
          _applyVisibilityRule(rule, enriched, visibleKeys);
          break;
        default:
          break;
      }
    }

    for (final rule in sortedRules) {
      if (!rule.isActive) continue;
      if (!_evaluateCondition(rule.condition, enriched)) continue;

      switch (rule.ruleType) {
        case 'formula':
          final out = _evaluateFormula(rule, enriched);
          if (out != null) formulas.add(out);
          break;
        case 'suggest':
        case 'recommendation':
          if ((rule.action['type']?.toString() ?? '') == 'qty_from_question') {
            qtyScaleRules.add(rule);
          } else {
            suggestRules.add(rule);
          }
          break;
        case 'visibility':
        case 'dependency':
          break;
      }
    }

    // Parallel product lookups (was sequential + Firebase auth sync → slow/crash on web).
    final suggestResults = await Future.wait(
      suggestRules.map((rule) => _evaluateSuggest(rule, enriched)),
    );
    final suggested = <CalculatorSuggestedLine>[
      for (final lines in suggestResults) ...lines,
    ];

    // Keys used as product filters on ANY active suggest rule (even if When
    // has not matched yet). Otherwise selecting Resolution alone auto-matches
    // cameras before indoor/outdoor qty is entered.
    final ruleProductFilterKeys = <String>{};
    for (final r in sortedRules) {
      if (!r.isActive) continue;
      if (r.ruleType != 'suggest' && r.ruleType != 'recommendation') continue;
      if ((r.action['type']?.toString() ?? '') != 'suggest_product') continue;
      final match = r.action['match'];
      if (match is! Map) continue;
      final raw = match['attributes'];
      if (raw is! Map) continue;
      for (final e in raw.entries) {
        final k = e.key.toString().trim();
        if (k.isNotEmpty) ruleProductFilterKeys.add(k);
      }
    }

    final attrLines = await _evaluateAttributeMatches(
      questions: questions,
      answers: enriched,
      visibleKeys: visibleKeys,
      excludeAttributeKeys: ruleProductFilterKeys,
    );
    var merged = <CalculatorSuggestedLine>[
      ...attrLines,
      ...suggested,
    ];
    merged = await _applyQtyFromQuestionRules(merged, qtyScaleRules, enriched);

    return CalculatorResult(
      suggestedLines: merged,
      formulas: formulas,
      warnings: warnings,
      visibleQuestionKeys: visibleKeys.toList()..sort(),
    );
  }

  /// Maps indoor_qty + outdoor_qty → legacy total keys used by DVR/SMPS/BNC rules.
  static Map<String, dynamic> _withDerivedCameraTotals(
    Map<String, dynamic> answers,
  ) {
    double read(String key) {
      final v = answers[key];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    final indoor = read('indoor_qty') + read('Indoor_Camera_Quantity');
    final outdoor = read('outdoor_qty') + read('Outdoor_Camera_Quantity');
    final total = indoor + outdoor;
    if (total <= 0) return answers;

    void putIfBlank(String key) {
      final cur = answers[key];
      final blank = cur == null ||
          (cur is String && cur.trim().isEmpty) ||
          (cur is num && cur == 0);
      if (blank) answers[key] = total;
    }

    putIfBlank('Number of Camers'); // legacy spelling in live rules
    putIfBlank('Number of Cameras');
    putIfBlank('camera_qty');
    putIfBlank('total_cameras');
    return answers;
  }

  /// Sets line qty from a number question so estimate total = unitPrice × answer.
  /// Only lines that match the rule's target product filter are updated (one product / set).
  Future<List<CalculatorSuggestedLine>> _applyQtyFromQuestionRules(
    List<CalculatorSuggestedLine> lines,
    List<CalculatorRule> rules,
    Map<String, dynamic> answers,
  ) async {
    if (lines.isEmpty || rules.isEmpty) return lines;
    var out = lines;
    for (final rule in rules) {
      final action = rule.action;
      final key = action['question_key']?.toString().trim() ?? '';
      if (key.isEmpty) continue;
      final qty = _num(answers[key]);
      if (qty <= 0) continue;

      final match = action['match'] as Map<String, dynamic>? ?? {};
      final slug = match['sub_category_slug']?.toString().trim() ?? '';
      final nameContains = match['name_contains']?.toString();
      final pinnedProductId = match['product_id']?.toString().trim() ?? '';
      final attributes = <String, String>{};
      final rawAttrs = match['attributes'];
      if (rawAttrs is Map) {
        for (final e in rawAttrs.entries) {
          final k = e.key.toString().trim();
          final v = e.value?.toString().trim() ?? '';
          if (k.isNotEmpty && v.isNotEmpty) attributes[k] = v;
        }
      }
      final groupId = action['match_group_id']?.toString().trim() ?? '';
      final applyTo =
          (action['apply_to']?.toString() ?? 'attribute_matches').trim();

      Set<String>? allowedProductIds;
      if (pinnedProductId.isNotEmpty) {
        allowedProductIds = {pinnedProductId};
      } else if (slug.isNotEmpty) {
        try {
          final hits = await _productLookup(
            slug,
            nameContains: nameContains,
            attributes: attributes.isEmpty ? null : attributes,
          );
          allowedProductIds = {
            for (final h in hits)
              if (h.id.isNotEmpty) h.id,
          };
        } catch (_) {
          allowedProductIds = {};
        }
        // Target product filter set but nothing matched → do not scale anything.
        if (allowedProductIds.isEmpty) continue;
      }

      final before = out;
      out = [
        for (final line in before)
          if (_lineMatchesQtyTarget(
            line,
            applyTo: applyTo,
            matchGroupId: groupId,
            allowedProductIds: allowedProductIds,
          ))
            line.copyWith(qty: qty)
          else
            line,
      ];

      // Specific product pinned but not yet on estimate (e.g. no attributes /
      // not suggested yet) → add it and apply qty directly.
      if (pinnedProductId.isNotEmpty &&
          !out.any((l) => l.productId == pinnedProductId)) {
        List<CalculatorProductHit> hits = const [];
        if (slug.isNotEmpty) {
          hits = await _productsForSlug(slug);
        }
        var pinned = hits.where((h) => h.id == pinnedProductId).toList();
        if (pinned.isEmpty && slug.isNotEmpty) {
          // Broader lookup without name/attr filters already done above.
          pinned = hits.where((h) => h.id == pinnedProductId).toList();
        }
        if (pinned.isNotEmpty) {
          final p = pinned.first;
          out = [
            ...out,
            CalculatorSuggestedLine(
              label: p.name,
              qty: qty,
              productId: p.id,
              sku: p.sku,
              unitPrice: p.unitPrice,
              sourceRuleId: rule.id,
              selectionKey: 'qty_scale:${rule.id}|$pinnedProductId',
              matchGroupId:
                  groupId.isNotEmpty ? groupId : '__rule_suggests__',
              matchGroupName: (rule.name ?? '').trim().isNotEmpty
                  ? rule.name!.trim()
                  : 'Suggested products',
              alternatives: [
                CalculatorProductOption(
                  productId: p.id,
                  label: p.name,
                  sku: p.sku,
                  unitPrice: p.unitPrice,
                  imageUrl: p.imageUrl,
                ),
              ],
            ),
          ];
        }
      }
    }
    return out;
  }

  bool _lineMatchesQtyTarget(
    CalculatorSuggestedLine line, {
    required String applyTo,
    required String matchGroupId,
    required Set<String>? allowedProductIds,
  }) {
    final pid = line.productId ?? '';
    if (pid.isEmpty) return false;

    // Strongest filter: only the targeted shop product(s).
    if (allowedProductIds != null) {
      if (!allowedProductIds.contains(pid)) return false;
    }

    if (matchGroupId.isNotEmpty) {
      if (line.matchGroupId != matchGroupId) return false;
    }

    // If a product filter was provided, membership is enough.
    if (allowedProductIds != null) return true;

    // Legacy / no product filter: fall back to apply_to (prefer not using all).
    switch (applyTo) {
      case 'all_products':
        return true;
      case 'suggest':
        return line.sourceRuleId != null;
      case 'attribute_matches':
      default:
        return line.selectionKey != null || line.matchGroupId != null;
    }
  }

  /// Root family attributes = one match; each question group = its own match.
  Future<List<CalculatorSuggestedLine>> _evaluateAttributeMatches({
    required List<CalculatorQuestion> questions,
    required Map<String, dynamic> answers,
    required Set<String> visibleKeys,
    Set<String> excludeAttributeKeys = const {},
  }) async {
    final lookup = _attributeProductLookup;
    if (lookup == null) return const [];

    final byGroup = <String, _GroupAttrBucket>{};
    for (final q in questions) {
      if (!visibleKeys.contains(q.questionKey)) continue;
      if (excludeAttributeKeys.contains(q.questionKey)) continue;
      final isRoot = q.showWhenKey == null || q.showWhenKey!.isEmpty;
      // Prefer explicit quotation group so Camera type + follow-ups share a bucket.
      final groupKey = (q.groupId != null && q.groupId!.isNotEmpty)
          ? q.groupId!
          : (isRoot
              ? '__family_root__'
              : '__ungrouped__');
      final bucket = byGroup.putIfAbsent(
        groupKey,
        () => _GroupAttrBucket(
          groupId: groupKey,
          groupName: isRoot && groupKey == '__family_root__'
              ? 'Main options'
              : ((q.groupName ?? '').trim().isNotEmpty
                  ? q.groupName!.trim()
                  : 'General'),
          groupSort: groupKey == '__family_root__' ? -1 : q.groupSortOrder,
        ),
      );
      if (q.uiType == 'number' ||
          q.uiType == 'slider' ||
          q.uiType == 'integer') {
        // Root qty questions may still scale a group; selects on the root path
        // option (Camera Technology) must never filter products — that mixes
        // Indoor+Outdoor when the root attr is assigned to a question group.
        final n = _num(answers[q.questionKey]);
        if (n > 0 && bucket.qty <= 0) bucket.qty = n;
        continue;
      }
      if (isRoot) {
        // Path parent (HD / IP / …) organises follow-ups only — not a SKU filter.
        continue;
      }
      if (q.uiType == 'text') continue;
      final raw = answers[q.questionKey];
      if (raw == null) continue;
      final value = raw.toString().trim();
      if (value.isEmpty) continue;
      if (q.uiType == 'select' ||
          q.uiType == 'chips' ||
          q.uiType == 'radio' ||
          (q.options?.isNotEmpty ?? false)) {
        bucket.attrs[q.questionKey] = value;
      }
    }

    // Root family bucket never suggests products. Question-group buckets only
    // use follow-up answers (resolution, location, …) — not the path parent.
    final buckets = byGroup.values
        .where((b) => b.attrs.isNotEmpty && b.groupId != '__family_root__')
        .toList()
      ..sort((a, b) => a.groupSort.compareTo(b.groupSort));
    if (buckets.isEmpty) return const [];

    final results = await Future.wait([
      for (final b in buckets) lookup(b.attrs),
    ]);

    final lines = <CalculatorSuggestedLine>[];
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final hits = results[i];
      if (hits.isEmpty) continue;
      final options = [
        for (final h in hits)
          CalculatorProductOption(
            productId: h.id,
            label: h.name,
            sku: h.sku,
            unitPrice: h.unitPrice,
            imageUrl: h.imageUrl,
          ),
      ];
      final pick = options.first;
      final selectionKey =
          'group:${b.groupId}|${b.attrs.entries.map((e) => '${e.key}=${e.value}').join('|')}';
      final qty = b.qty > 0 ? b.qty : 1.0;
      lines.add(
        CalculatorSuggestedLine(
          label: pick.label,
          qty: qty,
          productId: pick.productId,
          sku: pick.sku,
          unitPrice: pick.unitPrice,
          selectionKey: selectionKey,
          matchGroupId: b.groupId,
          matchGroupName: b.groupName,
          alternatives: options,
        ),
      );
    }
    return lines;
  }

  void _applyVisibilityRule(
    CalculatorRule rule,
    Map<String, dynamic> answers,
    Set<String> visibleKeys,
  ) {
    if (!_evaluateCondition(rule.condition, answers)) return;
    final action = rule.action;
    final show = action['show'] as List?;
    final hide = action['hide'] as List?;
    if (show != null) {
      for (final k in show) {
        visibleKeys.add(k.toString());
      }
    }
    if (hide != null) {
      for (final k in hide) {
        visibleKeys.remove(k.toString());
      }
    }
  }

  bool _evaluateCondition(Map<String, dynamic> condition, Map<String, dynamic> answers) {
    if (condition.isEmpty) return true;
    final all = condition['all'] as List?;
    if (all != null) {
      for (final clause in all) {
        if (clause is! Map) continue;
        if (!_evalClause(Map<String, dynamic>.from(clause), answers)) return false;
      }
      return true;
    }
    return _evalClause(condition, answers);
  }

  bool _evalClause(Map<String, dynamic> clause, Map<String, dynamic> answers) {
    final varKey = clause['var'] as String?;
    final op = clause['op'] as String? ?? 'eq';
    final expected = clause['value'];
    if (varKey == null) return true;
    final actual = answers[varKey];
    final blank = actual == null ||
        (actual is String && actual.trim().isEmpty);
    switch (op) {
      case 'gte':
      case 'gt':
      case 'lte':
      case 'lt':
        // Unanswered numbers must not match (was: empty → 0, so 0 <= 4 passed).
        if (blank) return false;
        if (op == 'gte') return _num(actual) >= _num(expected);
        if (op == 'gt') return _num(actual) > _num(expected);
        if (op == 'lte') return _num(actual) <= _num(expected);
        return _num(actual) < _num(expected);
      case 'neq':
        if (blank) return true;
        return actual.toString() != expected?.toString();
      case 'eq':
      default:
        if (blank) return false;
        return actual.toString().trim().toLowerCase() ==
            (expected?.toString() ?? '').trim().toLowerCase();
    }
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  CalculatorFormulaOutput? _evaluateFormula(CalculatorRule rule, Map<String, dynamic> answers) {
    final action = rule.action;
    if (action['type'] != 'formula') return null;
    final key = action['output_key'] as String?;
    final expr = action['expression'] as String?;
    if (key == null || expr == null) return null;
    final value = _safeEvaluateExpressionWithVars(expr, answers);
    return CalculatorFormulaOutput(key: key, value: value);
  }

  Future<List<CalculatorProductHit>> _productsForSlug(
    String slug, {
    String? nameContains,
    Map<String, String>? attributes,
  }) async {
    final attrKey = attributes == null || attributes.isEmpty
        ? ''
        : (attributes.entries.map((e) => '${e.key}=${e.value}').toList()
              ..sort())
            .join('&');
    final cacheKey = '$slug|${nameContains ?? ''}|$attrKey';
    if (_slugCache.containsKey(cacheKey)) return _slugCache[cacheKey]!;
    try {
      final hits = await _productLookup(
        slug,
        nameContains: nameContains,
        attributes: attributes,
      );
      _slugCache[cacheKey] = hits;
      return hits;
    } catch (_) {
      _slugCache[cacheKey] = const [];
      return const [];
    }
  }

  Future<List<CalculatorSuggestedLine>> _evaluateSuggest(
    CalculatorRule rule,
    Map<String, dynamic> answers,
  ) async {
    final action = rule.action;
    final actionType = action['type']?.toString() ?? '';
    if (actionType == 'charge_line') {
      return _evaluateChargeLine(rule, answers);
    }
    if (actionType != 'suggest_product') return [];

    final match = action['match'] as Map<String, dynamic>? ?? {};
    final slug = match['sub_category_slug'] as String?;
    final nameContains = match['name_contains'] as String?;
    final productId = match['product_id']?.toString().trim() ?? '';
    final attributes = <String, String>{};
    final rawAttrs = match['attributes'];
    if (rawAttrs is Map) {
      for (final e in rawAttrs.entries) {
        final k = e.key.toString().trim();
        final v = e.value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) attributes[k] = v;
      }
    }

    double qty = 1;
    final qtyVar = action['qty_var'] as String?;
    final qtyFormula = action['qty_formula'] as String?;
    if (qtyVar != null && answers.containsKey(qtyVar)) {
      qty = _num(answers[qtyVar]);
    } else if (qtyFormula != null) {
      qty = _safeEvaluateExpressionWithVars(qtyFormula, answers);
    }
    if (qty <= 0) qty = 1;

    List<CalculatorProductHit> products = const [];
    if (slug != null && slug.isNotEmpty) {
      products = await _productsForSlug(
        slug,
        nameContains: nameContains,
        attributes: attributes.isEmpty ? null : attributes,
      );
    }

    // Optional: pin to one shop product.
    if (productId.isNotEmpty && products.isNotEmpty) {
      final pinned = products.where((p) => p.id == productId).toList();
      if (pinned.isNotEmpty) {
        products = pinned;
      } else {
        // Still allow exact id if lookup returned others (stale filter).
        products = [
          for (final p in products)
            if (p.id == productId) p,
        ];
      }
    } else if (productId.isNotEmpty && products.isEmpty) {
      // Subcategory filter missed it — try attribute-free slug then pin.
      if (slug != null && slug.isNotEmpty) {
        final allInSub = await _productsForSlug(slug);
        products = [for (final p in allInSub) if (p.id == productId) p];
      }
    }

    if (products.isEmpty) {
      return [
        CalculatorSuggestedLine(
          label: rule.name ?? 'Suggested item (${slug ?? 'product'})',
          qty: qty,
          sourceRuleId: rule.id,
          showUnderQuestionKey: _showUnderQuestionKey(action),
        ),
      ];
    }

    final options = [
      for (final h in products)
        CalculatorProductOption(
          productId: h.id,
          label: h.name,
          sku: h.sku,
          unitPrice: h.unitPrice,
          imageUrl: h.imageUrl,
        ),
    ];
    final pick = options.first;
    final attrKey = attributes.isEmpty
        ? ''
        : (attributes.entries.map((e) => '${e.key}=${e.value}').toList()
              ..sort())
            .join('|');
    final selectionKey =
        'rule:${rule.id}|${slug ?? ''}|$productId|${nameContains ?? ''}|$attrKey';
    final groupIdRaw = action['match_group_id']?.toString().trim() ?? '';
    final groupNameRaw = action['match_group_name']?.toString().trim() ?? '';
    final matchGroupId =
        groupIdRaw.isNotEmpty ? groupIdRaw : '__rule_suggests__';
    final matchGroupName = groupNameRaw.isNotEmpty
        ? groupNameRaw
        : ((rule.name ?? '').trim().isNotEmpty
            ? rule.name!.trim()
            : 'Suggested products');

    return [
      CalculatorSuggestedLine(
        label: pick.label,
        qty: qty,
        productId: pick.productId,
        sku: pick.sku,
        unitPrice: pick.unitPrice,
        sourceRuleId: rule.id,
        selectionKey: selectionKey,
        matchGroupId: matchGroupId,
        matchGroupName: matchGroupName,
        showUnderQuestionKey: _showUnderQuestionKey(action),
        alternatives: options,
      ),
    ];
  }

  /// Priced estimate line (installation / labour) — qty × unit_price.
  List<CalculatorSuggestedLine> _evaluateChargeLine(
    CalculatorRule rule,
    Map<String, dynamic> answers,
  ) {
    final action = rule.action;
    final label = (action['label']?.toString().trim().isNotEmpty == true)
        ? action['label'].toString().trim()
        : ((rule.name ?? '').trim().isNotEmpty
            ? rule.name!.trim()
            : 'Charge');
    final unitPrice = _num(action['unit_price']);
    double qty = 1;
    final qtyVar = action['qty_var']?.toString().trim() ?? '';
    final qtyFormula = action['qty_formula']?.toString().trim() ?? '';
    if (qtyVar.isNotEmpty) {
      qty = _num(answers[qtyVar]);
    } else if (qtyFormula.isNotEmpty) {
      qty = _safeEvaluateExpressionWithVars(qtyFormula, answers);
    }
    if (qty <= 0 || unitPrice <= 0) return const [];

    final groupIdRaw = action['match_group_id']?.toString().trim() ?? '';
    final groupNameRaw = action['match_group_name']?.toString().trim() ?? '';
    final matchGroupId =
        groupIdRaw.isNotEmpty ? groupIdRaw : '__rule_suggests__';
    final matchGroupName = groupNameRaw.isNotEmpty
        ? groupNameRaw
        : 'Installation';

    return [
      CalculatorSuggestedLine(
        label: label,
        qty: qty,
        unitPrice: unitPrice,
        sourceRuleId: rule.id,
        selectionKey: 'charge:${rule.id}',
        matchGroupId: matchGroupId,
        matchGroupName: matchGroupName,
        showUnderQuestionKey:
            (action['show_under_question']?.toString().trim().isNotEmpty == true)
                ? action['show_under_question'].toString().trim()
                : null,
        alternatives: const [],
      ),
    ];
  }

  /// Prefer explicit admin placement; fall back to qty_var (Indoor/Outdoor qty).
  static String? _showUnderQuestionKey(Map<String, dynamic> action) {
    final explicit = action['show_under_question']?.toString().trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final qtyVar = action['qty_var']?.toString().trim() ?? '';
    if (qtyVar.isNotEmpty) return qtyVar;
    return null;
  }

  double _safeEvaluateExpressionWithVars(String expression, Map<String, dynamic> vars) {
    var expr = expression.trim();
    // Replace longer keys first so camera_qty wins over qty.
    final keys = vars.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      expr = expr.replaceAll(key, _num(vars[key]).toString());
    }
    return _parseSimpleMath(expr);
  }

  double _parseSimpleMath(String expr) {
    expr = expr.replaceAll(' ', '');
    if (expr.isEmpty) return 0;
    try {
      return _ExprParser(expr).parse();
    } catch (_) {
      return double.tryParse(expr) ?? 0;
    }
  }
}

class _ExprParser {
  _ExprParser(this._s);
  final String _s;
  int _i = 0;

  double parse() => _parseAddSub();

  double _parseAddSub() {
    var value = _parseMulDiv();
    while (_i < _s.length) {
      final op = _s[_i];
      if (op != '+' && op != '-') break;
      _i++;
      final right = _parseMulDiv();
      value = op == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseMulDiv() {
    var value = _parsePrimary();
    while (_i < _s.length) {
      final op = _s[_i];
      if (op != '*' && op != '/') break;
      _i++;
      final right = _parsePrimary();
      value = op == '*' ? value * right : (right == 0 ? 0 : value / right);
    }
    return value;
  }

  double _parsePrimary() {
    if (_i >= _s.length) return 0;
    if (_s[_i] == '(') {
      _i++;
      final value = _parseAddSub();
      if (_i < _s.length && _s[_i] == ')') _i++;
      return value;
    }
    final start = _i;
    if (_s[_i] == '-') _i++;
    while (_i < _s.length && (_s[_i] == '.' || (_s.codeUnitAt(_i) >= 48 && _s.codeUnitAt(_i) <= 57))) {
      _i++;
    }
    return double.tryParse(_s.substring(start, _i)) ?? 0;
  }
}

class _GroupAttrBucket {
  _GroupAttrBucket({
    required this.groupId,
    required this.groupName,
    required this.groupSort,
  });

  final String groupId;
  final String groupName;
  final int groupSort;
  final attrs = <String, String>{};
  double qty = 0;
}

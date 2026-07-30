// Public Calculator Repository - Anonymous Access
// Uses v_public_calculator_families view + published template RLS

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../calculator/data/calculator_repository.dart';
import '../../../calculator/domain/calculator_engine.dart';
import '../../../calculator/domain/calculator_models.dart';

class PublicCalculatorRepository {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getCalculatorFamilies() async {
    final response = await _client
        .from('v_public_calculator_families')
        .select()
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getCalculatorFamilyBySlug(String slug) async {
    final response = await _client
        .from('v_public_calculator_families')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    return response;
  }

  Future<List<CalculatorFamily>> listFamilies() async {
    final rows = await getCalculatorFamilies();
    return rows.map(CalculatorFamily.fromRow).toList();
  }

  Future<CalculatorFamily?> familyBySlug(String slug) async {
    final row = await getCalculatorFamilyBySlug(slug);
    if (row == null) return null;
    return CalculatorFamily.fromRow(row);
  }

  Future<List<CalculatorTemplate>> listPublishedTemplates(String familyId) async {
    final rows = await _client
        .from('calculator_templates')
        .select()
        .eq('family_id', familyId)
        .eq('is_published', true)
        .eq('is_active', true)
        .order('version', ascending: false);
    return (rows as List)
        .map((e) => CalculatorTemplate.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<CalculatorQuestion>> listQuestions(String templateId) async {
    final rows = await _client
        .from('calculator_questions')
        .select()
        .eq('template_id', templateId)
        .order('sort_order');
    final questions = (rows as List)
        .map((e) => CalculatorQuestion.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    final shopOptions = await _shopAttributeOptionsByKey();
    return CalculatorQuestion.enrichWithShopOptions(questions, shopOptions);
  }

  Future<List<CalculatorQuestion>> listFamilyAttributeQuestions(
    String familyId, {
    String templateId = '',
  }) async {
    try {
      final rows = await _client
          .from('calculator_family_attributes')
          .select(
            'sort_order, selected_options, question_mode, group_id, '
            'calculator_question_groups(id, name, sort_order), '
            'attribute_master(id, key, label, data_type, allowed_values, attribute_options(label, sort_order, is_active))',
          )
          .eq('family_id', familyId)
          .order('sort_order');
      final root = CalculatorRepository.questionsFromFamilyAttributeRows(
        rows as List,
        templateId,
      );
      final parentKeyByAttrId = <String, String>{};
      final parentGroupByAttrId =
          <String, ({String? id, String? name, int sort})>{};
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final am = row['attribute_master'];
        if (am is! Map) continue;
        final attrId = am['id']?.toString() ?? '';
        if (attrId.isEmpty) continue;
        parentKeyByAttrId[attrId] = am['key']?.toString() ?? '';
        final g = row['calculator_question_groups'];
        if (g is Map) {
          parentGroupByAttrId[attrId] = (
            id: g['id']?.toString() ?? row['group_id']?.toString(),
            name: (g['name'] as String?)?.trim(),
            sort: (g['sort_order'] as num?)?.toInt() ?? 0,
          );
        } else if (row['group_id'] != null) {
          parentGroupByAttrId[attrId] = (
            id: row['group_id']?.toString(),
            name: null,
            sort: 0,
          );
        }
      }
      final pathQs = await _listOptionPathQuestions(
        familyId,
        templateId: templateId,
        parentKeyByAttrId: parentKeyByAttrId,
        parentGroupByAttrId: parentGroupByAttrId,
      );
      final groups = await listQuestionGroups(familyId);
      return CalculatorRepository.enrichQuestionsWithGroups(
        [...root, ...pathQs],
        groups,
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<CalculatorQuestion>> _listOptionPathQuestions(
    String familyId, {
    required String templateId,
    required Map<String, String> parentKeyByAttrId,
    Map<String, ({String? id, String? name, int sort})> parentGroupByAttrId =
        const {},
  }) async {
    try {
      final paths = await _client
          .from('calculator_family_option_paths')
          .select(
            'id, parent_attribute_id, option_label, sort_order, '
            'calculator_family_option_path_attributes('
            'sort_order, selected_options, '
            'attribute_master(id, key, label, data_type, allowed_values, attribute_options(label, sort_order, is_active))'
            '), '
            'calculator_family_option_path_questions(id, question_key, label, ui_type, options, source_attribute_id, sort_order, group_id, calculator_question_groups(id, name, sort_order))',
          )
          .eq('family_id', familyId)
          .order('sort_order');
      final missingParentIds = <String>{};
      for (final raw in paths as List) {
        final path = Map<String, dynamic>.from(raw as Map);
        final parentAttrId = path['parent_attribute_id']?.toString() ?? '';
        if (parentAttrId.isNotEmpty &&
            (parentKeyByAttrId[parentAttrId] ?? '').isEmpty) {
          missingParentIds.add(parentAttrId);
        }
      }
      if (missingParentIds.isNotEmpty) {
        try {
          final masters = await _client
              .from('attribute_master')
              .select('id, key')
              .inFilter('id', missingParentIds.toList());
          for (final raw in masters as List) {
            final m = Map<String, dynamic>.from(raw as Map);
            final id = m['id']?.toString() ?? '';
            final key = m['key']?.toString().trim() ?? '';
            if (id.isNotEmpty && key.isNotEmpty) {
              parentKeyByAttrId[id] = key;
            }
          }
        } catch (_) {}
      }
      final out = <CalculatorQuestion>[];
      for (final raw in paths as List) {
        final path = Map<String, dynamic>.from(raw as Map);
        final parentAttrId = path['parent_attribute_id']?.toString() ?? '';
        final parentKey = parentKeyByAttrId[parentAttrId] ?? '';
        final optionLabel = (path['option_label'] as String?)?.trim() ?? '';
        if (parentKey.isEmpty || optionLabel.isEmpty) continue;
        final pathSort = (path['sort_order'] as num?)?.toInt() ?? 0;
        final parentGroup = parentGroupByAttrId[parentAttrId];
        final children = path['calculator_family_option_path_attributes'];
        if (children is List && children.isNotEmpty) {
          final childRows = <Map<String, dynamic>>[];
          for (final ch in children) {
            final m = Map<String, dynamic>.from(ch as Map);
            childRows.add({
              ...m,
              'sort_order':
                  pathSort * 1000 + ((m['sort_order'] as num?)?.toInt() ?? 0),
              'question_mode': CalculatorFamilyQuestionMode.select,
              if (parentGroup != null) ...{
                'group_id': parentGroup.id,
                'calculator_question_groups': {
                  'id': parentGroup.id,
                  'name': parentGroup.name,
                  'sort_order': parentGroup.sort,
                },
              },
            });
          }
          childRows.sort(
            (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
                .compareTo((b['sort_order'] as num?)?.toInt() ?? 0),
          );
          final built = CalculatorRepository.questionsFromFamilyAttributeRows(
            childRows,
            templateId,
          );
          for (final q in built) {
            out.add(
              q.copyWith(
                id: 'path-${path['id']}-${q.questionKey}',
                showWhenKey: parentKey,
                showWhenValue: optionLabel,
                defaultVisibility: false,
                groupId: q.groupId ?? parentGroup?.id,
                groupName: q.groupName ?? parentGroup?.name,
                groupSortOrder: q.groupId != null
                    ? q.groupSortOrder
                    : (parentGroup?.sort ?? 0),
              ),
            );
          }
        }
        final customQs = path['calculator_family_option_path_questions'];
        if (customQs is List) {
          for (final cq in customQs) {
            final m = Map<String, dynamic>.from(cq as Map);
            final q = CalculatorFamilyOptionPathQuestion.fromRow(m);
            if (q.questionKey.isEmpty) continue;
            final g = m['calculator_question_groups'];
            String? qGroupId = q.groupId ?? parentGroup?.id;
            String? qGroupName = parentGroup?.name;
            var qGroupSort = parentGroup?.sort ?? 0;
            if (g is Map) {
              qGroupId = g['id']?.toString() ?? qGroupId;
              qGroupName = (g['name'] as String?)?.trim() ?? qGroupName;
              qGroupSort = (g['sort_order'] as num?)?.toInt() ?? qGroupSort;
            }
            out.add(
              CalculatorQuestion(
                id: 'path-q-${path['id']}-${q.questionKey}',
                templateId: templateId,
                questionKey: q.questionKey,
                label: q.label,
                uiType: q.uiType,
                options: q.options,
                sortOrder: pathSort * 1000 + 500 + q.sortOrder,
                defaultVisibility: false,
                showWhenKey: parentKey,
                showWhenValue: optionLabel,
                groupId: qGroupId,
                groupName: qGroupName,
                groupSortOrder: qGroupSort,
              ),
            );
          }
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<List<CalculatorQuestionGroup>> listQuestionGroups(String familyId) async {
    try {
      final rows = await _client
          .from('calculator_question_groups')
          .select()
          .eq('family_id', familyId)
          .eq('is_active', true)
          .order('sort_order');
      return [
        for (final r in rows as List)
          CalculatorQuestionGroup.fromRow(Map<String, dynamic>.from(r as Map)),
      ].where((g) => g.id.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CalculatorQuestion>> listQuestionsForFamily({
    required String familyId,
    String? templateId,
  }) async {
    final familyQs = await listFamilyAttributeQuestions(
      familyId,
      templateId: templateId ?? '',
    );
    final templateQs = (templateId != null && templateId.isNotEmpty)
        ? await listQuestions(templateId)
        : <CalculatorQuestion>[];
    return CalculatorRepository.mergeFamilyAndTemplateQuestions(
      familyQs,
      templateQs,
    );
  }

  Future<Map<String, List<String>>> _shopAttributeOptionsByKey() async {
    try {
      final rows = await _client
          .from('attribute_master')
          .select(
            'key, data_type, allowed_values, attribute_options(label, sort_order, is_active)',
          )
          .eq('use_in_calculator', true)
          .eq('is_active', true);
      final out = <String, List<String>>{};
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final key = (row['key'] as String?)?.trim() ?? '';
        if (key.isEmpty) continue;
        final nested = row['attribute_options'];
        final fromTable = <({String label, int sort})>[];
        if (nested is List) {
          for (final o in nested) {
            final m = Map<String, dynamic>.from(o as Map);
            if (m['is_active'] == false) continue;
            final label = (m['label'] as String?)?.trim() ?? '';
            if (label.isEmpty) continue;
            fromTable.add((
              label: label,
              sort: (m['sort_order'] as num?)?.toInt() ?? 0,
            ));
          }
        }
        fromTable.sort((a, b) => a.sort.compareTo(b.sort));
        var labels = fromTable.map((e) => e.label).toList();
        if (labels.isEmpty) {
          final av = row['allowed_values'];
          if (av is List) {
            labels =
                av.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        }
        if (labels.isNotEmpty) out[key] = labels;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<List<CalculatorRule>> listRules(String templateId) async {
    final rows = await _client
        .from('calculator_rules')
        .select()
        .eq('template_id', templateId)
        .eq('is_active', true)
        .order('priority');
    return (rows as List)
        .map((e) => CalculatorRule.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Fast anonymous product lookup (no Firebase session sync).
  /// Supports legacy rule slugs (dvr/smps/hdd…) via aliases + optional name filter.
  Future<List<CalculatorProductHit>> findProductsBySubCategorySlug(
    String slug, {
    int limit = 8,
    String? nameContains,
    Map<String, String>? attributes,
  }) async {
    if (slug.trim().isEmpty && (nameContains == null || nameContains.trim().isEmpty)) {
      return const [];
    }
    try {
      final candidates = _slugCandidates(slug);
      final hints = <String>{
        if (nameContains != null && nameContains.trim().isNotEmpty) nameContains.trim(),
        if (_defaultNameHint(slug) != null) _defaultNameHint(slug)!,
        // Catalog HDDs are titled "Hard Disk", not "HDD".
        if ((nameContains ?? slug).toLowerCase().contains('hdd')) 'Hard Disk',
      };
      final attrFilters = <String, String>{
        for (final e in (attributes ?? const <String, String>{}).entries)
          if (e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
            e.key.trim(): e.value.trim(),
      };

      Future<List<CalculatorProductHit>> applyAttrFilter(
        List<CalculatorProductHit> hits,
      ) async {
        if (attrFilters.isEmpty || hits.isEmpty) return hits;
        final byAttr = await findProductsMatchingAttributes(
          attrFilters,
          limit: 200,
        );
        final inSub = hits.map((h) => h.id).toSet();
        return [
          for (final h in byAttr)
            if (inSub.contains(h.id)) h,
        ];
      }

      for (final candidate in candidates) {
        if (hints.isEmpty) {
          final hits = await applyAttrFilter(
            await _productsInSubcategory(candidate, limit: limit),
          );
          if (hits.isNotEmpty) return hits;
          // Subcategory exists but no attribute match — stay in this sub only.
          final inSub = await _productsInSubcategory(candidate, limit: limit);
          if (inSub.isNotEmpty && attrFilters.isEmpty) return inSub;
          if (inSub.isNotEmpty && attrFilters.isNotEmpty) {
            // Prefer empty over leaking into another subcategory (e.g. DVR vs SMPS).
            continue;
          }
          continue;
        }
        for (final hint in hints) {
          final hits = await applyAttrFilter(
            await _productsInSubcategory(
              candidate,
              limit: limit,
              nameContains: hint,
            ),
          );
          if (hits.isNotEmpty) return hits;
        }
        // Name hint too strict — try same subcategory without name filter.
        final allInSub = await applyAttrFilter(
          await _productsInSubcategory(candidate, limit: limit),
        );
        if (allInSub.isNotEmpty) return allInSub;
      }

      // Never fall back to attribute/name matches outside the subcategory.
      // Shared attrs (e.g. Channel) would otherwise pull a DVR for an SMPS rule.
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static List<String> _slugCandidates(String slug) {
    final s = slug.trim().toLowerCase();
    const aliases = <String, List<String>>{
      'dvr': ['recording-devices'],
      'nvr': ['recording-devices'],
      'smps': ['power-supply', 'power-supplies', 'smps-power-supply'],
      'power-supply': ['smps', 'power-supplies', 'smps-power-supply'],
      'power-supplies': ['power-supply', 'smps'],
      'camera': ['cameras', 'cctv-cameras', 'ip-cameras', 'hd-cameras'],
      'cameras': ['camera', 'cctv-cameras', 'ip-cameras', 'hd-cameras'],
      'cctv': ['cameras', 'cctv-cameras'],
      'hdd': ['storage-devices', 'ssd'],
      'hard-disk': ['storage-devices', 'ssd'],
      'poe-switch': ['network-switches', 'poe-devices'],
      'poe': ['network-switches', 'poe-devices'],
    };
    final mapped = aliases[s];
    if (mapped == null) return [s];
    return [s, ...mapped];
  }

  static String? _defaultNameHint(String slug) {
    return switch (slug.trim().toLowerCase()) {
      'dvr' => 'DVR',
      'nvr' => 'NVR',
      'smps' || 'power-supply' || 'power-supplies' || 'smps-power-supply' =>
        'SMPS',
      'hdd' || 'hard-disk' => 'Hard Disk',
      'poe-switch' || 'poe' => 'PoE',
      _ => null,
    };
  }

  Future<List<CalculatorProductHit>> _productsInSubcategory(
    String slug, {
    required int limit,
    String? nameContains,
  }) async {
    final subs = await _client
        .from('v_public_subcategories')
        .select('id')
        .eq('slug', slug)
        .limit(1);
    if ((subs as List).isEmpty) return const [];
    final subId = (subs.first as Map)['id']?.toString();
    if (subId == null || subId.isEmpty) return const [];

    var query = _client
        .from('v_public_products')
        .select('id, name, sku, online_price, selling_price, og_image')
        .eq('sub_category_id', subId);
    final hint = nameContains?.trim();
    if (hint != null && hint.isNotEmpty) {
      query = query.ilike('name', '%$hint%');
    }
    final products = await query.order('name').limit(limit);
    return _mapHits(products as List);
  }

  List<CalculatorProductHit> _mapHits(List raw) {
    final hits = <CalculatorProductHit>[
      for (final row in raw)
        CalculatorProductHit(
          id: (row as Map)['id']?.toString() ?? '',
          name: (row['name'] ?? 'Product').toString(),
          sku: row['sku']?.toString(),
          unitPrice: _priceOf(row),
          imageUrl: _imageOf(row),
        ),
    ].where((p) => p.id.isNotEmpty).toList();
    // Prefer priced products first.
    hits.sort((a, b) {
      final ap = a.unitPrice ?? 0;
      final bp = b.unitPrice ?? 0;
      if (ap <= 0 && bp > 0) return 1;
      if (bp <= 0 && ap > 0) return -1;
      return 0;
    });
    return hits;
  }

  Future<List<CalculatorProductHit>> _enrichWithGalleryImages(
    List<CalculatorProductHit> hits,
  ) async {
    if (hits.isEmpty) return hits;
    try {
      final ids = hits.map((h) => h.id).toList();
      final byProduct = <String, String>{};
      for (var i = 0; i < ids.length; i += 80) {
        final chunk = ids.sublist(i, i + 80 > ids.length ? ids.length : i + 80);
        final rows = await _client
            .from('v_public_product_images')
            .select('product_id, url, webp_url, sort_order')
            .inFilter('product_id', chunk)
            .order('sort_order');
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final pid = row['product_id']?.toString();
          if (pid == null || byProduct.containsKey(pid)) continue;
          final webp = (row['webp_url'] ?? '').toString().trim();
          final url = (row['url'] ?? '').toString().trim();
          final pick = webp.isNotEmpty ? webp : url;
          if (pick.isNotEmpty) byProduct[pid] = pick;
        }
      }
      if (byProduct.isEmpty) return hits;
      return [
        for (final h in hits)
          CalculatorProductHit(
            id: h.id,
            name: h.name,
            sku: h.sku,
            unitPrice: h.unitPrice,
            imageUrl: byProduct[h.id] ?? h.imageUrl,
          ),
      ];
    } catch (_) {
      return hits;
    }
  }

  /// Products that have ALL given attribute key → option value pairs (AND match).
  /// Sorted cheapest first. Used when calculator answers map to shop attributes.
  Future<List<CalculatorProductHit>> findProductsMatchingAttributes(
    Map<String, String> attributeKeyToValue, {
    int limit = 40,
  }) async {
    final filters = <String, String>{
      for (final e in attributeKeyToValue.entries)
        if (e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
          e.key.trim(): e.value.trim(),
    };
    if (filters.isEmpty) return const [];

    try {
      Set<String>? matchingIds;
      for (final entry in filters.entries) {
        final rows = await _client
            .from('v_public_product_attributes')
            .select('product_id, value_text, value_number')
            .eq('attribute_key', entry.key);
        final ids = <String>{};
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final pid = row['product_id']?.toString();
          if (pid == null || pid.isEmpty) continue;
          final text = (row['value_text'] ?? '').toString().trim();
          final numVal = row['value_number'];
          final numStr = numVal == null ? '' : numVal.toString();
          final want = entry.value;
          if (text == want ||
              numStr == want ||
              (numVal is num &&
                  double.tryParse(want) != null &&
                  (numVal - double.parse(want)).abs() < 0.0001)) {
            ids.add(pid);
          }
        }
        matchingIds = matchingIds == null ? ids : matchingIds.intersection(ids);
        if (matchingIds.isEmpty) return const [];
      }

      final idList = matchingIds!.toList();
      if (idList.isEmpty) return const [];

      // Chunk .inFilter to avoid overly long URLs.
      final hits = <CalculatorProductHit>[];
      for (var i = 0; i < idList.length; i += 80) {
        final chunk = idList.sublist(i, i + 80 > idList.length ? idList.length : i + 80);
        var products = await _client
            .from('v_public_products')
            .select(
              'id, name, sku, online_price, selling_price, og_image, show_in_calculator',
            )
            .inFilter('id', chunk)
            .eq('show_in_calculator', true);
        if ((products as List).isEmpty) {
          products = await _client
              .from('v_public_products')
              .select('id, name, sku, online_price, selling_price, og_image')
              .inFilter('id', chunk);
        }
        hits.addAll(_mapHits(products as List));
      }

      hits.sort((a, b) {
        final ap = a.unitPrice ?? double.infinity;
        final bp = b.unitPrice ?? double.infinity;
        final byPrice = ap.compareTo(bp);
        if (byPrice != 0) return byPrice;
        return a.name.compareTo(b.name);
      });
      final limited = hits.length <= limit ? hits : hits.sublist(0, limit);
      return _enrichWithGalleryImages(limited);
    } catch (_) {
      return const [];
    }
  }

  static double? _priceOf(Map row) {
    final online = row['online_price'];
    final selling = row['selling_price'];
    if (online is num && online > 0) return online.toDouble();
    if (selling is num && selling > 0) return selling.toDouble();
    final o = double.tryParse('$online');
    if (o != null && o > 0) return o;
    final s = double.tryParse('$selling');
    if (s != null && s > 0) return s;
    return null;
  }

  static String? _imageOf(Map row) {
    final og = (row['og_image'] ?? '').toString().trim();
    if (og.isNotEmpty) return og;
    return null;
  }
}

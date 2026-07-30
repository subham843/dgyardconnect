import 'package:firebase_auth/firebase_auth.dart';

import '../../shop/data/supabase_repository_base.dart';
import '../domain/calculator_models.dart';

class CalculatorRepository {
  Future<List<CalculatorFamily>> listFamilies({bool activeOnly = true}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    var q = c.from('calculator_families').select();
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('sort_order');
    return (rows as List)
        .map(
          (e) => CalculatorFamily.fromRow(SupabaseRepositoryBase.rowToMap(e)),
        )
        .toList();
  }

  Future<String?> createFamily({
    required String name,
    String? description,
    int sortOrder = 0,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c
        .from('calculator_families')
        .insert({
          'name': name.trim(),
          'slug': SupabaseRepositoryBase.slugify(name),
          'description': description?.trim(),
          'sort_order': sortOrder,
        })
        .select('id')
        .single();
    return row['id'] as String?;
  }

  Future<void> updateFamily({
    required String id,
    required String name,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
    bool updateSlug = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final payload = <String, dynamic>{
      'name': name.trim(),
      'description': description?.trim(),
      'sort_order': sortOrder,
      'is_active': isActive,
    };
    if (updateSlug) {
      payload['slug'] = SupabaseRepositoryBase.slugify(name);
    }
    await c.from('calculator_families').update(payload).eq('id', id);
  }

  /// Replace linked Shop attributes for a family (order + option subsets preserved).
  Future<void> setFamilyAttributes({
    required String familyId,
    required List<CalculatorFamilyAttributeLink> links,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) {
      throw StateError('Supabase session unavailable — sign in again and retry.');
    }
    await c.from('calculator_family_attributes').delete().eq('family_id', familyId);
    if (links.isEmpty) return;
    await c.from('calculator_family_attributes').insert([
      for (var i = 0; i < links.length; i++)
        {
          'family_id': familyId,
          'attribute_id': links[i].attributeId,
          'sort_order': i,
          'selected_options': links[i].selectedOptions,
          'question_mode': links[i].questionMode,
          'group_id': links[i].groupId,
        },
    ]);
  }

  Future<List<CalculatorQuestionGroup>> listQuestionGroups(String familyId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('calculator_question_groups')
        .select()
        .eq('family_id', familyId)
        .order('sort_order');
    return [
      for (final r in rows as List)
        CalculatorQuestionGroup.fromRow(Map<String, dynamic>.from(r as Map)),
    ].where((g) => g.id.isNotEmpty).toList();
  }

  /// Replace / upsert question groups. Preserves existing ids; sort_order = list index.
  Future<Map<String, String>> setQuestionGroups({
    required String familyId,
    required List<CalculatorQuestionGroup> groups,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) {
      throw StateError('Supabase session unavailable — sign in again and retry.');
    }

    final existing = await listQuestionGroups(familyId);
    final existingById = {for (final g in existing) g.id: g};
    final keepIds = <String>{
      for (final g in groups)
        if (!g.id.startsWith('local-') && existingById.containsKey(g.id)) g.id,
    };

    for (final g in existing) {
      if (!keepIds.contains(g.id)) {
        await c.from('calculator_question_groups').delete().eq('id', g.id);
      }
    }

    final idMap = <String, String>{};
    final orderedIds = <String>[];

    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final name = g.name.trim();
      if (name.isEmpty) continue;

      if (!g.id.startsWith('local-') && existingById.containsKey(g.id)) {
        final updated = await c
            .from('calculator_question_groups')
            .update({
              'name': name,
              'description': g.description,
              'is_active': g.isActive,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', g.id)
            .select('id')
            .maybeSingle();
        if (updated == null) {
          throw StateError(
            'Could not update group "$name" — check admin access / RLS.',
          );
        }
        idMap[g.id] = g.id;
        orderedIds.add(g.id);
        continue;
      }

      final res = await c
          .from('calculator_question_groups')
          .insert({
            'family_id': familyId,
            'name': name,
            'description': g.description,
            // Temporary unique rank; final order applied via RPC below.
            'sort_order': 100000 + i,
            'is_active': g.isActive,
          })
          .select('id')
          .maybeSingle();
      final newId = res?['id']?.toString();
      if (newId == null || newId.isEmpty) {
        throw StateError('Could not create group "$name".');
      }
      idMap[g.id] = newId;
      orderedIds.add(newId);
    }

    if (orderedIds.isNotEmpty) {
      try {
        await c.rpc(
          'reorder_calculator_question_groups',
          params: {
            'p_family_id': familyId,
            'p_group_ids': orderedIds,
          },
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final missingRpc = msg.contains('pgrst202') ||
            msg.contains('could not find the function') ||
            msg.contains('reorder_calculator_question_groups');
        if (!missingRpc) rethrow;
        // Fallback when RPC is not deployed yet: two-phase client updates.
        for (var i = 0; i < orderedIds.length; i++) {
          await c.from('calculator_question_groups').update({
            'sort_order': -100000 - i,
          }).eq('id', orderedIds[i]);
        }
        for (var i = 0; i < orderedIds.length; i++) {
          final updated = await c
              .from('calculator_question_groups')
              .update({'sort_order': i})
              .eq('id', orderedIds[i])
              .select('id, sort_order')
              .maybeSingle();
          if (updated == null) {
            throw StateError('Could not reorder question groups.');
          }
        }
      }
    }

    final saved = await listQuestionGroups(familyId);
    if (saved.length != orderedIds.length) {
      throw StateError(
        'Question group count mismatch after save '
        '(${saved.length} vs ${orderedIds.length}).',
      );
    }
    for (var i = 0; i < orderedIds.length; i++) {
      if (saved[i].id != orderedIds[i] || saved[i].sortOrder != i) {
        throw StateError(
          'Question group order did not persist. '
          'Expected ${orderedIds[i]} at $i, '
          'got ${saved[i].id} (sort ${saved[i].sortOrder}).',
        );
      }
    }
    return idMap;
  }

  /// Apply authoritative group name + sort onto questions.
  static List<CalculatorQuestion> enrichQuestionsWithGroups(
    List<CalculatorQuestion> questions,
    List<CalculatorQuestionGroup> groups,
  ) {
    if (groups.isEmpty || questions.isEmpty) return questions;
    final byId = {for (final g in groups) g.id: g};
    return [
      for (final q in questions)
        if (q.groupId != null && byId.containsKey(q.groupId))
          q.copyWith(
            groupName: byId[q.groupId!]!.name,
            groupSortOrder: byId[q.groupId!]!.sortOrder,
          )
        else
          q,
    ];
  }

  Future<List<String>> listFamilyAttributeIds(String familyId) async {
    final links = await listFamilyAttributeLinks(familyId);
    return [for (final l in links) l.attributeId];
  }

  Future<List<CalculatorFamilyAttributeLink>> listFamilyAttributeLinks(
    String familyId,
  ) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('calculator_family_attributes')
        .select('attribute_id, sort_order, selected_options, question_mode, group_id')
        .eq('family_id', familyId)
        .order('sort_order');
    return [
      for (final r in rows as List)
        CalculatorFamilyAttributeLink.fromRow(
          Map<String, dynamic>.from(r as Map),
        ),
    ].where((l) => l.attributeId.isNotEmpty).toList();
  }

  /// Family attributes as calculator questions (root + option quotation paths).
  Future<List<CalculatorQuestion>> listFamilyAttributeQuestions(
    String familyId, {
    String templateId = '',
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    try {
      final rows = await c
          .from('calculator_family_attributes')
          .select(
            'sort_order, selected_options, question_mode, group_id, '
            'calculator_question_groups(id, name, sort_order), '
            'attribute_master(id, key, label, data_type, allowed_values, attribute_options(label, sort_order, is_active))',
          )
          .eq('family_id', familyId)
          .order('sort_order');
      final root = questionsFromFamilyAttributeRows(rows as List, templateId);
      final parentKeyByAttrId = <String, String>{};
      final parentGroupByAttrId = <String, ({String? id, String? name, int sort})>{};
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final am = row['attribute_master'];
        if (am is! Map) continue;
        final attrId = am['id']?.toString() ?? '';
        final key = am['key']?.toString() ?? '';
        if (attrId.isEmpty) continue;
        parentKeyByAttrId[attrId] = key;
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
      return enrichQuestionsWithGroups([...root, ...pathQs], groups);
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
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    try {
      final paths = await c
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
          final childRows = [
            for (final ch in children)
              {
                ...Map<String, dynamic>.from(ch as Map),
                'sort_order': pathSort * 1000 +
                    ((ch['sort_order'] as num?)?.toInt() ?? 0),
                'question_mode': CalculatorFamilyQuestionMode.select,
                if (parentGroup != null) ...{
                  'group_id': parentGroup.id,
                  'calculator_question_groups': {
                    'id': parentGroup.id,
                    'name': parentGroup.name,
                    'sort_order': parentGroup.sort,
                  },
                },
              },
          ]..sort(
              (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
                  .compareTo((b['sort_order'] as num?)?.toInt() ?? 0),
            );
          final built = questionsFromFamilyAttributeRows(childRows, templateId);
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

  Future<List<CalculatorFamilyOptionPath>> listFamilyOptionPaths(
    String familyId,
  ) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    try {
      final rows = await c
          .from('calculator_family_option_paths')
          .select(
            'id, family_id, parent_attribute_id, option_label, sort_order, '
            'calculator_family_option_path_attributes(attribute_id, sort_order, selected_options), '
            'calculator_family_option_path_questions(id, question_key, label, ui_type, options, source_attribute_id, sort_order, group_id)',
          )
          .eq('family_id', familyId)
          .order('sort_order');
      final out = <CalculatorFamilyOptionPath>[];
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final attrs = <CalculatorFamilyAttributeLink>[];
        final nested = row['calculator_family_option_path_attributes'];
        if (nested is List) {
          for (final a in nested) {
            final m = Map<String, dynamic>.from(a as Map);
            List<String>? selected;
            final so = m['selected_options'];
            if (so is List) {
              selected = so
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
            attrs.add(
              CalculatorFamilyAttributeLink(
                attributeId: m['attribute_id']?.toString() ?? '',
                sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
                selectedOptions: selected,
              ),
            );
          }
          attrs.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }
        final questions = <CalculatorFamilyOptionPathQuestion>[];
        final qNested = row['calculator_family_option_path_questions'];
        if (qNested is List) {
          for (final q in qNested) {
            questions.add(
              CalculatorFamilyOptionPathQuestion.fromRow(
                Map<String, dynamic>.from(q as Map),
              ),
            );
          }
          questions.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }
        // Back-compat: shop attributes without custom questions → treat as questions in UI via attributes.
        out.add(
          CalculatorFamilyOptionPath(
            id: row['id']?.toString(),
            familyId: row['family_id']?.toString() ?? familyId,
            parentAttributeId: row['parent_attribute_id']?.toString() ?? '',
            optionLabel: row['option_label'] as String? ?? '',
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            attributes: attrs,
            questions: questions,
          ),
        );
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Replace all option quotation paths for a family.
  Future<void> setFamilyOptionPaths({
    required String familyId,
    required List<CalculatorFamilyOptionPath> paths,
    Map<String, String> questionKeyRenames = const {},
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) {
      throw StateError('Supabase session unavailable — sign in again and retry.');
    }
    await c
        .from('calculator_family_option_paths')
        .delete()
        .eq('family_id', familyId);
    for (var i = 0; i < paths.length; i++) {
      final p = paths[i];
      if (p.optionLabel.trim().isEmpty) continue;
      final inserted = await c
          .from('calculator_family_option_paths')
          .insert({
            'family_id': familyId,
            'parent_attribute_id': p.parentAttributeId,
            'option_label': p.optionLabel.trim(),
            'sort_order': i,
          })
          .select('id')
          .single();
      final pathId = inserted['id'] as String?;
      if (pathId == null) continue;
      if (p.attributes.isNotEmpty) {
        await c.from('calculator_family_option_path_attributes').insert([
          for (var j = 0; j < p.attributes.length; j++)
            {
              'path_id': pathId,
              'attribute_id': p.attributes[j].attributeId,
              'selected_options': p.attributes[j].selectedOptions,
              'sort_order': j,
            },
        ]);
      }
      if (p.questions.isNotEmpty) {
        await c.from('calculator_family_option_path_questions').insert([
          for (var j = 0; j < p.questions.length; j++)
            {
              'path_id': pathId,
              'question_key': p.questions[j].questionKey.trim(),
              'label': p.questions[j].label.trim(),
              'ui_type': p.questions[j].uiType,
              'options': p.questions[j].options,
              'source_attribute_id': p.questions[j].sourceAttributeId,
              'sort_order': j,
              'group_id': p.questions[j].groupId,
            },
        ]);
      }
    }
    await _syncTemplateFollowUpsFromPaths(
      familyId: familyId,
      paths: paths,
      questionKeyRenames: questionKeyRenames,
    );
  }

  /// Keep every family template's follow-up questions identical to Options &
  /// questions (path questions): insert / update / delete as needed.
  Future<void> _syncTemplateFollowUpsFromPaths({
    required String familyId,
    required List<CalculatorFamilyOptionPath> paths,
    Map<String, String> questionKeyRenames = const {},
  }) async {
    final byKey = <String, ({CalculatorFamilyOptionPathQuestion q, int sort})>{};
    var sort = 500;
    for (final p in paths) {
      for (final q in p.questions) {
        final key = q.questionKey.trim();
        if (key.isEmpty) continue;
        // First occurrence wins (stable); later options may repeat same key.
        byKey.putIfAbsent(key, () {
          final entry = (q: q, sort: sort);
          sort += 1;
          return entry;
        });
      }
    }
    final liveKeys = byKey.keys.toSet();

    final templates =
        await listTemplates(familyId: familyId, publishedOnly: false);
    for (final t in templates) {
      final existing = await listQuestions(t.id);
      final followUps = [
        for (final q in existing)
          if (!q.defaultVisibility) q,
      ];
      final byExistingKey = {
        for (final q in followUps) q.questionKey: q,
      };

      // Prefer renaming in place when question_key changed in Options.
      for (final e in questionKeyRenames.entries) {
        final oldKey = e.key.trim();
        final newKey = e.value.trim();
        if (oldKey.isEmpty || newKey.isEmpty || oldKey == newKey) continue;
        final prev = byExistingKey[oldKey];
        final live = byKey[newKey];
        if (prev == null || live == null) continue;
        if (byExistingKey.containsKey(newKey) &&
            byExistingKey[newKey]!.id != prev.id) {
          // New key already exists — drop the old row.
          await deleteQuestion(prev.id);
          byExistingKey.remove(oldKey);
          continue;
        }
        final label =
            live.q.label.trim().isEmpty ? newKey : live.q.label.trim();
        await updateQuestion(
          id: prev.id,
          questionKey: newKey,
          label: label,
          uiType: live.q.uiType,
          options: live.q.options,
          sortOrder: live.sort,
          defaultVisibility: false,
        );
        byExistingKey.remove(oldKey);
        byExistingKey[newKey] = CalculatorQuestion(
          id: prev.id,
          templateId: t.id,
          questionKey: newKey,
          label: label,
          uiType: live.q.uiType,
          options: live.q.options,
          sortOrder: live.sort,
          defaultVisibility: false,
        );
      }

      for (final e in byKey.entries) {
        final key = e.key;
        final live = e.value.q;
        final label = live.label.trim().isEmpty ? key : live.label.trim();
        final prev = byExistingKey[key];
        if (prev != null) {
          final optsChanged = !_sameOptions(prev.options, live.options);
          if (prev.label != label ||
              prev.uiType != live.uiType ||
              optsChanged ||
              prev.sortOrder != e.value.sort) {
            await updateQuestion(
              id: prev.id,
              questionKey: key,
              label: label,
              uiType: live.uiType,
              options: live.options,
              sortOrder: e.value.sort,
              defaultVisibility: false,
            );
          }
        } else {
          await createQuestion(
            templateId: t.id,
            questionKey: key,
            label: label,
            uiType: live.uiType,
            options: live.options,
            sortOrder: e.value.sort,
            defaultVisibility: false,
          );
        }
      }

      final after = await listQuestions(t.id);
      for (final q in after) {
        if (!q.defaultVisibility && !liveKeys.contains(q.questionKey)) {
          await deleteQuestion(q.id);
        }
      }

      if (questionKeyRenames.isNotEmpty) {
        await _remapRuleQuestionKeys(
          templateId: t.id,
          renames: questionKeyRenames,
        );
      }
    }
  }

  Future<void> _remapRuleQuestionKeys({
    required String templateId,
    required Map<String, String> renames,
  }) async {
    if (renames.isEmpty) return;
    final rules = await listRules(templateId);
    for (final rule in rules) {
      final action = Map<String, dynamic>.from(rule.action);
      final condition = Map<String, dynamic>.from(rule.condition);
      final actionChanged = _rewriteQuestionKeysInJson(action, renames);
      final condChanged = _rewriteQuestionKeysInJson(condition, renames);
      if (!actionChanged && !condChanged) continue;
      await updateRule(
        id: rule.id,
        ruleType: rule.ruleType,
        name: rule.name ?? '',
        priority: rule.priority,
        condition: condition,
        action: action,
        isActive: rule.isActive,
        optionScopeFamilyId: rule.optionScopeFamilyId,
        optionScopeAttributeId: rule.optionScopeAttributeId,
        optionScopeLabel: rule.optionScopeLabel,
        ruleGroupId: rule.ruleGroupId,
      );
    }
  }

  /// Returns true if any value was rewritten.
  static bool _rewriteQuestionKeysInJson(
    Map<String, dynamic> json,
    Map<String, String> renames,
  ) {
    var changed = false;
    void walk(dynamic node) {
      if (node is Map) {
        for (final e in node.entries.toList()) {
          final k = e.key.toString();
          final v = e.value;
          if (v is String) {
            final mapped = renames[v];
            if (mapped != null && mapped != v) {
              node[k] = mapped;
              changed = true;
            } else if ((k == 'qty_formula' || k == 'expression') &&
                v.isNotEmpty) {
              var next = v;
              for (final r in renames.entries) {
                if (r.key.isEmpty || r.key == r.value) continue;
                if (next.contains(r.key)) {
                  next = next.replaceAll(r.key, r.value);
                }
              }
              if (next != v) {
                node[k] = next;
                changed = true;
              }
            }
          } else {
            walk(v);
          }
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(json);
    return changed;
  }

  static bool _sameOptions(List<String>? a, List<String>? b) {
    final aa = a ?? const <String>[];
    final bb = b ?? const <String>[];
    if (aa.length != bb.length) return false;
    for (var i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) return false;
    }
    return true;
  }

  /// Template questions + family Shop attributes (family wins on same key).
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
    return mergeFamilyAndTemplateQuestions(familyQs, templateQs);
  }

  static List<CalculatorQuestion> mergeFamilyAndTemplateQuestions(
    List<CalculatorQuestion> familyQs,
    List<CalculatorQuestion> templateQs,
  ) {
    final familyKeys = familyQs.map((q) => q.questionKey).toSet();
    // Family option-path follow-ups are the source of truth. Skip stale
    // template copies left behind after a rename/delete (old sync).
    final familyHasPathFollowUps = familyQs.any(
      (q) => (q.showWhenKey ?? '').trim().isNotEmpty,
    );
    final out = [...familyQs];
    for (final q in templateQs) {
      if (familyKeys.contains(q.questionKey)) continue;
      if (familyHasPathFollowUps && !q.defaultVisibility) continue;
      out.add(q.copyWith(sortOrder: 1000 + q.sortOrder));
    }
    return out;
  }

  static List<CalculatorQuestion> questionsFromFamilyAttributeRows(
    List rows,
    String templateId,
  ) {
    final out = <CalculatorQuestion>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final am = row['attribute_master'];
      if (am is! Map) continue;
      final master = Map<String, dynamic>.from(am);
      final key = (master['key'] as String?)?.trim() ?? '';
      if (key.isEmpty) continue;
      final label = (master['label'] as String?)?.trim().isNotEmpty == true
          ? (master['label'] as String).trim()
          : key;
      final dataType = master['data_type'] as String? ?? 'text';
      final shopOpts = _effectiveOptionsFromMaster(master);
      final opts = _resolveSelectedOptions(row['selected_options'], shopOpts);
      final mode = row['question_mode'] as String? ?? CalculatorFamilyQuestionMode.select;
      final baseSort = (row['sort_order'] as num?)?.toInt() ?? out.length;
      final attrId = master['id']?.toString() ?? key;
      String? groupId = row['group_id']?.toString();
      String? groupName;
      var groupSort = 0;
      final g = row['calculator_question_groups'];
      if (g is Map) {
        groupId = g['id']?.toString() ?? groupId;
        groupName = (g['name'] as String?)?.trim();
        groupSort = (g['sort_order'] as num?)?.toInt() ?? 0;
      }

      if (mode == CalculatorFamilyQuestionMode.perOption && opts.isNotEmpty) {
        for (var i = 0; i < opts.length; i++) {
          final opt = opts[i];
          final optKey = '${key}__${SupabaseRepositoryBase.slugify(opt)}';
          out.add(
            CalculatorQuestion(
              id: 'family-attr-$attrId-$optKey',
              templateId: templateId,
              questionKey: optKey,
              label: opt,
              uiType: 'number',
              options: null,
              sortOrder: baseSort * 100 + i,
              defaultVisibility: true,
              groupId: groupId,
              groupName: groupName,
              groupSortOrder: groupSort,
            ),
          );
        }
        continue;
      }

      final uiType = opts.isNotEmpty
          ? 'select'
          : switch (dataType) {
              'number' => 'number',
              'bool' => 'bool',
              'select' || 'multi_select' => 'select',
              _ => 'text',
            };
      out.add(
        CalculatorQuestion(
          id: 'family-attr-$attrId',
          templateId: templateId,
          questionKey: key,
          label: label,
          uiType: uiType,
          options: opts.isEmpty ? null : opts,
          sortOrder: baseSort,
          defaultVisibility: true,
          groupId: groupId,
          groupName: groupName,
          groupSortOrder: groupSort,
        ),
      );
    }
    return out;
  }

  /// Admin subset wins; keep Shop order for still-valid labels.
  /// Null selected_options = all shop options; empty list = none.
  static List<String> _resolveSelectedOptions(
    dynamic selectedRaw,
    List<String> shopOpts,
  ) {
    if (selectedRaw is! List) return shopOpts;
    if (selectedRaw.isEmpty) return const [];
    final allow = selectedRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (allow.isEmpty) return const [];
    final ordered = shopOpts.where(allow.contains).toList();
    if (ordered.isNotEmpty) return ordered;
    return allow.toList();
  }

  static List<String> _effectiveOptionsFromMaster(Map<String, dynamic> master) {
    final nested = master['attribute_options'];
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
    if (fromTable.isNotEmpty) return fromTable.map((e) => e.label).toList();
    final av = master['allowed_values'];
    if (av is List) {
      return av.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  /// Hard delete — cascades to templates / questions / rules for this family.
  Future<void> deleteFamily(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_families').delete().eq('id', id);
  }

  Future<List<CalculatorTemplate>> listTemplates({
    String? familyId,
    bool publishedOnly = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    var q = c.from('calculator_templates').select();
    if (familyId != null) q = q.eq('family_id', familyId);
    if (publishedOnly) q = q.eq('is_published', true).eq('is_active', true);
    final rows = await q.order('name');
    return (rows as List)
        .map(
          (e) => CalculatorTemplate.fromRow(SupabaseRepositoryBase.rowToMap(e)),
        )
        .toList();
  }

  Future<String?> createTemplate({
    required String familyId,
    required String name,
    bool isPublished = false,
    int version = 1,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('calculator_templates')
        .insert({
          'family_id': familyId,
          'name': name.trim(),
          'slug': SupabaseRepositoryBase.slugify(name),
          'version': version,
          'is_published': isPublished,
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> updateTemplate({
    required String id,
    required String name,
    int version = 1,
    bool isPublished = false,
    bool isActive = true,
    bool updateSlug = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final payload = <String, dynamic>{
      'name': name.trim(),
      'version': version < 1 ? 1 : version,
      'is_published': isPublished,
      'is_active': isActive,
    };
    if (updateSlug) {
      payload['slug'] = SupabaseRepositoryBase.slugify(name);
    }
    await c.from('calculator_templates').update(payload).eq('id', id);
  }

  /// Hard delete — cascades questions + rules for this template.
  Future<void> deleteTemplate(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_templates').delete().eq('id', id);
  }

  Future<void> setTemplatePublished(String id, bool published) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c
        .from('calculator_templates')
        .update({'is_published': published})
        .eq('id', id);
  }

  Future<List<CalculatorQuestion>> listQuestions(String templateId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('calculator_questions')
        .select()
        .eq('template_id', templateId)
        .order('sort_order');
    final questions = (rows as List)
        .map(
          (e) => CalculatorQuestion.fromRow(SupabaseRepositoryBase.rowToMap(e)),
        )
        .toList();
    final shopOptions = await _shopAttributeOptionsByKey();
    return CalculatorQuestion.enrichWithShopOptions(questions, shopOptions);
  }

  /// Live options from Attribute Master (use_in_calculator) keyed by attribute key.
  Future<Map<String, List<String>>> _shopAttributeOptionsByKey() async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return const {};
    try {
      final rows = await c
          .from('attribute_master')
          .select(
            'key, data_type, allowed_values, attribute_options(label, sort_order, is_active)',
          )
          .eq('use_in_calculator', true)
          .eq('is_active', true);
      return _parseAttributeOptionsByKey(rows as List);
    } catch (_) {
      return const {};
    }
  }

  static Map<String, List<String>> _parseAttributeOptionsByKey(List rows) {
    final out = <String, List<String>>{};
    for (final raw in rows) {
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
          labels = av.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        }
      }
      if (labels.isNotEmpty) out[key] = labels;
    }
    return out;
  }

  Future<void> createQuestion({
    required String templateId,
    required String questionKey,
    required String label,
    String uiType = 'number',
    List<String>? options,
    int sortOrder = 0,
    bool defaultVisibility = true,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_questions').insert({
      'template_id': templateId,
      'question_key': questionKey,
      'label': label,
      'ui_type': uiType,
      'options': options,
      'sort_order': sortOrder,
      'default_visibility': defaultVisibility,
    });
  }

  Future<void> updateQuestion({
    required String id,
    required String questionKey,
    required String label,
    String uiType = 'number',
    List<String>? options,
    int sortOrder = 0,
    bool defaultVisibility = true,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_questions').update({
      'question_key': questionKey.trim(),
      'label': label.trim(),
      'ui_type': uiType,
      'options': options,
      'sort_order': sortOrder,
      'default_visibility': defaultVisibility,
    }).eq('id', id);
  }

  Future<void> deleteQuestion(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_questions').delete().eq('id', id);
  }

  Future<List<CalculatorRule>> listRules(String templateId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('calculator_rules')
        .select('*, calculator_rule_groups(id, name, sort_order)')
        .eq('template_id', templateId)
        .order('priority');
    return (rows as List)
        .map((e) => CalculatorRule.fromRow(SupabaseRepositoryBase.rowToMap(e)))
        .toList();
  }

  Future<void> createRule({
    required String templateId,
    required String ruleType,
    required String name,
    int priority = 100,
    Map<String, dynamic>? condition,
    Map<String, dynamic>? action,
    bool isActive = true,
    String? optionScopeFamilyId,
    String? optionScopeAttributeId,
    String? optionScopeLabel,
    String? ruleGroupId,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final row = <String, dynamic>{
      'template_id': templateId,
      'rule_type': ruleType,
      'name': name,
      'priority': priority,
      'condition': condition ?? {},
      'action': action ?? {},
      'is_active': isActive,
      'rule_group_id': (ruleGroupId ?? '').isEmpty ? null : ruleGroupId,
    };
    if (optionScopeFamilyId != null &&
        optionScopeAttributeId != null &&
        optionScopeLabel != null) {
      row['option_scope_family_id'] = optionScopeFamilyId;
      row['option_scope_attribute_id'] = optionScopeAttributeId;
      row['option_scope_label'] = optionScopeLabel;
    }
    await c.from('calculator_rules').insert(row);
  }

  Future<void> updateRule({
    required String id,
    required String ruleType,
    required String name,
    int priority = 100,
    Map<String, dynamic>? condition,
    Map<String, dynamic>? action,
    bool isActive = true,
    String? optionScopeFamilyId,
    String? optionScopeAttributeId,
    String? optionScopeLabel,
    String? ruleGroupId,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_rules').update({
      'rule_type': ruleType,
      'name': name.trim(),
      'priority': priority,
      'condition': condition ?? {},
      'action': action ?? {},
      'is_active': isActive,
      'option_scope_family_id': optionScopeFamilyId,
      'option_scope_attribute_id': optionScopeAttributeId,
      'option_scope_label': optionScopeLabel,
      'rule_group_id': (ruleGroupId ?? '').isEmpty ? null : ruleGroupId,
    }).eq('id', id);
  }

  Future<List<CalculatorRuleGroup>> listRuleGroupsForOptionScope({
    required String familyId,
    required String attributeId,
    required String optionLabel,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    try {
      final rows = await c
          .from('calculator_rule_groups')
          .select()
          .eq('family_id', familyId)
          .eq('option_scope_attribute_id', attributeId)
          .eq('option_scope_label', optionLabel)
          .order('sort_order');
      return [
        for (final r in rows as List)
          CalculatorRuleGroup.fromRow(SupabaseRepositoryBase.rowToMap(r)),
      ].where((g) => g.id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> createRuleGroup({
    required String familyId,
    required String name,
    String? optionScopeAttributeId,
    String? optionScopeLabel,
    int sortOrder = 0,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c
        .from('calculator_rule_groups')
        .insert({
          'family_id': familyId,
          'name': name.trim(),
          'option_scope_attribute_id': optionScopeAttributeId,
          'option_scope_label': optionScopeLabel,
          'sort_order': sortOrder,
        })
        .select('id')
        .single();
    return row['id'] as String?;
  }

  Future<void> updateRuleGroup({
    required String id,
    required String name,
    int? sortOrder,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_rule_groups').update({
      'name': name.trim(),
      if (sortOrder != null) 'sort_order': sortOrder,
    }).eq('id', id);
  }

  Future<void> deleteRuleGroup(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_rule_groups').delete().eq('id', id);
  }

  Future<List<CalculatorRule>> listRulesForOptionScope({
    required String familyId,
    required String attributeId,
    required String optionLabel,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('calculator_rules')
        .select('*, calculator_rule_groups(id, name, sort_order)')
        .eq('option_scope_family_id', familyId)
        .eq('option_scope_attribute_id', attributeId)
        .eq('option_scope_label', optionLabel)
        .order('priority');
    return (rows as List)
        .map((e) => CalculatorRule.fromRow(SupabaseRepositoryBase.rowToMap(e)))
        .toList();
  }

  /// Ensures a template exists for the family; returns template id.
  Future<String?> ensureTemplateForFamily(String familyId) async {
    final templates = await listTemplates(familyId: familyId, publishedOnly: false);
    if (templates.isNotEmpty) return templates.first.id;
    final families = await listFamilies(activeOnly: false);
    final family = families.where((f) => f.id == familyId).firstOrNull;
    final name = family?.name ?? 'Calculator';
    final id = await createTemplate(
      familyId: familyId,
      name: '$name Standard',
      isPublished: true,
    );
    return id;
  }

  Future<void> deleteRule(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_rules').delete().eq('id', id);
  }

  Future<void> linkRuleProduct({
    required String ruleId,
    required String productId,
    int defaultQty = 1,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('calculator_rule_products').upsert({
      'rule_id': ruleId,
      'product_id': productId,
      'default_qty': defaultQty,
    });
  }

  Future<String?> createSession({
    required String templateId,
    required Map<String, dynamic> answers,
    Map<String, dynamic>? result,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('calculator_sessions')
        .insert({
          'firebase_uid': uid,
          'template_id': templateId,
          'answers': answers,
          'result': ?result,
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }
}

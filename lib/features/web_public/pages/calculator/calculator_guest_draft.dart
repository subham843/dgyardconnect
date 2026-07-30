import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guest calculator answers + product picks — survives "See price" → login.
class CalculatorGuestDraft {
  const CalculatorGuestDraft({
    required this.familySlug,
    required this.answers,
    required this.productOverrides,
    required this.savedAtMs,
  });

  final String familySlug;
  final Map<String, dynamic> answers;
  final Map<String, String> productOverrides;
  final int savedAtMs;

  Map<String, dynamic> toJson() => {
        'familySlug': familySlug,
        'answers': answers,
        'productOverrides': productOverrides,
        'savedAtMs': savedAtMs,
      };

  static CalculatorGuestDraft? fromJson(Map<String, dynamic> json) {
    final slug = (json['familySlug'] as String?)?.trim() ?? '';
    if (slug.isEmpty) return null;
    final rawAnswers = json['answers'];
    final answers = <String, dynamic>{};
    if (rawAnswers is Map) {
      rawAnswers.forEach((k, v) {
        if (k is String && k.isNotEmpty) answers[k] = v;
      });
    }
    final rawOverrides = json['productOverrides'];
    final overrides = <String, String>{};
    if (rawOverrides is Map) {
      rawOverrides.forEach((k, v) {
        if (k is String && k.isNotEmpty && v != null) {
          final id = v.toString().trim();
          if (id.isNotEmpty) overrides[k] = id;
        }
      });
    }
    final savedAtMs = (json['savedAtMs'] as num?)?.toInt() ?? 0;
    return CalculatorGuestDraft(
      familySlug: slug,
      answers: answers,
      productOverrides: overrides,
      savedAtMs: savedAtMs,
    );
  }
}

abstract final class CalculatorDraftStore {
  static const _key = 'dgyard_calculator_guest_draft_v1';
  static const _maxAge = Duration(hours: 12);

  static Future<void> save({
    required String familySlug,
    required Map<String, dynamic> answers,
    required Map<String, String> productOverrides,
  }) async {
    final slug = familySlug.trim();
    if (slug.isEmpty) return;
    final hasAnswers = answers.values.any((v) {
      if (v == null) return false;
      if (v is num) return v != 0;
      return v.toString().trim().isNotEmpty;
    });
    if (!hasAnswers && productOverrides.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = CalculatorGuestDraft(
        familySlug: slug,
        answers: Map<String, dynamic>.from(answers),
        productOverrides: Map<String, String>.from(productOverrides),
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString(_key, jsonEncode(draft.toJson()));
    } catch (_) {
      // Best-effort — login still works without draft.
    }
  }

  static Future<CalculatorGuestDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final draft = CalculatorGuestDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (draft == null) return null;
      if (draft.savedAtMs > 0) {
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(draft.savedAtMs),
        );
        if (age > _maxAge) {
          await clear();
          return null;
        }
      }
      return draft;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

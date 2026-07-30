import 'package:flutter/material.dart';

/// App-wide dynamic configuration fetched from Firebase Remote Config.
///
/// - Minor changes (colors/text/flags) should be handled here without app update.
@immutable
class AppRemoteConfig {
  const AppRemoteConfig({
    required this.fetchedAt,
    this.primaryColorHex,
    this.texts = const <String, String>{},
    this.featureFlags = const <String, bool>{},
  });

  final DateTime fetchedAt;
  final String? primaryColorHex;
  final Map<String, String> texts;
  final Map<String, bool> featureFlags;

  Color? get primaryColor => _parseColor(primaryColorHex);

  bool isFeatureEnabled(String key, {bool defaultValue = false}) {
    return featureFlags[key] ?? defaultValue;
  }

  String text(String key, {String fallback = ''}) {
    return texts[key] ?? fallback;
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final h = hex.trim().replaceFirst('#', '');
    if (h.length != 6 && h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v | 0xFF000000);
  }
}


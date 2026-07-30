import 'package:flutter/material.dart';

import '../models/brand_kit_model.dart';

/// Website logo tint modes (SVG / monochrome logos).
enum BrandLogoTintMode {
  original('original', 'Original colors'),
  primary('primary', 'Primary brand'),
  secondary('secondary', 'Secondary brand'),
  accent('accent', 'Accent brand'),
  white('white', 'White'),
  black('black', 'Black'),
  custom('custom', 'Custom color');

  const BrandLogoTintMode(this.id, this.label);
  final String id;
  final String label;

  static BrandLogoTintMode fromId(String? id) {
    return BrandLogoTintMode.values.firstWhere(
      (m) => m.id == id,
      orElse: () => BrandLogoTintMode.original,
    );
  }
}

class BrandLogoTint {
  BrandLogoTint._();

  static bool isSvgUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('.svg') || lower.contains('image%2Fsvg');
  }

  /// Tint for website landscape logo. Null = show original asset colors.
  static Color? resolveTint(BrandKitModel kit, {bool preferWhiteAsset = false}) {
    if (preferWhiteAsset) return null;

    final mode = BrandLogoTintMode.fromId(kit.publicWeb.webLogoTintMode);
    switch (mode) {
      case BrandLogoTintMode.original:
        return null;
      case BrandLogoTintMode.primary:
        return kit.primaryColor ?? const Color(0xFF0D47A1);
      case BrandLogoTintMode.secondary:
        return kit.secondaryColor ?? const Color(0xFF00838F);
      case BrandLogoTintMode.accent:
        return kit.accentColor ?? const Color(0xFFF59E0B);
      case BrandLogoTintMode.white:
        return Colors.white;
      case BrandLogoTintMode.black:
        return const Color(0xFF0F172A);
      case BrandLogoTintMode.custom:
        return _parseHex(kit.publicWeb.webLogoCustomTintHex) ?? kit.accentColor;
    }
  }

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final h = hex.trim().replaceFirst('#', '');
    if (h.length != 6 && h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v | 0xFF000000);
  }
}

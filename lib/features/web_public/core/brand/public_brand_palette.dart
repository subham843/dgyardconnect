import 'package:flutter/material.dart';

import '../../../../shared/models/brand_kit_model.dart';
import '../../v2/v2_colors.dart';

/// Dynamic color palette generated from Admin Brand Kit.
class PublicBrandPalette {
  const PublicBrandPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.primaryDark,
    required this.primaryLight,
    required this.accentLight,
    required this.accentDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.footerBackground,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color primaryDark;
  final Color primaryLight;
  final Color accentLight;
  final Color accentDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color footerBackground;

  static PublicBrandPalette fromKit(BrandKitModel kit) {
    final primary = kit.primaryColor ?? V2Colors.plasma;
    final secondary = kit.secondaryColor ?? V2Colors.navy;
    final accent = kit.accentColor ?? V2Colors.ember;
    final darkBg =
        _parseHex(kit.publicWeb.darkBackgroundColorHex) ?? V2Colors.ink;
    final lightBg =
        _parseHex(kit.publicWeb.lightBackgroundColorHex) ?? V2Colors.paper;

    return PublicBrandPalette(
      primary: primary,
      secondary: secondary,
      accent: accent,
      primaryDark: darkBg,
      primaryLight: _lighten(primary, 0.12),
      accentLight: _lighten(accent, 0.08),
      accentDark: _darken(accent, 0.08),
      surface: lightBg,
      textPrimary: V2Colors.ink,
      textSecondary: V2Colors.fgMuted,
      footerBackground: V2Colors.ink,
    );
  }

  LinearGradient get primaryGradient => LinearGradient(
        colors: [primaryDark, primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get brandGradient => LinearGradient(
        colors: [accent, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final h = hex.replaceFirst('#', '').trim();
    if (h.length != 6 && h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v | 0xFF000000);
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

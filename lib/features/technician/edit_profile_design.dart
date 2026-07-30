import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_ui_tokens.dart';

/// Premium Apple-level design tokens for Edit Profile flow.
abstract final class EditProfileDesign {
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;

  static const Color surfaceBg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static Color get textHeadline => TechnicianUiTokens.labelPrimary;
  static const Color textBody = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color glassWhite = Color(0xE6FFFFFF);
  static const Color shadowSoft = Color(0x0A000000);
  static const Color shadowMedium = Color(0x12000000);

  static BoxDecoration glassCard({
    double borderRadius = radiusLg,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: glassWhite,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: shadowSoft,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: shadowMedium,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
      );

  static BoxDecoration floatingCard({
    double borderRadius = radiusLg,
  }) =>
      BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowSoft,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: shadowMedium,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? counterText,
  }) =>
      InputDecoration(
        labelText: label,
        counterText: counterText ?? '',
        prefixIcon: Icon(icon, size: 22, color: textMuted),
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: AppColors.googleGreyBorder.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      );
}

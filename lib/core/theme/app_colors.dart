import 'package:flutter/material.dart';

/// Production-ready color palette for DG Yard Connect.
/// Clean, professional, accessible contrast.
abstract final class AppColors {
  // Global premium soft-glass gradient system.
  static const Color primary = Color(0xFF5A7BFF);
  static const Color primaryLight = Color(0xFF6EC6FF);
  static const Color primaryDark = Color(0xFF3E63F0);
  /// Accent for limited highlights (warm orange, matches dealer bottom nav family).
  static const Color accent = Color(0xFFFB923C);

  /// Warm orange family — same as dealer bottom nav selected + hover (`_dealerAccentOrange` / splash).
  /// Use instead of legacy “saffron” yellow-oranges app-wide.
  static const Color brandWarm = Color(0xFFEA580C);
  static const Color brandWarmLight = Color(0xFFF97316);
  static const Color brandWarmSoft = Color(0xFFFB923C);
  static const Color brandWarmDark = Color(0xFFC2410C);
  static const Color brandWarmBg = Color(0xFFFFF7ED);
  static const Color brandWarmBgMuted = Color(0xFFFFEDD5);
  static const Color brandWarmSurfaceTop = Color(0xFFFFFBF7);
  static const Color brandWarmBorder = Color(0x4DF97316);

  // Secondary / accent
  static const Color secondary = Color(0xFF00838F);
  static const Color secondaryLight = Color(0xFF4FB3BF);
  static const Color secondaryDark = Color(0xFF005662);

  // Surface & background
  static const Color surface = Color(0xFFF4F7FF);
  static const Color surfaceVariant = Color(0xFFEAF2FF);
  static const Color background = Color(0xFFEEF2FF);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF60AD5E);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFF6659);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // Level badges (technician: Bronze, Silver, Gold, Elite)
  static const Color bronze = Color(0xFF8D6E63);
  static const Color silver = Color(0xFF9E9E9E);
  static const Color gold = Color(0xFFF9A825);
  static const Color platinum = Color(0xFFE0E0E0); // legacy
  static const Color elite = Color(0xFFB8860B); // dark goldenrod for Elite

  // Dealer levels
  static const Color basic = Color(0xFF757575);
  static const Color trusted = Color(0xFF00838F);
  static const Color premium = Color(0xFF0D47A1);
  static const Color enterprise = Color(0xFF002171);

  // Google-style (auth / location flow)
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleBlueHover = Color(0xFF3367D6);
  static const Color googleGreyBg = Color(0xFFF8F9FA);
  static const Color googleGreyBorder = Color(0xFFDADCE0);
  static const Color googleTextSecondary = Color(0xFF5F6368);
  static const Color googleCardBg = Color(0xFFFFFFFF);
}

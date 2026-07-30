import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Light, Apple-inspired design tokens for the technician module only.
abstract final class TechnicianUiTokens {
  TechnicianUiTokens._();

  // —— Canvas & surfaces ——
  static const Color canvas = Color(0xFFF5F7FA);
  static const Color canvasElevated = Color(0xFFFFFFFF);

  // —— Text ——
  static const Color labelPrimary = Color(0xFF0A0F1A);
  static const Color labelSecondary = Color(0xFF4A5563);
  static const Color labelTertiary = Color(0xFF6E7A89);

  // —— Primary accent (aligned with dealer brand blue) ——
  static const Color accent = AppColors.primary;
  static const Color accentSoft = Color(0x291D4ED8);

  // —— Semantic (status only) ——
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);

  // —— Hairlines & fills ——
  static const Color separator = Color(0x26000000);
  static const Color hairlineOnGlass = Color(0x8AFFFFFF);
  static const Color fillQuaternary = Color(0x0F000000);

  // —— Background gradient stops (glass reads better on layered tones) ——
  static const Color bgBlobA = Color(0x66C7E5FF);
  static const Color bgBlobB = Color(0x4DE8F0FF);
  static const Color bgBlobC = Color(0x33F0F4FF);

  // Legacy names used by existing glass kit (map to new palette)
  static const Color textPrimary = labelPrimary;
  static const Color textSecondary = labelSecondary;
  static const Color glassTintTop = Color(0xEEF3F8FF);
  static const Color glassTintMid = Color(0xE5EDF5FF);
  static const Color glassTintBottom = Color(0xDDE8F2FF);

  /// Frosted panel fill (semi-transparent white)
  static const Color glassSurface = Color(0x7DFFFFFF);
  static const Color glassSurfaceStrong = Color(0x94FFFFFF);

  /// App bar frosted strip (high opacity so titles/icons stay readable)
  static const Color appBarGlassTop = Color(0xF2FFFFFF);
  static const Color appBarGlassBottom = Color(0xE8FFFFFF);
  static const Color glassBorder = Color(0x99FFFFFF);
  static const Color glassBorderSoft = Color(0x55FFFFFF);

  static const double blurHeavy = 28;
  static const double blurMedium = 20;

  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 22;
  static const double rXl = 28;
  static const double rPill = 999;

  // —— Shadows (soft, diffuse) ——
  static List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 26,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.035),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowFloat = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
  ];

  // —— Motion ——
  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionMedium = Duration(milliseconds: 320);
  static const Curve motionCurve = Curves.easeOutCubic;

  static TextStyle textLargeTitle({Color? color}) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.15,
        color: color ?? labelPrimary,
      );

  static TextStyle textTitle1({Color? color}) => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: color ?? labelPrimary,
      );

  static TextStyle textTitle2({Color? color}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color ?? labelPrimary,
      );

  static TextStyle textHeadline({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color ?? labelPrimary,
      );

  static TextStyle textSubhead({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? labelSecondary,
      );

  static TextStyle textCaption1({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color ?? labelSecondary,
      );

  static TextStyle textCaption2({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color ?? labelTertiary,
      );
}

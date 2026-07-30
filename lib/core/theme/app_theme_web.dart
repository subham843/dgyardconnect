import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/models/brand_kit_model.dart';
import 'app_colors.dart';

/// Lightweight web theme — system fonts only (no GoogleFonts package at startup).
class AppTheme {
  AppTheme._();

  static ThemeData light([BrandKitModel? brandKit]) {
    final primary = brandKit?.primaryColor ?? AppColors.primary;
    final secondary = brandKit?.secondaryColor ?? AppColors.secondary;
    const fontFamily = 'system-ui';
    final textTheme = ThemeData.light().textTheme.apply(
          fontFamily: fontFamily,
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: const ['system-ui', 'Segoe UI', 'sans-serif'],
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: primary.withValues(alpha: 0.14),
        secondary: secondary,
        onSecondary: AppColors.textOnSecondary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
        outline: Colors.grey.shade300,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

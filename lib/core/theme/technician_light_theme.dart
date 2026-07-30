import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'technician_ui_tokens.dart';

/// Overrides parent theme so technician shortcut flows stay strictly light
/// (surfaces, text, cards, sheets) with no dark Material defaults.
abstract final class TechnicianLightTheme {
  static ThemeData overlay(BuildContext context) {
    final base = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: TechnicianUiTokens.accent,
      brightness: Brightness.light,
    );
    final lightText = GoogleFonts.interTextTheme(
      ThemeData(useMaterial3: true, brightness: Brightness.light).textTheme,
    );
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: TechnicianUiTokens.canvas,
      splashColor: TechnicianUiTokens.accent.withValues(alpha: 0.08),
      highlightColor: TechnicianUiTokens.accent.withValues(alpha: 0.05),
      colorScheme: scheme.copyWith(
        surface: TechnicianUiTokens.canvasElevated,
        onSurface: TechnicianUiTokens.labelPrimary,
        onSurfaceVariant: TechnicianUiTokens.labelSecondary,
        outline: TechnicianUiTokens.separator,
        primary: TechnicianUiTokens.accent,
        onPrimary: Colors.white,
        secondary: TechnicianUiTokens.accent,
        onSecondary: Colors.white,
      ),
      textTheme: lightText.apply(
        bodyColor: TechnicianUiTokens.labelPrimary,
        displayColor: TechnicianUiTokens.labelPrimary,
      ),
      primaryTextTheme: lightText.apply(
        bodyColor: TechnicianUiTokens.labelPrimary,
        displayColor: TechnicianUiTokens.labelPrimary,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TechnicianUiTokens.rLg),
          side: BorderSide(color: TechnicianUiTokens.hairlineOnGlass),
        ),
      ),
      dividerTheme: DividerThemeData(color: TechnicianUiTokens.separator),
      listTileTheme: ListTileThemeData(
        iconColor: TechnicianUiTokens.labelPrimary,
        textColor: TechnicianUiTokens.labelPrimary,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.65),
        labelStyle: TextStyle(color: TechnicianUiTokens.labelPrimary, fontSize: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        modalBackgroundColor: Colors.white.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        indicatorColor: TechnicianUiTokens.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? TechnicianUiTokens.accent
                : TechnicianUiTokens.labelTertiary,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        selectedItemColor: TechnicianUiTokens.accent,
        unselectedItemColor: TechnicianUiTokens.labelTertiary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: TechnicianUiTokens.labelPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: TechnicianUiTokens.labelPrimary),
        titleTextStyle: TextStyle(
          color: TechnicianUiTokens.labelPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Wrap a subtree (e.g. whole [Scaffold]) with [TechnicianLightTheme.overlay].
class TechnicianLightScope extends StatelessWidget {
  const TechnicianLightScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TechnicianLightTheme.overlay(context),
      child: child,
    );
  }
}

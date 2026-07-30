import 'package:flutter/material.dart';

import '../../../../shared/widgets/brand_kit_provider.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_text.dart';
import 'public_brand_content.dart';
import 'public_brand_palette.dart';

/// Provides dynamic Brand Kit palette + content to public web widgets.
class PublicBrandScope extends InheritedWidget {
  const PublicBrandScope({
    super.key,
    required this.palette,
    required this.content,
    required super.child,
  });

  final PublicBrandPalette palette;
  final PublicBrandContent content;

  static PublicBrandPalette paletteOf(BuildContext context) {
    final scope = maybeOf(context);
    if (scope != null) return scope.palette;
    return PublicBrandPalette.fromKit(BrandKitProvider.of(context));
  }

  static PublicBrandContent contentOf(BuildContext context) {
    final scope = maybeOf(context);
    if (scope != null) return scope.content;
    return PublicBrandContent.fromKit(BrandKitProvider.of(context));
  }

  static PublicBrandScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PublicBrandScope>();
  }

  @override
  bool updateShouldNotify(PublicBrandScope oldWidget) {
    return palette.primary != oldWidget.palette.primary ||
        content.companyShortName != oldWidget.content.companyShortName ||
        content.heroHeadline != oldWidget.content.heroHeadline ||
        content.heroAccentWord != oldWidget.content.heroAccentWord ||
        content.tagline != oldWidget.content.tagline;
  }
}

ThemeData _brandTheme(PublicBrandPalette palette) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: palette.accent,
      onPrimary: V2Colors.fgInverse,
      secondary: palette.primary,
      onSecondary: V2Colors.fgInverse,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      outline: V2Colors.border,
      error: const Color(0xFFEF4444),
    ),
    scaffoldBackgroundColor: palette.surface,
    textTheme: TextTheme(
      titleMedium: V2Text.bodyEmph(),
      bodyMedium: V2Text.body(),
      labelLarge: V2Text.smallStrong(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: V2Colors.bgSubtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: V2Colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
    ),
  );
}

/// Wraps public pages with Brand Kit theme + scope.
class PublicBrandShell extends StatelessWidget {
  const PublicBrandShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kit = BrandKitProvider.of(context);
    final palette = PublicBrandPalette.fromKit(kit);
    final content = PublicBrandContent.fromKit(kit);

    return PublicBrandScope(
      palette: palette,
      content: content,
      child: Theme(
        data: _brandTheme(palette),
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Animation style for the hero headline accent (last) word.
enum HeroAccentAnimation {
  none,
  popUp,
  bounce,
  slideUp,
  flipY,
  shimmer,
  pulse;

  static HeroAccentAnimation fromId(String? id) {
    return HeroAccentAnimation.values.firstWhere(
      (e) => e.name == id,
      orElse: () => HeroAccentAnimation.popUp,
    );
  }

  String get label => switch (this) {
        HeroAccentAnimation.none => 'None (static)',
        HeroAccentAnimation.popUp => 'Pop up',
        HeroAccentAnimation.bounce => 'Bounce',
        HeroAccentAnimation.slideUp => 'Slide up',
        HeroAccentAnimation.flipY => '3D flip',
        HeroAccentAnimation.shimmer => 'Shimmer glow',
        HeroAccentAnimation.pulse => 'Pulse scale',
      };
}

/// Font family preset for hero accent word.
enum HeroAccentFontFamily {
  inherit,
  display,
  serif,
  rounded,
  mono;

  static HeroAccentFontFamily fromId(String? id) {
    return HeroAccentFontFamily.values.firstWhere(
      (e) => e.name == id,
      orElse: () => HeroAccentFontFamily.inherit,
    );
  }

  String get label => switch (this) {
        HeroAccentFontFamily.inherit => 'Same as headline',
        HeroAccentFontFamily.display => 'Display (Poppins)',
        HeroAccentFontFamily.serif => 'Serif (Merriweather)',
        HeroAccentFontFamily.rounded => 'Rounded (Nunito)',
        HeroAccentFontFamily.mono => 'Mono (Roboto Mono)',
      };
}

enum HeroAccentFontWeight {
  regular,
  bold,
  extraBold,
  black;

  static HeroAccentFontWeight fromId(String? id) {
    return HeroAccentFontWeight.values.firstWhere(
      (e) => e.name == id,
      orElse: () => HeroAccentFontWeight.extraBold,
    );
  }

  FontWeight get fontWeight => switch (this) {
        HeroAccentFontWeight.regular => FontWeight.w400,
        HeroAccentFontWeight.bold => FontWeight.w700,
        HeroAccentFontWeight.extraBold => FontWeight.w800,
        HeroAccentFontWeight.black => FontWeight.w900,
      };

  String get label => switch (this) {
        HeroAccentFontWeight.regular => 'Regular',
        HeroAccentFontWeight.bold => 'Bold',
        HeroAccentFontWeight.extraBold => 'Extra bold',
        HeroAccentFontWeight.black => 'Black',
      };
}

/// Splits hero headline into static prefix + animated accent word.
(String prefix, String accent) splitHeroHeadline({
  required String headline,
  String? accentWord,
}) {
  final trimmed = headline.trim();
  if (trimmed.isEmpty) return ('', '');

  final accent = accentWord?.trim();
  if (accent != null && accent.isNotEmpty) {
    if (trimmed.endsWith(accent)) {
      var prefix = trimmed.substring(0, trimmed.length - accent.length).trimRight();
      if (prefix.isNotEmpty && !prefix.endsWith(' ')) prefix = '$prefix ';
      return (prefix, accent);
    }
    return (trimmed.endsWith(' ') ? trimmed : '$trimmed ', accent);
  }

  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length <= 1) return ('', trimmed);
  final last = parts.removeLast();
  final prefix = parts.isEmpty ? '' : '${parts.join(' ')} ';
  return (prefix, last);
}

Color? parseAccentColorHex(String? hex, {Color? fallback}) {
  if (hex == null || hex.trim().isEmpty) return fallback;
  var value = hex.replaceFirst('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

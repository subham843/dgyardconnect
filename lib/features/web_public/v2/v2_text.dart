// V2 Typography — Aurora type system.
//
// Three fonts working together (premium tech-firm signature):
//   - Bricolage Grotesque : Display + H1/H2 (variable, expressive, very tight tracking)
//   - Inter Tight         : Body, nav, buttons, UI (modern, technical, clean)
//   - Instrument Serif    : Italic accent word inside headlines (editorial magic)
//
// Mobile-first fluid scale via V2Responsive.

import 'package:flutter/material.dart';

import 'v2_colors.dart';
import 'v2_fonts.dart';
import 'v2_tokens.dart';

class V2Text {
  V2Text._();

  // ---------------------------------------------------------------------------
  // FONT FAMILIES (centralised so we can swap globally)
  // ---------------------------------------------------------------------------

  static TextStyle _display({
    required double size,
    required FontWeight weight,
    required double tracking,
    required double lineHeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: V2Fonts.display,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
      letterSpacing: tracking,
      color: color ?? V2Colors.ink,
    );
  }

  static TextStyle _ui({
    required double size,
    FontWeight weight = FontWeight.w400,
    double tracking = 0,
    double lineHeight = 1.5,
    Color? color,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: V2Fonts.ui,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
      letterSpacing: tracking,
      color: color ?? V2Colors.ink,
      decoration: decoration,
    );
  }

  /// Editorial italic — use ONLY on accent words for that Apple/Framer feel.
  static TextStyle accentItalic({required double size, Color? color}) {
    return TextStyle(
      fontFamily: V2Fonts.accent,
      fontSize: size,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.0,
      letterSpacing: -0.5,
      color: color ?? V2Colors.ember,
    );
  }

  // ---------------------------------------------------------------------------
  // SCALE
  // ---------------------------------------------------------------------------

  // Eyebrow (tracked uppercase) — Inter Tight, very small but legible
  static TextStyle eyebrow({Color? color}) => _ui(
        size: 11,
        weight: FontWeight.w600,
        tracking: 1.6,
        lineHeight: 1.3,
        color: color ?? V2Colors.ember,
      );

  // Display (hero)
  static TextStyle display(BuildContext context, {Color? color}) {
    final v = V2Responsive(context);
    final size = v.r<double>(
      xs: 40.0,
      sm: 48.0,
      md: 60.0,
      lg: 72.0,
      xl: 84.0,
      xxl: 96.0,
    );
    return _display(
      size: size,
      weight: FontWeight.w800,
      tracking: -size * 0.035, // very tight, Bricolage looks great this way
      lineHeight: 1.02,
      color: color,
    );
  }

  // H1 (section heros / standalone pages)
  static TextStyle h1(BuildContext context, {Color? color}) {
    final v = V2Responsive(context);
    final size = v.r<double>(
      xs: 32.0,
      sm: 36.0,
      md: 42.0,
      lg: 48.0,
      xl: 54.0,
      xxl: 58.0,
    );
    return _display(
      size: size,
      weight: FontWeight.w700,
      tracking: -size * 0.03,
      lineHeight: 1.08,
      color: color,
    );
  }

  // H2 (section titles)
  static TextStyle h2(BuildContext context, {Color? color}) {
    final v = V2Responsive(context);
    final size = v.r<double>(
      xs: 26.0,
      sm: 30.0,
      md: 34.0,
      lg: 38.0,
      xl: 42.0,
    );
    return _display(
      size: size,
      weight: FontWeight.w700,
      tracking: -size * 0.028,
      lineHeight: 1.1,
      color: color,
    );
  }

  // H3 (card / sub-section titles)
  static TextStyle h3(BuildContext context, {Color? color}) {
    final v = V2Responsive(context);
    final size = v.r<double>(
      xs: 20.0,
      sm: 22.0,
      md: 24.0,
      lg: 26.0,
    );
    return _display(
      size: size,
      weight: FontWeight.w600,
      tracking: -size * 0.02,
      lineHeight: 1.2,
      color: color,
    );
  }

  // Body large (hero lead, section subtitles)
  static TextStyle bodyLg(BuildContext context, {Color? color}) {
    final v = V2Responsive(context);
    final size = v.r<double>(
      xs: 16.0,
      sm: 17.0,
      md: 18.0,
      lg: 19.0,
    );
    return _ui(
      size: size,
      weight: FontWeight.w400,
      lineHeight: 1.55,
      color: color ?? V2Colors.fgMuted,
    );
  }

  // Body
  static TextStyle body({Color? color}) => _ui(
        size: 15,
        lineHeight: 1.55,
        color: color ?? V2Colors.fgMuted,
      );

  static TextStyle bodyEmph({Color? color}) => _ui(
        size: 15,
        weight: FontWeight.w500,
        lineHeight: 1.5,
        color: color ?? V2Colors.ink,
      );

  // Small / captions
  static TextStyle small({Color? color}) => _ui(
        size: 13,
        lineHeight: 1.45,
        color: color ?? V2Colors.fgSubtle,
      );

  static TextStyle smallStrong({Color? color}) => _ui(
        size: 13,
        weight: FontWeight.w600,
        lineHeight: 1.4,
        color: color ?? V2Colors.ink,
      );

  static TextStyle micro({Color? color}) => _ui(
        size: 11,
        weight: FontWeight.w500,
        tracking: 0.4,
        lineHeight: 1.4,
        color: color ?? V2Colors.fgSubtle,
      );

  // Buttons
  static TextStyle btn({double size = 15, Color? color}) => _ui(
        size: size,
        weight: FontWeight.w600,
        tracking: -0.1,
        lineHeight: 1,
        color: color ?? V2Colors.fgInverse,
      );

  // Nav links
  static TextStyle navLink({Color? color}) => _ui(
        size: 14,
        weight: FontWeight.w500,
        lineHeight: 1,
        color: color ?? V2Colors.ink,
      );

  // Price
  static TextStyle price(BuildContext context, {Color? color}) {
    final v = V2Responsive(context);
    final size = v.r<double>(xs: 18.0, md: 20.0);
    return _ui(
      size: size,
      weight: FontWeight.w700,
      tracking: -0.4,
      lineHeight: 1.1,
      color: color ?? V2Colors.ink,
    );
  }

  static TextStyle strike({Color? color}) => _ui(
        size: 13,
        lineHeight: 1.2,
        decoration: TextDecoration.lineThrough,
        color: color ?? V2Colors.fgSubtle,
      );
}

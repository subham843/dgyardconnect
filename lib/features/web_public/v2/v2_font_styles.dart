import 'package:flutter/material.dart';

import 'v2_fonts.dart';

/// CSS-loaded web fonts (see `web/index.html`) — no runtime TTF downloads.
abstract final class V2FontStyles {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    Color? decorationColor,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: V2Fonts.ui,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
      fontStyle: fontStyle,
    );
  }

  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: V2Fonts.display,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle accentItalic({
    double? fontSize,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: V2Fonts.accent,
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }
}

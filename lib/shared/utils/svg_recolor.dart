import 'package:flutter/material.dart';

/// Rewrites SVG fill/stroke attributes so brand tint applies to exported logos.
class SvgRecolor {
  SvgRecolor._();

  static String? apply(String svg, Color color) {
    if (svg.trim().isEmpty) return null;

    final hex = _toHex(color);
    var out = svg;

    // fill="..." except none/transparent
    out = out.replaceAllMapped(
      RegExp(r'''fill\s*=\s*"(?!none|transparent)([^"]*)"''', caseSensitive: false),
      (_) => 'fill="$hex"',
    );
    out = out.replaceAllMapped(
      RegExp(r"""fill\s*=\s*'(?!none|transparent)([^']*)'""", caseSensitive: false),
      (_) => "fill='$hex'",
    );

    // stroke="..."
    out = out.replaceAllMapped(
      RegExp(r'''stroke\s*=\s*"(?!none|transparent)([^"]*)"''', caseSensitive: false),
      (_) => 'stroke="$hex"',
    );

    // style="...fill: #xxx..."
    out = out.replaceAllMapped(
      RegExp(
        r'fill\s*:\s*(#[0-9a-fA-F]{3,8}|rgb\([^)]+\)|rgba\([^)]+\)|[a-zA-Z]+)',
        caseSensitive: false,
      ),
      (_) => 'fill:$hex',
    );
    out = out.replaceAllMapped(
      RegExp(
        r'stroke\s*:\s*(#[0-9a-fA-F]{3,8}|rgb\([^)]+\)|rgba\([^)]+\)|[a-zA-Z]+)',
        caseSensitive: false,
      ),
      (_) => 'stroke:$hex',
    );

    // Inline hex colors in paths (common in Illustrator exports)
    out = out.replaceAllMapped(
      RegExp(r'#[0-9a-fA-F]{6}\b'),
      (_) => hex,
    );

    // If still no fill on shapes, set currentColor on root <svg>
    if (!out.contains('fill=') && !out.contains('fill:')) {
      out = out.replaceFirstMapped(
        RegExp(r'<svg\b', caseSensitive: false),
        (m) => '${m.group(0)} fill="$hex"',
      );
    }

    return out;
  }

  static String _toHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

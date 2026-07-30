import 'package:flutter/material.dart';

/// Admin-controlled logo placement inside a fixed display canvas.
class BrandLogoLayout {
  const BrandLogoLayout({
    this.scale = 1.0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.backgroundColorHex,
  });

  final double scale;
  final double offsetX;
  final double offsetY;
  final String? backgroundColorHex;

  Color? get backgroundColor => parseHexColor(backgroundColorHex);

  static Color? parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  static String? colorToHex(Color? color) {
    if (color == null) return null;
    final c = color.withValues(alpha: 1);
    return '#${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}';
  }

  factory BrandLogoLayout.fromRow(Map<String, dynamic> row) {
    return BrandLogoLayout(
      scale: (row['logo_scale'] as num?)?.toDouble() ?? 1.0,
      offsetX: (row['logo_offset_x'] as num?)?.toDouble() ?? 0,
      offsetY: (row['logo_offset_y'] as num?)?.toDouble() ?? 0,
      backgroundColorHex: row['logo_background_color'] as String?,
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        'logo_scale': scale,
        'logo_offset_x': offsetX,
        'logo_offset_y': offsetY,
        'logo_background_color': backgroundColorHex,
      };

  BrandLogoLayout copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
    String? backgroundColorHex,
    bool clearBackground = false,
  }) {
    return BrandLogoLayout(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      backgroundColorHex:
          clearBackground ? null : (backgroundColorHex ?? this.backgroundColorHex),
    );
  }
}

/// Fixed display canvases for logo previews (object-fit: contain).
abstract final class BrandLogoCanvasPreset {
  static const homepageDesktop = Size(160, 72);
  static const homepageMobile = Size(120, 56);
  static const storeFeatured = Size(200, 96);
  static const storeCarousel = Size(140, 64);
  /// Compact logos for horizontal brand strip on mobile store.
  static const storeCarouselMobile = Size(72, 36);
  static const storeCarouselTablet = Size(88, 44);
  static const adminEditor = Size(400, 200);
}

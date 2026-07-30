import 'package:flutter/material.dart';

/// Per-surface image framing for public storefront (no shop/admin imports).
class PublicImageLayout {
  const PublicImageLayout({
    this.scale = 1.0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.backgroundColorHex,
  });

  final double scale;
  final double offsetX;
  final double offsetY;
  final String? backgroundColorHex;

  Color? get backgroundColor {
    final hex = backgroundColorHex;
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}

class PublicImagePlacements {
  const PublicImagePlacements(this.bySlot);

  final Map<String, PublicImageLayout> bySlot;

  static const defaultSlotId = 'default';

  bool get isEmpty => bySlot.isEmpty;

  PublicImageLayout layoutFor(String slotId) {
    return bySlot[slotId] ?? const PublicImageLayout();
  }

  static PublicImagePlacements fromJson(dynamic raw) {
    if (raw is! Map) return const PublicImagePlacements({});
    final map = <String, PublicImageLayout>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val is! Map) continue;
      map[key] = PublicImageLayout(
        scale: (val['scale'] as num?)?.toDouble() ?? 1,
        offsetX: (val['offset_x'] as num?)?.toDouble() ?? 0,
        offsetY: (val['offset_y'] as num?)?.toDouble() ?? 0,
        backgroundColorHex: val['background_color'] as String?,
      );
    }
    return PublicImagePlacements(map);
  }
}

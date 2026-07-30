import '../data/shop_media_processor.dart';
import 'brand_logo_layout.dart';
import 'shop_image_display_slots.dart';
import 'shop_media_models.dart';

/// Per-surface image framing — homepage card vs category banner vs mobile, etc.
class EntityImagePlacements {
  const EntityImagePlacements(this.bySlot);

  final Map<String, BrandLogoLayout> bySlot;

  static const defaultSlotId = 'default';

  BrandLogoLayout layoutFor(String slotId, {BrandLogoLayout? fallback}) {
    return bySlot[slotId] ?? fallback ?? const BrandLogoLayout();
  }

  EntityImagePlacements withSlot(String slotId, BrandLogoLayout layout) {
    return EntityImagePlacements({...bySlot, slotId: layout});
  }

  static EntityImagePlacements fromSingle(BrandLogoLayout layout, ShopImagePreset preset) {
    final map = <String, BrandLogoLayout>{};
    for (final slot in ShopImageDisplaySlots.forPreset(preset)) {
      map[slot.id] = layout;
    }
    return EntityImagePlacements(map);
  }

  /// Auto-fit every display slot for a preset (independent framing per surface).
  static EntityImagePlacements autoFitForPreset({
    required ShopImagePreset preset,
    required int sourceW,
    required int sourceH,
  }) {
    final slots = ShopImageDisplaySlots.forPreset(preset);
    final map = <String, BrandLogoLayout>{};
    for (final slot in slots) {
      map[slot.id] = EntityImageFrameMath.autoFitLayout(
        sourceW: sourceW,
        sourceH: sourceH,
        canvasW: preset.width,
        canvasH: preset.height,
      );
    }
    return EntityImagePlacements(map);
  }

  static EntityImagePlacements fromJson(dynamic raw) {
    if (raw is! Map) return const EntityImagePlacements({});
    final map = <String, BrandLogoLayout>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val is! Map) continue;
      map[key] = BrandLogoLayout(
        scale: (val['scale'] as num?)?.toDouble() ?? 1,
        offsetX: (val['offset_x'] as num?)?.toDouble() ?? 0,
        offsetY: (val['offset_y'] as num?)?.toDouble() ?? 0,
        backgroundColorHex: val['background_color'] as String?,
      );
    }
    return EntityImagePlacements(map);
  }

  Map<String, dynamic> toJson() => {
        for (final e in bySlot.entries)
          e.key: {
            'scale': e.value.scale,
            'offset_x': e.value.offsetX,
            'offset_y': e.value.offsetY,
            if (e.value.backgroundColorHex != null) 'background_color': e.value.backgroundColorHex,
          },
      };

  BrandLogoLayout get defaultLayout => layoutFor(defaultSlotId);

  EntityImagePlacements autoFitAllSlots({
    required ShopImagePreset preset,
    required int sourceW,
    required int sourceH,
  }) {
    return autoFitForPreset(preset: preset, sourceW: sourceW, sourceH: sourceH);
  }
}

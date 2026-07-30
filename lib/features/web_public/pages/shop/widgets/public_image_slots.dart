import '../../../data/models/public_image_placements.dart';

/// Output canvas + display slot sizes for public storefront images.
enum PublicStoreImagePreset {
  category(1200, 630),
  subCategory(1200, 630),
  productMain(1000, 1000);

  const PublicStoreImagePreset(this.width, this.height);

  final int width;
  final int height;
}

class PublicImageDisplaySlot {
  const PublicImageDisplaySlot({
    required this.id,
    required this.width,
    required this.height,
  });

  final String id;
  final double width;
  final double height;
}

abstract final class PublicImageDisplaySlots {
  static PublicImageDisplaySlot? find(PublicStoreImagePreset preset, String slotId) {
    for (final slot in forPreset(preset)) {
      if (slot.id == slotId) return slot;
    }
    return null;
  }

  static List<PublicImageDisplaySlot> forPreset(PublicStoreImagePreset preset) {
    return switch (preset) {
      PublicStoreImagePreset.category => const [
          PublicImageDisplaySlot(id: 'homepage_card', width: 260, height: 400),
          PublicImageDisplaySlot(id: 'category_banner', width: 380, height: 168),
          PublicImageDisplaySlot(id: 'mobile_homepage', width: 160, height: 260),
          PublicImageDisplaySlot(id: PublicImagePlacements.defaultSlotId, width: 210, height: 110),
        ],
      PublicStoreImagePreset.subCategory => const [
          PublicImageDisplaySlot(id: 'sub_header', width: 380, height: 168),
          PublicImageDisplaySlot(id: 'store_browse', width: 280, height: 147),
          PublicImageDisplaySlot(id: 'mobile_card', width: 150, height: 79),
          PublicImageDisplaySlot(id: PublicImagePlacements.defaultSlotId, width: 210, height: 110),
        ],
      PublicStoreImagePreset.productMain => const [
          PublicImageDisplaySlot(id: 'store_grid', width: 200, height: 190),
          PublicImageDisplaySlot(id: 'product_detail', width: 300, height: 300),
          PublicImageDisplaySlot(id: 'cart_thumb', width: 72, height: 72),
          PublicImageDisplaySlot(id: 'quick_view', width: 260, height: 260),
          PublicImageDisplaySlot(id: PublicImagePlacements.defaultSlotId, width: 120, height: 120),
        ],
    };
  }
}
import 'brand_logo_layout.dart';
import 'entity_image_placements.dart';
import 'shop_media_models.dart';

/// One public/admin surface where an image is shown.
class ShopImageDisplaySlot {
  const ShopImageDisplaySlot({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    this.isDefaultOutput = false,
  });

  final String id;
  final String label;
  final double width;
  final double height;

  /// Layout for this slot is used to build the main saved WebP (`image_url`).
  final bool isDefaultOutput;
}

abstract final class ShopImageDisplaySlots {
  static List<ShopImageDisplaySlot> forPreset(ShopImagePreset preset) {
    return switch (preset) {
      ShopImagePreset.category => const [
        ShopImageDisplaySlot(id: 'homepage_card', label: 'Homepage card', width: 260, height: 400),
        ShopImageDisplaySlot(id: 'category_banner', label: 'Category page banner', width: 380, height: 168),
        ShopImageDisplaySlot(id: 'mobile_homepage', label: 'Mobile homepage', width: 160, height: 260),
        ShopImageDisplaySlot(
          id: EntityImagePlacements.defaultSlotId,
          label: 'SEO / fallback',
          width: 210,
          height: 110,
          isDefaultOutput: true,
        ),
      ],
      ShopImagePreset.subCategory => const [
        ShopImageDisplaySlot(id: 'sub_header', label: 'Sub-category header', width: 380, height: 168),
        ShopImageDisplaySlot(id: 'store_browse', label: 'Store browse', width: 280, height: 147),
        ShopImageDisplaySlot(id: 'mobile_card', label: 'Mobile card', width: 150, height: 79),
        ShopImageDisplaySlot(
          id: EntityImagePlacements.defaultSlotId,
          label: 'SEO / fallback',
          width: 210,
          height: 110,
          isDefaultOutput: true,
        ),
      ],
      ShopImagePreset.productMain => const [
        ShopImageDisplaySlot(id: 'store_grid', label: 'Store grid card', width: 200, height: 190),
        ShopImageDisplaySlot(id: 'product_detail', label: 'Product detail', width: 300, height: 300),
        ShopImageDisplaySlot(id: 'cart_thumb', label: 'Cart thumbnail', width: 72, height: 72),
        ShopImageDisplaySlot(id: 'quick_view', label: 'Quick view', width: 260, height: 260),
        ShopImageDisplaySlot(
          id: EntityImagePlacements.defaultSlotId,
          label: 'SEO / fallback',
          width: 120,
          height: 120,
          isDefaultOutput: true,
        ),
      ],
      ShopImagePreset.productGallery => const [
        ShopImageDisplaySlot(id: 'gallery_thumb', label: 'Gallery thumb', width: 84, height: 84),
        ShopImageDisplaySlot(id: 'store_card', label: 'Store card', width: 200, height: 190),
        ShopImageDisplaySlot(id: 'detail_zoom', label: 'Detail zoom', width: 320, height: 320),
        ShopImageDisplaySlot(
          id: EntityImagePlacements.defaultSlotId,
          label: 'SEO / fallback',
          width: 120,
          height: 120,
          isDefaultOutput: true,
        ),
      ],
      ShopImagePreset.brandLogo => [
        ShopImageDisplaySlot(
          id: 'homepage_desktop',
          label: 'Homepage desktop',
          width: BrandLogoCanvasPreset.homepageDesktop.width,
          height: BrandLogoCanvasPreset.homepageDesktop.height,
        ),
        ShopImageDisplaySlot(
          id: 'homepage_mobile',
          label: 'Homepage mobile',
          width: BrandLogoCanvasPreset.homepageMobile.width,
          height: BrandLogoCanvasPreset.homepageMobile.height,
        ),
        ShopImageDisplaySlot(
          id: 'store_featured',
          label: 'Store featured',
          width: BrandLogoCanvasPreset.storeFeatured.width,
          height: BrandLogoCanvasPreset.storeFeatured.height,
        ),
        ShopImageDisplaySlot(
          id: EntityImagePlacements.defaultSlotId,
          label: 'Store carousel',
          width: BrandLogoCanvasPreset.storeCarousel.width,
          height: BrandLogoCanvasPreset.storeCarousel.height,
          isDefaultOutput: true,
        ),
      ],
    };
  }

  static ShopImageDisplaySlot defaultSlot(ShopImagePreset preset) {
    return forPreset(preset).firstWhere((s) => s.isDefaultOutput);
  }

  static ShopImageDisplaySlot? find(ShopImagePreset preset, String slotId) {
    for (final s in forPreset(preset)) {
      if (s.id == slotId) return s;
    }
    return null;
  }
}

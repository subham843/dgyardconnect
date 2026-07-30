// Public Store domain models.
// All data originates from admin-managed Supabase tables/views:
//   v_public_categories, v_public_subcategories, v_public_products,
//   v_public_product_images, v_public_product_attributes,
//   brands, shop_banners, v_active_offers.
// No hardcoded catalog content lives here.

import 'package:flutter/material.dart';

import 'public_brand.dart';
import 'public_image_placements.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// A top-level category card (Apple-style image experience).
class PublicCategory {
  PublicCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.imageEditorSourceUrl,
    this.imagePlacements,
    this.imageSourceW,
    this.imageSourceH,
    this.subcategories = const [],
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String? imageEditorSourceUrl;
  final PublicImagePlacements? imagePlacements;
  final int? imageSourceW;
  final int? imageSourceH;
  final List<PublicSubcategory> subcategories;
  int productCount;

  String get safeDescription =>
      (description != null && description!.trim().isNotEmpty)
          ? description!.trim()
          : 'Explore curated $name solutions for modern infrastructure.';

  factory PublicCategory.fromRow(Map<String, dynamic> row) {
    return PublicCategory(
      id: row['id'].toString(),
      name: (row['name'] ?? '').toString(),
      slug: (row['slug'] ?? '').toString(),
      description: (row['description'] as String?)?.trim().isNotEmpty == true
          ? row['description'] as String?
          : (row['meta_description'] as String?),
      imageUrl: (row['image_url'] as String?)?.trim().isNotEmpty == true
          ? row['image_url'] as String?
          : (row['og_image'] as String?),
      imageEditorSourceUrl: row['image_editor_source_url'] as String?,
      imagePlacements: PublicImagePlacements.fromJson(row['image_placements']),
      imageSourceW: row['image_source_width'] != null ? _toInt(row['image_source_width']) : null,
      imageSourceH: row['image_source_height'] != null ? _toInt(row['image_source_height']) : null,
    );
  }
}

class PublicSubcategory {
  PublicSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.imageEditorSourceUrl,
    this.imagePlacements,
    this.imageSourceW,
    this.imageSourceH,
    this.productCount = 0,
  });

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String? imageEditorSourceUrl;
  final PublicImagePlacements? imagePlacements;
  final int? imageSourceW;
  final int? imageSourceH;
  int productCount;

  factory PublicSubcategory.fromRow(Map<String, dynamic> row) {
    return PublicSubcategory(
      id: row['id'].toString(),
      categoryId: (row['category_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      slug: (row['slug'] ?? '').toString(),
      description: row['description'] as String?,
      imageUrl: (row['image_url'] as String?)?.trim().isNotEmpty == true
          ? row['image_url'] as String?
          : (row['og_image'] as String?),
      imageEditorSourceUrl: row['image_editor_source_url'] as String?,
      imagePlacements: PublicImagePlacements.fromJson(row['image_placements']),
      imageSourceW: row['image_source_width'] != null ? _toInt(row['image_source_width']) : null,
      imageSourceH: row['image_source_height'] != null ? _toInt(row['image_source_height']) : null,
    );
  }
}

class PublicProduct {
  PublicProduct({
    required this.id,
    required this.name,
    required this.slug,
    this.sku,
    this.subCategoryId,
    this.brandId,
    this.onlinePrice,
    this.mrp,
    this.sellingPrice,
    this.shortDescription,
    this.description,
    this.technicalNotes,
    this.installationNotes,
    this.modelName,
    this.warranty,
    this.createdAt,
    this.imageUrl,
    this.thumbnailUrl,
    this.imageEditorSourceUrl,
    this.imagePlacements,
    this.imageSourceW,
    this.imageSourceH,
    this.galleryUrls = const [],
    this.attributes = const {},
    this.categoryId,
    this.brandName,
  });

  final String id;
  final String name;
  final String slug;
  final String? sku;
  final String? subCategoryId;
  final String? brandId;
  final double? onlinePrice;
  final double? mrp;
  final double? sellingPrice;
  final String? shortDescription;
  final String? description;
  final String? technicalNotes;
  final String? installationNotes;
  final String? modelName;
  final String? warranty;
  final DateTime? createdAt;

  String? imageUrl;
  String? thumbnailUrl;
  String? imageEditorSourceUrl;
  PublicImagePlacements? imagePlacements;
  int? imageSourceW;
  int? imageSourceH;
  List<String> galleryUrls;
  Map<String, String> attributes;

  // Resolved client-side from lookups.
  String? categoryId;
  String? brandName;

  double? get price => onlinePrice ?? sellingPrice;

  bool get hasDiscount =>
      mrp != null && price != null && mrp! > price! && price! > 0;

  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((mrp! - price!) / mrp!) * 100).round();
  }

  /// Public views expose only active products, so they are purchasable.
  bool get inStock => true;

  factory PublicProduct.fromRow(Map<String, dynamic> row) {
    final slug = (row['url_slug'] as String?)?.trim();
    return PublicProduct(
      id: row['id'].toString(),
      name: (row['name'] ?? 'Product').toString(),
      slug: (slug != null && slug.isNotEmpty) ? slug : row['id'].toString(),
      sku: row['sku'] as String?,
      subCategoryId: row['sub_category_id']?.toString(),
      brandId: row['brand_id']?.toString(),
      onlinePrice: _toDouble(row['online_price']),
      mrp: _toDouble(row['mrp']),
      sellingPrice: _toDouble(row['selling_price']),
      shortDescription: row['short_description'] as String?,
      description: row['description'] as String?,
      technicalNotes: row['technical_notes'] as String?,
      installationNotes: row['installation_notes'] as String?,
      modelName: row['model_name'] as String?,
      warranty: row['warranty'] as String?,
      createdAt: _toDate(row['created_at']),
      imageEditorSourceUrl: row['main_image_editor_source_url'] as String?,
      imagePlacements: PublicImagePlacements.fromJson(row['main_image_placements']),
      imageSourceW: row['main_image_source_width'] != null
          ? _toInt(row['main_image_source_width'])
          : null,
      imageSourceH: row['main_image_source_height'] != null
          ? _toInt(row['main_image_source_height'])
          : null,
    );
  }
}

class PublicBanner {
  PublicBanner({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.mobileImageUrl,
    this.ctaText,
    this.ctaUrl,
    this.displayOrder = 0,
  });

  final String id;
  final String type;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? mobileImageUrl;
  final String? ctaText;
  final String? ctaUrl;
  final int displayOrder;

  factory PublicBanner.fromRow(Map<String, dynamic> row) {
    return PublicBanner(
      id: row['id'].toString(),
      type: (row['banner_type'] ?? 'store').toString(),
      title: (row['title'] ?? '').toString(),
      subtitle: row['subtitle'] as String?,
      description: row['description'] as String?,
      imageUrl: row['image_url'] as String?,
      mobileImageUrl: row['mobile_image_url'] as String?,
      ctaText: row['cta_text'] as String?,
      ctaUrl: row['cta_url'] as String?,
      displayOrder: _toInt(row['display_order']),
    );
  }
}

class PublicOffer {
  PublicOffer({
    required this.id,
    required this.offerType,
    required this.name,
    this.description,
    this.bannerUrl,
    this.discountType,
    this.discountValue,
    this.badgeText,
    this.badgeColor,
    this.categoryId,
    this.subcategoryId,
    this.endDate,
    this.priority = 0,
    this.productCount = 0,
  });

  final String id;
  final String offerType;
  final String name;
  final String? description;
  final String? bannerUrl;
  final String? discountType;
  final double? discountValue;
  final String? badgeText;
  final String? badgeColor;
  final String? categoryId;
  final String? subcategoryId;
  final DateTime? endDate;
  final int priority;
  final int productCount;

  bool get isFlash => offerType == 'flash';

  String get headlineDiscount {
    if (discountValue == null) return badgeText ?? 'Special Offer';
    if (discountType == 'percentage') {
      return '${discountValue!.toStringAsFixed(0)}% OFF';
    }
    return '₹${discountValue!.toStringAsFixed(0)} OFF';
  }

  Color get accentColor {
    final hex = badgeColor?.replaceAll('#', '');
    if (hex == null || hex.length != 6) return const Color(0xFFFF7A00);
    final value = int.tryParse('FF$hex', radix: 16);
    return value == null ? const Color(0xFFFF7A00) : Color(value);
  }

  factory PublicOffer.fromRow(Map<String, dynamic> row) {
    return PublicOffer(
      id: row['id'].toString(),
      offerType: (row['offer_type'] ?? 'percentage').toString(),
      name: (row['name'] ?? 'Offer').toString(),
      description: row['description'] as String?,
      bannerUrl: row['banner_url'] as String?,
      discountType: row['discount_type'] as String?,
      discountValue: _toDouble(row['discount_value']),
      badgeText: row['badge_text'] as String?,
      badgeColor: row['badge_color'] as String?,
      categoryId: row['category_id']?.toString(),
      subcategoryId: row['subcategory_id']?.toString(),
      endDate: _toDate(row['end_date']),
      priority: _toInt(row['priority']),
      productCount: _toInt(row['product_count']),
    );
  }
}

/// Everything the store needs, loaded once and faceted client-side.
class StoreCatalog {
  StoreCatalog({
    required this.categories,
    required this.subcategories,
    required this.products,
    required this.brands,
    required this.banners,
    required this.offers,
  });

  final List<PublicCategory> categories;
  final List<PublicSubcategory> subcategories;
  final List<PublicProduct> products;
  final List<PublicBrand> brands;
  final List<PublicBanner> banners;
  final List<PublicOffer> offers;

  bool get isEmpty => products.isEmpty && categories.isEmpty;

  static StoreCatalog empty() => StoreCatalog(
        categories: const [],
        subcategories: const [],
        products: const [],
        brands: const [],
        banners: const [],
        offers: const [],
      );
}

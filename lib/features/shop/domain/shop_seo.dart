import '../config/shop_seo_config.dart';
import '../data/supabase_repository_base.dart';

/// Admin-editable SEO only (everything else is auto-generated on save).
class ShopSeoAdminInput {
  const ShopSeoAdminInput({
    this.seoTitle,
    this.metaDescription,
    this.slugOverride,
    this.ogImageOverride,
  });

  final String? seoTitle;
  final String? metaDescription;

  /// Manual slug; auto-generated from name when empty.
  final String? slugOverride;

  /// Products only — when set, overrides main image for Open Graph.
  final String? ogImageOverride;
}

/// Full SEO stored in DB (admin fields + system-generated canonical / OG).
class ShopSeoResolved {
  const ShopSeoResolved({
    required this.slug,
    this.seoTitle,
    this.metaDescription,
    this.canonicalUrl,
    this.ogTitle,
    this.ogDescription,
    this.ogImage,
    this.ogImageOverride,
  });

  final String slug;
  final String? seoTitle;
  final String? metaDescription;
  final String? canonicalUrl;
  final String? ogTitle;
  final String? ogDescription;
  final String? ogImage;

  /// Product-only stored override (null = use main product image).
  final String? ogImageOverride;

  factory ShopSeoResolved.fromCategoryRow(Map<String, dynamic> row) => ShopSeoResolved(
        slug: row['slug'] as String? ?? '',
        seoTitle: row['seo_title'] as String?,
        metaDescription: row['meta_description'] as String?,
        canonicalUrl: row['canonical_url'] as String?,
        ogTitle: row['og_title'] as String?,
        ogDescription: row['og_description'] as String?,
        ogImage: row['og_image'] as String? ?? row['image_url'] as String?,
      );

  factory ShopSeoResolved.fromSubCategoryRow(Map<String, dynamic> row) => ShopSeoResolved(
        slug: row['slug'] as String? ?? '',
        seoTitle: row['seo_title'] as String?,
        metaDescription: row['meta_description'] as String?,
        canonicalUrl: row['canonical_url'] as String?,
        ogTitle: row['og_title'] as String?,
        ogDescription: row['og_description'] as String?,
        ogImage: row['og_image'] as String? ?? row['image_url'] as String?,
      );

  factory ShopSeoResolved.fromProductRow(Map<String, dynamic> row) => ShopSeoResolved(
        slug: row['url_slug'] as String? ?? row['sku'] as String? ?? '',
        seoTitle: row['seo_title'] as String?,
        metaDescription: row['seo_description'] as String?,
        canonicalUrl: row['canonical_url'] as String?,
        ogTitle: row['og_title'] as String?,
        ogDescription: row['og_description'] as String?,
        ogImage: row['og_image'] as String?,
        ogImageOverride: row['og_image_override'] as String?,
      );

  Map<String, dynamic> toCategoryPayload() => {
        'slug': slug,
        if (seoTitle != null) 'seo_title': seoTitle,
        if (metaDescription != null) 'meta_description': metaDescription,
        if (canonicalUrl != null) 'canonical_url': canonicalUrl,
        if (ogTitle != null) 'og_title': ogTitle,
        if (ogDescription != null) 'og_description': ogDescription,
        if (ogImage != null) 'og_image': ogImage,
      };

  Map<String, dynamic> toSubCategoryPayload() => toCategoryPayload();

  Map<String, dynamic> toProductPayload() => {
        'url_slug': slug,
        if (seoTitle != null) 'seo_title': seoTitle,
        if (metaDescription != null) 'seo_description': metaDescription,
        if (canonicalUrl != null) 'canonical_url': canonicalUrl,
        if (ogTitle != null) 'og_title': ogTitle,
        if (ogDescription != null) 'og_description': ogDescription,
        if (ogImage != null) 'og_image': ogImage,
        'og_image_override': ogImageOverride,
      };
}

/// Slug + canonical / OG / JSON-LD generation.
abstract final class ShopSeoService {
  ShopSeoService._();

  static String effectiveSlug({
    required String name,
    String? slugOverride,
    String? existingSlug,
  }) {
    final manual = slugOverride?.trim();
    if (manual != null && manual.isNotEmpty) {
      return SupabaseRepositoryBase.slugify(manual);
    }
    if (existingSlug != null && existingSlug.trim().isNotEmpty) {
      return existingSlug.trim();
    }
    return SupabaseRepositoryBase.slugify(name);
  }

  static ShopSeoResolved resolveCategory({
    required ShopSeoAdminInput input,
    required String name,
    String? existingSlug,
    String? imageUrl,
  }) {
    final slug = effectiveSlug(name: name, slugOverride: input.slugOverride, existingSlug: existingSlug);
    final title = _nonEmpty(input.seoTitle) ?? name.trim();
    final description = _nonEmpty(input.metaDescription);
    final ogImage = _nonEmpty(imageUrl);
    return ShopSeoResolved(
      slug: slug,
      seoTitle: title,
      metaDescription: description,
      canonicalUrl: ShopSeoConfig.absolute(ShopSeoConfig.shopCategoryPath(slug)),
      ogTitle: title,
      ogDescription: description ?? title,
      ogImage: ogImage,
    );
  }

  static ShopSeoResolved resolveSubCategory({
    required ShopSeoAdminInput input,
    required String name,
    required String categorySlug,
    String? existingSlug,
    String? imageUrl,
  }) {
    final slug = effectiveSlug(name: name, slugOverride: input.slugOverride, existingSlug: existingSlug);
    final title = _nonEmpty(input.seoTitle) ?? name.trim();
    final description = _nonEmpty(input.metaDescription);
    final ogImage = _nonEmpty(imageUrl);
    final catSlug = SupabaseRepositoryBase.slugify(categorySlug);
    return ShopSeoResolved(
      slug: slug,
      seoTitle: title,
      metaDescription: description,
      canonicalUrl: ShopSeoConfig.absolute(ShopSeoConfig.shopSubCategoryPath(catSlug, slug)),
      ogTitle: title,
      ogDescription: description ?? title,
      ogImage: ogImage,
    );
  }

  static ShopSeoResolved resolveProduct({
    required ShopSeoAdminInput input,
    required String name,
    required String categorySlug,
    required String subCategorySlug,
    String? existingSlug,
    String? mainImageUrl,
    String? fallbackSku,
  }) {
    final slug = effectiveSlug(
      name: name,
      slugOverride: input.slugOverride,
      existingSlug: existingSlug ?? (fallbackSku != null ? SupabaseRepositoryBase.slugify(fallbackSku) : null),
    );
    final title = _nonEmpty(input.seoTitle) ?? name.trim();
    final description = _nonEmpty(input.metaDescription);
    final ogOverride = _nonEmpty(input.ogImageOverride);
    final ogImage = ogOverride ?? _nonEmpty(mainImageUrl);
    return ShopSeoResolved(
      slug: slug,
      seoTitle: title,
      metaDescription: description,
      canonicalUrl: ShopSeoConfig.absolute(ShopSeoConfig.productPath(slug)),
      ogTitle: title,
      ogDescription: description ?? title,
      ogImage: ogImage,
      ogImageOverride: ogOverride,
    );
  }

  static String? _nonEmpty(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}

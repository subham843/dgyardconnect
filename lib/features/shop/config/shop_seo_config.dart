import '../../../core/seo/site_seo_config.dart';

/// Public shop URL base for canonical and Open Graph links.
abstract final class ShopSeoConfig {
  ShopSeoConfig._();

  /// Store brand for SEO titles and meta (AI assist + auto OG).
  static const String companyName = 'DG Yard';

  static const String companySiteHost = SiteSeoConfig.siteHost;

  /// Production storefront base (no trailing slash).
  static const String baseUrl = String.fromEnvironment(
    'SHOP_SEO_BASE_URL',
    defaultValue: SiteSeoConfig.baseUrl,
  );

  static String shopCategoryPath(String categorySlug) => '/store/category/$categorySlug';

  static String shopSubCategoryPath(String categorySlug, String subCategorySlug) =>
      '/store?category=$categorySlug&subcategory=$subCategorySlug';

  static String productPath(String productSlug) => '/product/$productSlug';

  static String absolute(String path) {
    if (path.startsWith('http')) return path;
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$p';
  }
}

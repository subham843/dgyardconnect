import 'shop_seo.dart';

/// JSON-LD structured data for shop catalog pages (generate at render or persist in metadata).
abstract final class ShopStructuredData {
  ShopStructuredData._();

  static Map<String, dynamic> collectionPage({
    required String name,
    required String url,
    String? description,
    String? imageUrl,
  }) {
    return {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': name,
      'url': url,
      if (description != null && description.isNotEmpty) 'description': description,
      if (imageUrl != null && imageUrl.isNotEmpty)
        'image': imageUrl,
    };
  }

  static Map<String, dynamic> product({
    required String name,
    required String url,
    required String sku,
    required double price,
    required bool inStock,
    String? description,
    String? brandName,
    String? imageUrl,
    String? currency,
  }) {
    return {
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': name,
      'url': url,
      'sku': sku,
      if (description != null && description.isNotEmpty) 'description': description,
      if (brandName != null && brandName.isNotEmpty)
        'brand': {'@type': 'Brand', 'name': brandName},
      if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
      'offers': {
        '@type': 'Offer',
        'url': url,
        'priceCurrency': currency ?? 'INR',
        'price': price.toStringAsFixed(2),
        'availability': inStock
            ? 'https://schema.org/InStock'
            : 'https://schema.org/OutOfStock',
      },
    };
  }

  static Map<String, dynamic> categoryPage(ShopSeoResolved seo, {required String categoryName}) =>
      collectionPage(
        name: seo.seoTitle ?? categoryName,
        url: seo.canonicalUrl ?? '',
        description: seo.metaDescription,
        imageUrl: seo.ogImage,
      );

  static Map<String, dynamic> subCategoryPage(ShopSeoResolved seo, {required String subCategoryName}) =>
      collectionPage(
        name: seo.seoTitle ?? subCategoryName,
        url: seo.canonicalUrl ?? '',
        description: seo.metaDescription,
        imageUrl: seo.ogImage,
      );

  static Map<String, dynamic> productPage({
    required ShopSeoResolved seo,
    required String productName,
    required String sku,
    required double price,
    required int qtyOnHand,
    String? brandName,
    String? description,
    String? mainImageUrl,
  }) =>
      product(
        name: seo.seoTitle ?? productName,
        url: seo.canonicalUrl ?? '',
        sku: sku,
        price: price,
        inStock: qtyOnHand > 0,
        description: seo.metaDescription ?? description,
        brandName: brandName,
        imageUrl: seo.ogImage ?? mainImageUrl,
      );
}

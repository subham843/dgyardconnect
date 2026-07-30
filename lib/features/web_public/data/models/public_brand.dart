import '../../../shop/domain/brand_logo_layout.dart';

class PublicBrand {
  const PublicBrand({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.logoMimeType,
    this.logoLayout = const BrandLogoLayout(),
    this.shortDescription,
    this.isFeaturedOnHomepage = false,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? logoMimeType;
  final BrandLogoLayout logoLayout;
  final String? shortDescription;
  final bool isFeaturedOnHomepage;
  final int displayOrder;

  factory PublicBrand.fromRow(Map<String, dynamic> row) {
    return PublicBrand(
      id: row['id'].toString(),
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      logoUrl: row['logo_url'] as String?,
      logoMimeType: row['logo_mime_type'] as String?,
      logoLayout: BrandLogoLayout.fromRow(row),
      shortDescription: row['short_description'] as String?,
      isFeaturedOnHomepage: row['is_featured_on_homepage'] as bool? ?? false,
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

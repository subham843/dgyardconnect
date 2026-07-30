import 'shop_seo.dart';

class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.sortOrder,
    required this.isActive,
    this.imageUrl,
    this.seo = const ShopSeoResolved(slug: ''),
  });

  final String id;
  final String name;
  final String slug;
  final int sortOrder;
  final bool isActive;

  /// Public URL from Supabase Storage (not typed by admin).
  final String? imageUrl;
  final ShopSeoResolved seo;

  factory ShopCategory.fromRow(Map<String, dynamic> row) {
    return ShopCategory(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      imageUrl: row['image_url'] as String? ?? row['og_image'] as String?,
      seo: ShopSeoResolved.fromCategoryRow(row),
    );
  }
}

class ShopSubCategory {
  const ShopSubCategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.description,
    required this.sortOrder,
    required this.isActive,
    this.defaultGstPercentage = 18,
    this.defaultHsnCode,
    this.imageUrl,
    this.seo = const ShopSeoResolved(slug: ''),
    this.attributeGroupIds = const [],
    this.attributeGroupNames = const [],
  });

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final double defaultGstPercentage;
  final String? defaultHsnCode;
  final String? imageUrl;
  final ShopSeoResolved seo;
  final List<String> attributeGroupIds;
  final List<String> attributeGroupNames;

  factory ShopSubCategory.fromRow(Map<String, dynamic> row) {
    final groupIds = <String>[];
    final groupNames = <String>[];
    final links = row['sub_category_attribute_groups'];
    if (links is List) {
      for (final link in links) {
        final m = link as Map<String, dynamic>;
        final gid = m['attribute_group_id'] as String?;
        if (gid != null) groupIds.add(gid);
        final ag = m['attribute_groups'] as Map<String, dynamic>?;
        final name = ag?['name'] as String?;
        if (name != null) groupNames.add(name);
      }
    }
    return ShopSubCategory(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      description: row['description'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      defaultGstPercentage: (row['default_gst_percentage'] as num?)?.toDouble() ?? 18,
      defaultHsnCode: row['default_hsn_code'] as String?,
      imageUrl: row['image_url'] as String?,
      seo: ShopSeoResolved.fromSubCategoryRow(row),
      attributeGroupIds: groupIds,
      attributeGroupNames: groupNames,
    );
  }
}

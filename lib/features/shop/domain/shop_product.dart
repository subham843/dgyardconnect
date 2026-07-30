import '../data/supabase_repository_base.dart';
import 'brand_logo_layout.dart';

class ShopBrand {
  const ShopBrand({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
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
  final bool isActive;
  final String? logoUrl;
  final String? logoMimeType;
  final BrandLogoLayout logoLayout;
  final String? shortDescription;
  final bool isFeaturedOnHomepage;
  final int displayOrder;

  factory ShopBrand.fromRow(Map<String, dynamic> row) {
    return ShopBrand(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      isActive: row['is_active'] as bool? ?? true,
      logoUrl: row['logo_url'] as String?,
      logoMimeType: row['logo_mime_type'] as String?,
      logoLayout: BrandLogoLayout.fromRow(row),
      shortDescription: row['short_description'] as String?,
      isFeaturedOnHomepage: row['is_featured_on_homepage'] as bool? ?? false,
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.subCategoryId,
    this.brandId,
    required this.sku,
    required this.name,
    this.description,
    required this.basePrice,
    this.taxClass,
    required this.isActive,
    this.qtyOnHand,
    this.imageUrl,
    this.subCategoryName,
    this.categoryName,
    this.mrp,
    this.onlinePrice,
    this.dealerPrice,
  });

  final String id;
  final String subCategoryId;
  final String? brandId;
  final String sku;
  final String name;
  final String? description;
  final double basePrice;
  final String? taxClass;
  final bool isActive;
  final int? qtyOnHand;
  final String? imageUrl;
  final String? subCategoryName;
  final String? categoryName;
  final double? mrp;
  final double? onlinePrice;
  final double? dealerPrice;

  ShopProduct copyWith({
    double? basePrice,
    bool? isActive,
    double? mrp,
    double? onlinePrice,
    double? dealerPrice,
    bool clearMrp = false,
    bool clearOnlinePrice = false,
    bool clearDealerPrice = false,
  }) {
    return ShopProduct(
      id: id,
      subCategoryId: subCategoryId,
      brandId: brandId,
      sku: sku,
      name: name,
      description: description,
      basePrice: basePrice ?? this.basePrice,
      taxClass: taxClass,
      isActive: isActive ?? this.isActive,
      qtyOnHand: qtyOnHand,
      imageUrl: imageUrl,
      subCategoryName: subCategoryName,
      categoryName: categoryName,
      mrp: clearMrp ? null : (mrp ?? this.mrp),
      onlinePrice: clearOnlinePrice ? null : (onlinePrice ?? this.onlinePrice),
      dealerPrice: clearDealerPrice ? null : (dealerPrice ?? this.dealerPrice),
    );
  }

  factory ShopProduct.fromRow(Map<String, dynamic> row) {
    final inv = SupabaseRepositoryBase.embeddedRows(row['inventory']);
    int? qty;
    if (inv.isNotEmpty) {
      qty = (inv.first['qty_on_hand'] as num?)?.toInt();
    } else if (row['qty_on_hand'] != null) {
      qty = (row['qty_on_hand'] as num?)?.toInt();
    }
    final images = SupabaseRepositoryBase.embeddedRows(row['product_images']);
    String? img;
    if (images.isNotEmpty) {
      img = images.first['url'] as String?;
    }
    String? subName;
    String? catName;
    final sub = row['sub_categories'];
    if (sub is Map) {
      final sm = Map<String, dynamic>.from(sub);
      subName = sm['name'] as String?;
      final cat = sm['categories'];
      if (cat is Map) {
        catName = Map<String, dynamic>.from(cat)['name'] as String?;
      }
    }
    final online = (row['online_price'] as num?)?.toDouble();
    final selling = (row['selling_price'] as num?)?.toDouble();
    final base = (row['base_price'] as num?)?.toDouble() ?? 0;
    final customerOnline = online ?? selling ?? base;

    return ShopProduct(
      id: row['id'] as String,
      subCategoryId: row['sub_category_id'] as String,
      brandId: row['brand_id'] as String?,
      sku: row['sku'] as String? ?? '',
      name: row['name'] as String? ?? '',
      description: row['description'] as String?,
      basePrice: customerOnline,
      taxClass: row['tax_class'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      qtyOnHand: qty,
      imageUrl: img,
      subCategoryName: subName,
      categoryName: catName,
      mrp: (row['mrp'] as num?)?.toDouble(),
      onlinePrice: customerOnline,
      dealerPrice: (row['dealer_price'] as num?)?.toDouble(),
    );
  }
}

class ShopProductAttribute {
  const ShopProductAttribute({
    required this.id,
    required this.productId,
    required this.attributeId,
    required this.attributeKey,
    required this.attributeLabel,
    this.valueText,
    this.valueNumber,
  });

  final String id;
  final String productId;
  final String attributeId;
  final String attributeKey;
  final String attributeLabel;
  final String? valueText;
  final double? valueNumber;

  factory ShopProductAttribute.fromRow(Map<String, dynamic> row) {
    final am = row['attribute_master'] as Map<String, dynamic>?;
    return ShopProductAttribute(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      attributeId: row['attribute_id'] as String,
      attributeKey: am?['key'] as String? ?? '',
      attributeLabel: am?['label'] as String? ?? '',
      valueText: row['value_text'] as String?,
      valueNumber: (row['value_number'] as num?)?.toDouble(),
    );
  }
}

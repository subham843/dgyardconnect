import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace_price_tier.dart';
import 'marketplace_taxonomy.dart';

/// Seller-side listing (may include fields not shown to buyers until published to catalog).
class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.sellerUid,
    required this.status,
    required this.title,
    required this.description,
    required this.proposedPricePaise,
    required this.imageUrls,
    required this.categoryId,
    this.subcategoryId = '',
    this.categoryName = '',
    this.subcategoryName = '',
    this.attributeSelections = const {},
    this.usedOtherSubcategory = false,
    this.entryCategoryId = '',
    this.entryCategoryName = '',
    this.sellerProposedFeatureDefs = const [],
    this.priceTiers = const [],
    this.stockQtyInitial,
    this.deletionRequested = false,
    this.adminSuggestedCategoryId,
    this.adminSuggestedSubcategoryId,
    this.adminSuggestedCategoryName,
    this.adminSuggestedSubcategoryName,
    this.adminSuggestedAttributeSelections = const {},
    this.catalogProductId,
    this.rejectionReason,
    this.updatedAt,
  });

  final String id;
  final String sellerUid;
  final String status;
  final String title;
  final String description;
  final int proposedPricePaise;
  final List<String> imageUrls;
  final String categoryId;
  final String subcategoryId;
  final String categoryName;
  final String subcategoryName;
  final Map<String, String> attributeSelections;
  final bool usedOtherSubcategory;
  final String entryCategoryId;
  final String entryCategoryName;
  final List<SellerProposedFeatureDef> sellerProposedFeatureDefs;
  /// Bulk / slab pricing; if empty, [proposedPricePaise] applies as single unit price.
  final List<MarketplacePriceTier> priceTiers;
  /// Starting stock proposed for catalog (null = not tracking / unlimited at publish).
  final int? stockQtyInitial;
  /// Seller asked admin to remove live catalog row.
  final bool deletionRequested;
  final String? adminSuggestedCategoryId;
  final String? adminSuggestedSubcategoryId;
  final String? adminSuggestedCategoryName;
  final String? adminSuggestedSubcategoryName;
  final Map<String, String> adminSuggestedAttributeSelections;
  final String? catalogProductId;
  final String? rejectionReason;
  final DateTime? updatedAt;

  bool get hasAdminTaxonomySuggestion {
    final c = adminSuggestedCategoryId?.trim() ?? '';
    final s = adminSuggestedSubcategoryId?.trim() ?? '';
    return c.isNotEmpty && s.isNotEmpty;
  }

  bool get usesProposedNewSubcategory => subcategoryId == kMarketplaceProposedSubcategoryId;

  static Map<String, String> _parseAttrMap(dynamic v) {
    if (v is! Map) return {};
    final out = <String, String>{};
    for (final e in v.entries) {
      out['${e.key}'] = '${e.value}';
    }
    return out;
  }

  static List<SellerProposedFeatureDef> _parseProposedDefs(dynamic v) {
    if (v is! List) return const [];
    return v.map(SellerProposedFeatureDef.fromDynamic).whereType<SellerProposedFeatureDef>().toList(growable: false);
  }

  static MarketplaceListing? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final images = data['image_urls'];
    final tiers = MarketplacePriceTier.listFromFirestore(data['price_tiers']);
    return MarketplaceListing(
      id: doc.id,
      sellerUid: (data['seller_uid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'draft',
      title: (data['title'] as String?)?.trim() ?? 'Untitled',
      description: (data['description'] as String?)?.trim() ?? '',
      proposedPricePaise: (data['proposed_price_paise'] as num?)?.toInt() ?? 0,
      imageUrls: images is List ? images.map((e) => '$e').toList(growable: false) : const [],
      categoryId: (data['category_id'] as String?) ?? 'general',
      subcategoryId: (data['subcategory_id'] as String?)?.trim() ?? '',
      categoryName: (data['category_name'] as String?)?.trim() ?? '',
      subcategoryName: (data['subcategory_name'] as String?)?.trim() ?? '',
      attributeSelections: _parseAttrMap(data['attribute_selections']),
      usedOtherSubcategory: data['used_other_subcategory'] == true,
      entryCategoryId: (data['entry_category_id'] as String?)?.trim() ?? '',
      entryCategoryName: (data['entry_category_name'] as String?)?.trim() ?? '',
      sellerProposedFeatureDefs: _parseProposedDefs(data['seller_proposed_feature_defs']),
      priceTiers: tiers,
      stockQtyInitial: (data['stock_qty_initial'] as num?)?.toInt(),
      deletionRequested: data['deletion_requested'] == true,
      adminSuggestedCategoryId: data['admin_suggested_category_id'] as String?,
      adminSuggestedSubcategoryId: data['admin_suggested_subcategory_id'] as String?,
      adminSuggestedCategoryName: data['admin_suggested_category_name'] as String?,
      adminSuggestedSubcategoryName: data['admin_suggested_subcategory_name'] as String?,
      adminSuggestedAttributeSelections: _parseAttrMap(data['admin_suggested_attribute_selections']),
      catalogProductId: data['catalog_product_id'] as String?,
      rejectionReason: data['rejection_reason'] as String?,
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }
}

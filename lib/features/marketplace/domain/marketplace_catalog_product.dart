import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace_price_tier.dart';

/// Buyer-safe catalog row (no seller PII in buyer UI; [sellerUid] for rules / seller tools).
class MarketplaceCatalogProduct {
  const MarketplaceCatalogProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.pricePaise,
    required this.imageUrls,
    required this.categoryId,
    required this.listingStatus,
    this.subcategoryId = '',
    this.categoryName = '',
    this.subcategoryName = '',
    this.attributeSelections = const {},
    this.moq = 1,
    this.priceTiers = const [],
    this.sellerUid = '',
    this.sourceListingId = '',
    this.stockQty,
    this.updatedAt,
    this.offerActive = false,
    this.offerDiscountPercent,
    this.offerPricePaise,
    this.offerEndAt,
  });

  final String id;
  final String title;
  final String description;
  final int pricePaise;
  final List<String> imageUrls;
  final String categoryId;
  final String subcategoryId;
  final String categoryName;
  final String subcategoryName;
  final Map<String, String> attributeSelections;
  final String listingStatus;
  final int moq;
  final List<MarketplacePriceTier> priceTiers;
  final String sellerUid;
  final String sourceListingId;
  /// null = not tracked (unlimited), 0 = out of stock, >0 = remaining count
  final int? stockQty;
  final DateTime? updatedAt;
  final bool offerActive;
  final int? offerDiscountPercent;
  final int? offerPricePaise;
  final DateTime? offerEndAt;

  bool get isLive => listingStatus == 'live';
  bool get isOutOfStock => listingStatus == 'out_of_stock' || (stockQty != null && stockQty! <= 0);

  int pricePaiseForQuantity(int quantity) {
    if (priceTiers.isNotEmpty) {
      return MarketplacePriceTier.pricePaiseForQuantity(priceTiers, quantity);
    }
    return pricePaise;
  }

  /// Effective unit price considering an admin offer (buyer-facing).
  ///
  /// Pricing model:
  /// - If [offerDiscountPercent] is set, it is applied on top of the base unit price.
  /// - Else if [offerPricePaise] is set, it is treated as the effective unit price at MOQ
  ///   and used as a ratio reference for all quantities.
  int effectiveUnitPaiseForQuantity(int quantity) {
    final base = pricePaiseForQuantity(quantity);
    if (!offerActive) return base;

    if (offerDiscountPercent != null) {
      final disc = offerDiscountPercent!.clamp(0, 90);
      return (base * (100 - disc) / 100).round();
    }

    if (offerPricePaise != null && offerPricePaise! > 0) {
      final baseAtMoq = pricePaiseForQuantity(moq);
      if (baseAtMoq <= 0) return base;
      final ratio = offerPricePaise! / baseAtMoq;
      return (base * ratio).round();
    }

    return base;
  }

  /// Discounted price tiers used for cart pricing when an offer is active.
  List<MarketplacePriceTier> effectivePriceTiers() {
    if (!offerActive || priceTiers.isEmpty) return priceTiers;

    if (offerDiscountPercent != null) {
      final disc = offerDiscountPercent!.clamp(0, 90);
      return priceTiers
          .map(
            (t) => MarketplacePriceTier(
              minQty: t.minQty,
              maxQty: t.maxQty,
              pricePaise: (t.pricePaise * (100 - disc) / 100).round(),
            ),
          )
          .toList(growable: false);
    }

    if (offerPricePaise != null && offerPricePaise! > 0) {
      final baseAtMoq = MarketplacePriceTier.pricePaiseForQuantity(priceTiers, moq);
      if (baseAtMoq <= 0) return priceTiers;
      final ratio = offerPricePaise! / baseAtMoq;
      return priceTiers
          .map(
            (t) => MarketplacePriceTier(
              minQty: t.minQty,
              maxQty: t.maxQty,
              pricePaise: (t.pricePaise * ratio).round(),
            ),
          )
          .toList(growable: false);
    }

    return priceTiers;
  }

  static Map<String, String> _parseAttrMap(dynamic v) {
    if (v is! Map) return {};
    final out = <String, String>{};
    for (final e in v.entries) {
      out['${e.key}'] = '${e.value}';
    }
    return out;
  }

  static MarketplaceCatalogProduct? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final images = data['image_urls'];
    final tiers = MarketplacePriceTier.listFromFirestore(data['price_tiers']);
    final stockRaw = data['stock_qty'];
    final stockQty = stockRaw == null ? null : (stockRaw as num).toInt();
    return MarketplaceCatalogProduct(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? 'Product',
      description: (data['description'] as String?)?.trim() ?? '',
      pricePaise: (data['price_paise'] as num?)?.toInt() ?? 0,
      imageUrls: images is List ? images.map((e) => '$e').toList(growable: false) : const [],
      categoryId: (data['category_id'] as String?) ?? 'general',
      subcategoryId: (data['subcategory_id'] as String?)?.trim() ?? '',
      categoryName: (data['category_name'] as String?)?.trim() ?? '',
      subcategoryName: (data['subcategory_name'] as String?)?.trim() ?? '',
      attributeSelections: _parseAttrMap(data['attribute_selections']),
      listingStatus: (data['listing_status'] as String?) ?? 'draft',
      moq: (data['moq'] as num?)?.toInt() ?? 1,
      priceTiers: tiers,
      sellerUid: (data['seller_uid'] as String?)?.trim() ?? '',
      sourceListingId: (data['source_listing_id'] as String?)?.trim() ?? '',
      stockQty: stockQty,
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      offerActive: (data['offer_active'] as bool?) ?? false,
      offerDiscountPercent: (data['offer_discount_percent'] as num?)?.toInt(),
      offerPricePaise: (data['offer_price_paise'] as num?)?.toInt(),
      offerEndAt: (data['offer_end_at'] as Timestamp?)?.toDate(),
    );
  }
}

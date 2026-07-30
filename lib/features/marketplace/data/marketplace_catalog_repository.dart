import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/services/firestore_service.dart';
import '../domain/marketplace_catalog_product.dart';

class MarketplaceCatalogRepository {
  static int _fetchLimitForBuyer(int limit, String? excludeSellerUid) {
    if (excludeSellerUid == null || excludeSellerUid.isEmpty) return limit;
    return (limit * 2).clamp(limit, 240);
  }

  static List<MarketplaceCatalogProduct> _withoutSeller(
    List<MarketplaceCatalogProduct> list,
    String? excludeSellerUid,
    int maxItems,
  ) {
    if (excludeSellerUid == null || excludeSellerUid.isEmpty) {
      if (list.length <= maxItems) return list;
      return list.sublist(0, maxItems);
    }
    final filtered = list.where((p) => p.sellerUid != excludeSellerUid).take(maxItems).toList(growable: false);
    return filtered;
  }

  /// Buyer catalog. Pass [excludeSellerUid] so a seller does not see their own listings when shopping.
  Stream<List<MarketplaceCatalogProduct>> watchLiveProducts({
    int limit = 48,
    String? excludeSellerUid,
  }) {
    if (!FirestoreService.isAvailable) {
      return Stream.value(const []);
    }
    final fetch = _fetchLimitForBuyer(limit, excludeSellerUid);
    return FirestoreService.marketplaceCatalog()
        .where('listing_status', isEqualTo: 'live')
        .orderBy('updated_at', descending: true)
        .limit(fetch)
        .snapshots()
        .map((snap) {
      final parsed = snap.docs
          .map(MarketplaceCatalogProduct.fromDoc)
          .whereType<MarketplaceCatalogProduct>()
          .toList(growable: false);
      return _withoutSeller(parsed, excludeSellerUid, limit);
    });
  }

  /// Offer-active products for buyer shopping.
  ///
  /// Requires catalog docs to have `offer_active == true`.
  Stream<List<MarketplaceCatalogProduct>> watchOfferProducts({
    int limit = 24,
    String? excludeSellerUid,
  }) {
    if (!FirestoreService.isAvailable) {
      return Stream.value(const []);
    }
    final fetch = _fetchLimitForBuyer(limit, excludeSellerUid);
    return FirestoreService.marketplaceCatalog()
        .where('listing_status', isEqualTo: 'live')
        .where('offer_active', isEqualTo: true)
        .orderBy('updated_at', descending: true)
        .limit(fetch)
        .snapshots()
        .map((snap) {
      final parsed = snap.docs
          .map(MarketplaceCatalogProduct.fromDoc)
          .whereType<MarketplaceCatalogProduct>()
          .toList(growable: false);
      return _withoutSeller(parsed, excludeSellerUid, limit);
    });
  }

  /// Live products in one category (requires composite index).
  Stream<List<MarketplaceCatalogProduct>> watchLiveProductsByCategory(
    String categoryId, {
    int limit = 48,
    String? excludeSellerUid,
  }) {
    if (!FirestoreService.isAvailable || categoryId.isEmpty) {
      return Stream.value(const []);
    }
    final fetch = _fetchLimitForBuyer(limit, excludeSellerUid);
    return FirestoreService.marketplaceCatalog()
        .where('listing_status', isEqualTo: 'live')
        .where('category_id', isEqualTo: categoryId)
        .orderBy('updated_at', descending: true)
        .limit(fetch)
        .snapshots()
        .map((snap) {
      final parsed = snap.docs
          .map(MarketplaceCatalogProduct.fromDoc)
          .whereType<MarketplaceCatalogProduct>()
          .toList(growable: false);
      return _withoutSeller(parsed, excludeSellerUid, limit);
    });
  }

  /// Single read for buyer product screen: distinguishes missing vs own listing.
  Future<BuyerCatalogProductResult> loadProductForBuyer(String productId, String? viewerUid) async {
    if (!FirestoreService.isAvailable) {
      return BuyerCatalogProductResult(product: null, isOwnListing: false);
    }
    final doc = await FirestoreService.marketplaceCatalog().doc(productId).get();
    final p = MarketplaceCatalogProduct.fromDoc(doc);
    if (p == null) {
      return BuyerCatalogProductResult(product: null, isOwnListing: false);
    }
    if (p.listingStatus != 'live' && p.listingStatus != 'out_of_stock') {
      return BuyerCatalogProductResult(product: null, isOwnListing: false);
    }
    final v = viewerUid?.trim() ?? '';
    if (v.isNotEmpty && p.sellerUid.isNotEmpty && p.sellerUid == v) {
      return BuyerCatalogProductResult(product: null, isOwnListing: true);
    }
    return BuyerCatalogProductResult(product: p, isOwnListing: false);
  }

  /// [viewerUid]: when set and the row is that seller's product, returns null (cannot buy own listing).
  Future<MarketplaceCatalogProduct?> getProduct(String productId, {String? viewerUid}) async {
    final r = await loadProductForBuyer(productId, viewerUid);
    return r.product;
  }

  /// Seller tooling: read catalog row if owned by [sellerUid] (any listing_status).
  Future<MarketplaceCatalogProduct?> getProductIfOwnedBySeller(String productId, String sellerUid) async {
    if (!FirestoreService.isAvailable || sellerUid.isEmpty) return null;
    final doc = await FirestoreService.marketplaceCatalog().doc(productId).get();
    final p = MarketplaceCatalogProduct.fromDoc(doc);
    if (p == null || p.sellerUid != sellerUid) return null;
    return p;
  }

  /// Allowed fields for seller per Firestore rules: stock, availability, updated_at.
  Future<void> sellerPatchCatalog({
    required String catalogProductId,
    required String sellerUid,
    String? listingStatus,
    int? stockQty,
    bool clearStockQty = false,
  }) async {
    if (!FirestoreService.isAvailable) return;
    final doc = await FirestoreService.marketplaceCatalog().doc(catalogProductId).get();
    final p = MarketplaceCatalogProduct.fromDoc(doc);
    if (p == null || p.sellerUid != sellerUid) {
      throw StateError('Not allowed to update this product');
    }
    final patch = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (listingStatus != null) {
      patch['listing_status'] = listingStatus;
    }
    if (clearStockQty) {
      patch['stock_qty'] = FieldValue.delete();
    } else if (stockQty != null) {
      patch['stock_qty'] = stockQty;
    }
    await FirestoreService.marketplaceCatalog().doc(catalogProductId).update(patch);
  }

  Future<MarketplaceCatalogProduct?> getProductForAdmin(String productId) async {
    if (!FirestoreService.isAvailable) return null;
    final doc = await FirestoreService.marketplaceCatalog().doc(productId).get();
    return MarketplaceCatalogProduct.fromDoc(doc);
  }

  /// Superadmin: all catalog rows (any status) for moderation UI.
  Stream<List<MarketplaceCatalogProduct>> watchAllForAdmin({int limit = 400}) {
    if (!FirestoreService.isAvailable) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceCatalog()
        .orderBy('updated_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(MarketplaceCatalogProduct.fromDoc)
            .whereType<MarketplaceCatalogProduct>()
            .toList(growable: false));
  }
}

/// Result of [MarketplaceCatalogRepository.loadProductForBuyer].
class BuyerCatalogProductResult {
  const BuyerCatalogProductResult({required this.product, required this.isOwnListing});

  final MarketplaceCatalogProduct? product;
  final bool isOwnListing;
}

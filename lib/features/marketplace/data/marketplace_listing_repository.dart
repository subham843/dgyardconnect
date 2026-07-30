import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/services/firestore_service.dart';
import '../domain/marketplace_listing.dart';
import '../domain/marketplace_price_tier.dart';
import '../domain/marketplace_taxonomy.dart';

class MarketplaceListingRepository {
  Stream<List<MarketplaceListing>> watchForSeller(String sellerUid, {int limit = 64}) {
    if (!FirestoreService.isAvailable || sellerUid.isEmpty) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceListings()
        .where('seller_uid', isEqualTo: sellerUid)
        .orderBy('updated_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(MarketplaceListing.fromDoc)
            .whereType<MarketplaceListing>()
            .toList(growable: false));
  }

  Stream<List<MarketplaceListing>> watchPendingReview({int limit = 80}) {
    if (!FirestoreService.isAvailable) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceListings()
        .where('status', isEqualTo: 'pending_review')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(MarketplaceListing.fromDoc)
            .whereType<MarketplaceListing>()
            .toList(growable: false));
  }

  Future<String> createDraftListing({
    required String sellerUid,
    required String title,
    required String description,
    required int proposedPricePaise,
    String categoryId = 'general',
    String subcategoryId = '',
    String categoryName = '',
    String subcategoryName = '',
    Map<String, String> attributeSelections = const {},
    bool usedOtherSubcategory = false,
    String entryCategoryId = '',
    String entryCategoryName = '',
    List<Map<String, dynamic>> sellerProposedFeatureDefs = const [],
    List<MarketplacePriceTier> priceTiers = const [],
    int? stockQtyInitial,
  }) async {
    if (!FirestoreService.isAvailable) throw StateError('Firestore unavailable');
    final ref = FirestoreService.marketplaceListings().doc();
    final data = <String, dynamic>{
      'seller_uid': sellerUid,
      'status': 'draft',
      'title': title,
      'description': description,
      'proposed_price_paise': proposedPricePaise,
      'price_tiers': MarketplacePriceTier.listToFirestore(priceTiers),
      'image_urls': <String>[],
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'category_name': categoryName,
      'subcategory_name': subcategoryName,
      'attribute_selections': attributeSelections,
      'used_other_subcategory': usedOtherSubcategory,
      'entry_category_id': entryCategoryId,
      'entry_category_name': entryCategoryName,
      'deletion_requested': false,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (stockQtyInitial != null) {
      data['stock_qty_initial'] = stockQtyInitial;
    }
    if (subcategoryId == kMarketplaceProposedSubcategoryId) {
      data['seller_proposed_feature_defs'] = sellerProposedFeatureDefs;
    }
    await ref.set(data);
    return ref.id;
  }

  Future<void> submitForReview(String listingId) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceListings().doc(listingId).update({
      'status': 'pending_review',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDraft({
    required String listingId,
    required String title,
    required String description,
    required int proposedPricePaise,
    String categoryId = 'general',
    String subcategoryId = '',
    String categoryName = '',
    String subcategoryName = '',
    Map<String, String> attributeSelections = const {},
    bool usedOtherSubcategory = false,
    String entryCategoryId = '',
    String entryCategoryName = '',
    List<Map<String, dynamic>> sellerProposedFeatureDefs = const [],
    List<MarketplacePriceTier> priceTiers = const [],
    int? stockQtyInitial,
    bool clearAdminSuggestions = false,
    String? nextStatus,
    bool? deletionRequested,
  }) async {
    if (!FirestoreService.isAvailable) return;
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'proposed_price_paise': proposedPricePaise,
      'price_tiers': MarketplacePriceTier.listToFirestore(priceTiers),
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'category_name': categoryName,
      'subcategory_name': subcategoryName,
      'attribute_selections': attributeSelections,
      'used_other_subcategory': usedOtherSubcategory,
      'entry_category_id': entryCategoryId,
      'entry_category_name': entryCategoryName,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (stockQtyInitial != null) {
      payload['stock_qty_initial'] = stockQtyInitial;
    } else {
      payload['stock_qty_initial'] = FieldValue.delete();
    }
    if (subcategoryId == kMarketplaceProposedSubcategoryId) {
      payload['seller_proposed_feature_defs'] = sellerProposedFeatureDefs;
    } else {
      payload['seller_proposed_feature_defs'] = FieldValue.delete();
    }
    if (clearAdminSuggestions) {
      payload['admin_suggested_category_id'] = FieldValue.delete();
      payload['admin_suggested_subcategory_id'] = FieldValue.delete();
      payload['admin_suggested_category_name'] = FieldValue.delete();
      payload['admin_suggested_subcategory_name'] = FieldValue.delete();
      payload['admin_suggested_attribute_selections'] = FieldValue.delete();
    }
    if (nextStatus != null) {
      payload['status'] = nextStatus;
    }
    if (deletionRequested != null) {
      payload['deletion_requested'] = deletionRequested;
    }
    await FirestoreService.marketplaceListings().doc(listingId).update(payload);
  }

  /// Clears admin suggestion fields after seller applies them (or dismisses).
  Future<void> clearAdminTaxonomySuggestions(String listingId) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceListings().doc(listingId).update({
      'admin_suggested_category_id': FieldValue.delete(),
      'admin_suggested_subcategory_id': FieldValue.delete(),
      'admin_suggested_category_name': FieldValue.delete(),
      'admin_suggested_subcategory_name': FieldValue.delete(),
      'admin_suggested_attribute_selections': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<MarketplaceListing?> getListing(String listingId) async {
    if (!FirestoreService.isAvailable) return null;
    final doc = await FirestoreService.marketplaceListings().doc(listingId).get();
    return MarketplaceListing.fromDoc(doc);
  }

  Future<void> updateListingImages(String listingId, List<String> imageUrls) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceListings().doc(listingId).update({
      'image_urls': imageUrls,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Published listing: ask admin to remove the live catalog row.
  Future<void> requestCatalogDeletionReview(String listingId) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceListings().doc(listingId).update({
      'status': 'pending_review',
      'deletion_requested': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}

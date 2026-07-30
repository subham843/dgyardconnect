import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/storage_service.dart';
import '../domain/marketplace_catalog_product.dart';
import '../domain/marketplace_listing.dart';
import '../domain/marketplace_price_tier.dart';

/// Superadmin-only flows (enforced by Firestore rules). Prefer Cloud Functions for production hardening.
class MarketplaceAdminActions {
  MarketplaceAdminActions._();

  static List<MarketplacePriceTier> _scaledTiersForCatalog(
    List<MarketplacePriceTier> tiers,
    int proposedPricePaise,
    int finalBuyerPricePaise,
  ) {
    if (tiers.isEmpty) return const [];
    final refUnit = tiers.first.pricePaise > 0
        ? tiers.first.pricePaise
        : (proposedPricePaise > 0 ? proposedPricePaise : 1);
    final ratio = finalBuyerPricePaise / refUnit;
    return tiers
        .map(
          (t) => MarketplacePriceTier(
            minQty: t.minQty,
            maxQty: t.maxQty,
            pricePaise: (t.pricePaise * ratio).round(),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> _publishedListingCleanup() => {
        'status': 'published',
        'rejection_reason': FieldValue.delete(),
        'admin_suggested_category_id': FieldValue.delete(),
        'admin_suggested_subcategory_id': FieldValue.delete(),
        'admin_suggested_category_name': FieldValue.delete(),
        'admin_suggested_subcategory_name': FieldValue.delete(),
        'admin_suggested_attribute_selections': FieldValue.delete(),
        'seller_proposed_feature_defs': FieldValue.delete(),
        'deletion_requested': false,
        'updated_at': FieldValue.serverTimestamp(),
      };

  /// Creates real subcategory + attribute docs from seller proposal, updates listing document.
  static Future<MarketplaceListing> _materializeProposedTaxonomy(MarketplaceListing listing) async {
    if (!FirestoreService.isAvailable) throw StateError('Firestore unavailable');
    if (!listing.usesProposedNewSubcategory) return listing;
    final name = listing.subcategoryName.trim();
    if (name.isEmpty) throw StateError('Proposed subcategory name missing');
    final catId = listing.categoryId.trim();
    if (catId.isEmpty) throw StateError('Category missing');

    final batch = FirebaseFirestore.instance.batch();
    final listRef = FirestoreService.marketplaceListings().doc(listing.id);
    final subRef = FirestoreService.marketplaceSubcategories(catId).doc();
    batch.set(subRef, {
      'name': name,
      'sort_order': 999,
      'active': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
    var i = 0;
    for (final def in listing.sellerProposedFeatureDefs) {
      final aRef = FirestoreService.marketplaceCategoryAttributes(catId, subRef.id).doc();
      batch.set(aRef, {
        'key': def.key,
        'label': def.label,
        'values': def.values,
        'free_text': def.usesTextInput,
        if (def.scanQrBarcode) 'scan_qr_barcode': true,
        'sort_order': i++,
        'required': true,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    batch.update(listRef, {
      'subcategory_id': subRef.id,
      'seller_proposed_feature_defs': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    final snap = await listRef.get();
    final updated = MarketplaceListing.fromDoc(snap);
    if (updated == null) throw StateError('Listing missing after taxonomy create');
    return updated;
  }

  /// Approve new listing, update existing catalog row, or remove catalog when [MarketplaceListing.deletionRequested].
  static Future<String> publishListingToCatalog({
    required MarketplaceListing listing,
    required int finalBuyerPricePaise,
    int moq = 1,
  }) async {
    if (!FirestoreService.isAvailable) throw StateError('Firestore unavailable');

    if (listing.deletionRequested) {
      final cid = (listing.catalogProductId ?? '').trim();
      if (cid.isEmpty) throw StateError('Missing catalog product for deletion');
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(FirestoreService.marketplaceCatalog().doc(cid));
      batch.update(FirestoreService.marketplaceListings().doc(listing.id), {
        'status': 'archived',
        'catalog_product_id': FieldValue.delete(),
        'deletion_requested': false,
        'rejection_reason': FieldValue.delete(),
        'admin_suggested_category_id': FieldValue.delete(),
        'admin_suggested_subcategory_id': FieldValue.delete(),
        'admin_suggested_category_name': FieldValue.delete(),
        'admin_suggested_subcategory_name': FieldValue.delete(),
        'admin_suggested_attribute_selections': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return cid;
    }

    var effective = listing;
    if (listing.usesProposedNewSubcategory && (listing.catalogProductId ?? '').trim().isEmpty) {
      effective = await _materializeProposedTaxonomy(listing);
    }

    final scaledTiers = _scaledTiersForCatalog(effective.priceTiers, effective.proposedPricePaise, finalBuyerPricePaise);
    final stock = effective.stockQtyInitial;
    final listRef = FirestoreService.marketplaceListings().doc(effective.id);
    final batch = FirebaseFirestore.instance.batch();

    final existingCatalogId = (effective.catalogProductId ?? '').trim();
    if (existingCatalogId.isNotEmpty) {
      final catRef = FirestoreService.marketplaceCatalog().doc(existingCatalogId);
      final update = <String, dynamic>{
        'title': effective.title,
        'description': effective.description,
        'price_paise': finalBuyerPricePaise,
        'price_tiers': MarketplacePriceTier.listToFirestore(scaledTiers),
        'image_urls': effective.imageUrls,
        'category_id': effective.categoryId,
        'subcategory_id': effective.subcategoryId,
        'category_name': effective.categoryName,
        'subcategory_name': effective.subcategoryName,
        'attribute_selections': effective.attributeSelections,
        'listing_status': 'live',
        'moq': moq,
        'seller_uid': effective.sellerUid,
        'source_listing_id': effective.id,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (stock != null) {
        update['stock_qty'] = stock;
      }
      batch.update(catRef, update);
      batch.update(listRef, _publishedListingCleanup());
      await batch.commit();
      return existingCatalogId;
    }

    final catRef = FirestoreService.marketplaceCatalog().doc();
    final create = <String, dynamic>{
      'title': effective.title,
      'description': effective.description,
      'price_paise': finalBuyerPricePaise,
      'price_tiers': MarketplacePriceTier.listToFirestore(scaledTiers),
      'image_urls': effective.imageUrls,
      'category_id': effective.categoryId,
      'subcategory_id': effective.subcategoryId,
      'category_name': effective.categoryName,
      'subcategory_name': effective.subcategoryName,
      'attribute_selections': effective.attributeSelections,
      'listing_status': 'live',
      'moq': moq,
      'seller_uid': effective.sellerUid,
      'source_listing_id': effective.id,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (stock != null) {
      create['stock_qty'] = stock;
    }
    batch.set(catRef, create);
    batch.update(listRef, {
      ..._publishedListingCleanup(),
      'catalog_product_id': catRef.id,
    });
    await batch.commit();
    return catRef.id;
  }

  /// Rejects a pending listing. New submissions: clears images and Storage folder. Live-catalog edits: restores [published].
  static Future<void> rejectListing({
    required String listingId,
    required String reason,
    String? suggestedCategoryId,
    String? suggestedSubcategoryId,
    String? suggestedCategoryName,
    String? suggestedSubcategoryName,
    Map<String, String>? suggestedAttributeSelections,
  }) async {
    if (!FirestoreService.isAvailable) return;
    final snap = await FirestoreService.marketplaceListings().doc(listingId).get();
    final listing = MarketplaceListing.fromDoc(snap);
    if (listing == null) return;

    final catalogId = (listing.catalogProductId ?? '').trim();
    final softReject = listing.status == 'pending_review' && catalogId.isNotEmpty;

    if (!softReject) {
      await StorageService.deleteMarketplaceListingFolder(
        userId: listing.sellerUid,
        listingId: listingId,
      );
    }

    final payload = <String, dynamic>{
      'rejection_reason': reason,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (softReject) {
      payload['status'] = 'published';
      payload['deletion_requested'] = false;
    } else {
      payload['status'] = 'rejected';
      payload['image_urls'] = <String>[];
    }

    final sugCat = (suggestedCategoryId ?? '').trim();
    final sugSub = (suggestedSubcategoryId ?? '').trim();
    final hasSuggestion = sugCat.isNotEmpty && sugSub.isNotEmpty;
    if (hasSuggestion) {
      payload['admin_suggested_category_id'] = sugCat;
      payload['admin_suggested_subcategory_id'] = sugSub;
      payload['admin_suggested_category_name'] = (suggestedCategoryName ?? '').trim();
      payload['admin_suggested_subcategory_name'] = (suggestedSubcategoryName ?? '').trim();
      payload['admin_suggested_attribute_selections'] =
          suggestedAttributeSelections == null || suggestedAttributeSelections.isEmpty
              ? FieldValue.delete()
              : suggestedAttributeSelections;
    } else {
      payload['admin_suggested_category_id'] = FieldValue.delete();
      payload['admin_suggested_subcategory_id'] = FieldValue.delete();
      payload['admin_suggested_category_name'] = FieldValue.delete();
      payload['admin_suggested_subcategory_name'] = FieldValue.delete();
      payload['admin_suggested_attribute_selections'] = FieldValue.delete();
    }
    await FirestoreService.marketplaceListings().doc(listingId).update(payload);
  }

  /// Desk edit of a live catalog row (superadmin; rules allow full update).
  static Future<void> adminUpdateCatalogProduct({
    required String catalogProductId,
    required String title,
    required String description,
    required int pricePaise,
    required int moq,
    required String listingStatus,
    int? stockQty,
    bool clearStockQty = false,
    required bool offerActive,
    int? offerDiscountPercent,
    int? offerPricePaise,
  }) async {
    if (!FirestoreService.isAvailable) throw StateError('Firestore unavailable');
    final patch = <String, dynamic>{
      'title': title,
      'description': description,
      'price_paise': pricePaise,
      'moq': moq,
      'listing_status': listingStatus,
      'offer_active': offerActive,
      if (offerDiscountPercent == null)
        'offer_discount_percent': FieldValue.delete()
      else
        'offer_discount_percent': offerDiscountPercent,
      if (offerPricePaise == null)
        'offer_price_paise': FieldValue.delete()
      else
        'offer_price_paise': offerPricePaise,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (clearStockQty) {
      patch['stock_qty'] = FieldValue.delete();
    } else if (stockQty != null) {
      patch['stock_qty'] = stockQty;
    }
    await FirestoreService.marketplaceCatalog().doc(catalogProductId).update(patch);
  }

  /// Removes catalog doc and archives linked seller listing when [source_listing_id] is set.
  static Future<void> deleteCatalogProductAndUnlinkListing(String catalogProductId) async {
    if (!FirestoreService.isAvailable) return;
    final catRef = FirestoreService.marketplaceCatalog().doc(catalogProductId);
    final snap = await catRef.get();
    final p = MarketplaceCatalogProduct.fromDoc(snap);
    if (p == null) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(catRef);
    final sid = p.sourceListingId.trim();
    if (sid.isNotEmpty) {
      batch.update(FirestoreService.marketplaceListings().doc(sid), {
        'catalog_product_id': FieldValue.delete(),
        'status': 'archived',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<void> logAudit({
    required String actorUid,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceAuditLogs().add({
      'actor_uid': actorUid,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'payload': payload,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}

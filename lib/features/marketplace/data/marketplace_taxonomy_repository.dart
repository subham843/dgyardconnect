import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/services/firestore_service.dart';
import '../domain/marketplace_taxonomy.dart';

class MarketplaceTaxonomyRepository {
  Stream<List<MarketplaceCategoryNode>> watchCategories({bool activeOnly = true}) {
    if (!FirestoreService.isAvailable) return Stream.value(const []);
    Query<Map<String, dynamic>> q = FirestoreService.marketplaceCategories().orderBy('sort_order');
    return q.snapshots().map((snap) {
      final list = snap.docs.map(MarketplaceCategoryNode.fromDoc).whereType<MarketplaceCategoryNode>().toList();
      if (activeOnly) {
        return list.where((c) => c.active).toList(growable: false);
      }
      return list;
    });
  }

  /// Admin: all categories including inactive.
  Stream<List<MarketplaceCategoryNode>> watchCategoriesForAdmin() {
    if (!FirestoreService.isAvailable) return Stream.value(const []);
    return FirestoreService.marketplaceCategories().orderBy('sort_order').snapshots().map((snap) => snap.docs
        .map(MarketplaceCategoryNode.fromDoc)
        .whereType<MarketplaceCategoryNode>()
        .toList(growable: false));
  }

  Stream<List<MarketplaceSubcategoryNode>> watchSubcategories(String categoryId, {bool activeOnly = true}) {
    if (!FirestoreService.isAvailable || categoryId.isEmpty) return Stream.value(const []);
    return FirestoreService.marketplaceSubcategories(categoryId).orderBy('sort_order').snapshots().map((snap) {
      final list =
          snap.docs.map(MarketplaceSubcategoryNode.fromDoc).whereType<MarketplaceSubcategoryNode>().toList();
      if (activeOnly) {
        return list.where((s) => s.active).toList(growable: false);
      }
      return list;
    });
  }

  Stream<List<MarketplaceAttributeDef>> watchAttributes(String categoryId, String subcategoryId) {
    if (!FirestoreService.isAvailable || categoryId.isEmpty || subcategoryId.isEmpty) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceCategoryAttributes(categoryId, subcategoryId)
        .orderBy('sort_order')
        .snapshots()
        .map((snap) => snap.docs
            .map(MarketplaceAttributeDef.fromDoc)
            .whereType<MarketplaceAttributeDef>()
            .toList(growable: false));
  }

  Future<void> createCategory({required String name, int sortOrder = 0}) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceCategories().add({
      'name': name.trim(),
      'sort_order': sortOrder,
      'active': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setCategoryActive(String categoryId, bool active) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceCategories().doc(categoryId).update({
      'active': active,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory(String categoryId, {required String name, int? sortOrder}) async {
    if (!FirestoreService.isAvailable || categoryId.isEmpty) return;
    final payload = <String, dynamic>{
      'name': name.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    await FirestoreService.marketplaceCategories().doc(categoryId).update(payload);
  }

  Future<void> createSubcategory({
    required String categoryId,
    required String name,
    int sortOrder = 0,
  }) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceSubcategories(categoryId).add({
      'name': name.trim(),
      'sort_order': sortOrder,
      'active': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setSubcategoryActive(String categoryId, String subcategoryId, bool active) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceSubcategories(categoryId).doc(subcategoryId).update({
      'active': active,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSubcategory(
    String categoryId,
    String subcategoryId, {
    required String name,
    int? sortOrder,
  }) async {
    if (!FirestoreService.isAvailable || categoryId.isEmpty || subcategoryId.isEmpty) return;
    final payload = <String, dynamic>{
      'name': name.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    await FirestoreService.marketplaceSubcategories(categoryId).doc(subcategoryId).update(payload);
  }

  Future<void> createAttribute({
    required String categoryId,
    required String subcategoryId,
    required String key,
    required String label,
    required List<String> values,
    int sortOrder = 0,
    bool required = true,
    bool scanQrBarcode = false,
  }) async {
    if (!FirestoreService.isAvailable) return;
    final payload = <String, dynamic>{
      'key': key.trim(),
      'label': label.trim(),
      'values': values,
      'free_text': values.isEmpty,
      'sort_order': sortOrder,
      'required': required,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (values.isEmpty && scanQrBarcode) {
      payload['scan_qr_barcode'] = true;
    }
    await FirestoreService.marketplaceCategoryAttributes(categoryId, subcategoryId).add(payload);
  }

  Future<void> deleteAttribute(String categoryId, String subcategoryId, String attributeId) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceCategoryAttributes(categoryId, subcategoryId).doc(attributeId).delete();
  }

  /// Key is not updated (would break existing listing attribute_selections maps).
  Future<void> updateAttribute(
    String categoryId,
    String subcategoryId,
    String attributeId, {
    required String label,
    required List<String> values,
    required bool isRequired,
    int? sortOrder,
    required bool scanQrBarcode,
  }) async {
    if (!FirestoreService.isAvailable || categoryId.isEmpty || subcategoryId.isEmpty || attributeId.isEmpty) {
      return;
    }
    final payload = <String, dynamic>{
      'label': label.trim(),
      'values': values,
      'free_text': values.isEmpty,
      'required': isRequired,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (values.isEmpty && scanQrBarcode) {
      payload['scan_qr_barcode'] = true;
    } else {
      payload['scan_qr_barcode'] = FieldValue.delete();
    }
    await FirestoreService.marketplaceCategoryAttributes(categoryId, subcategoryId).doc(attributeId).update(payload);
  }
}

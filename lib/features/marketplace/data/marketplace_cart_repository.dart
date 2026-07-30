import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/services/firestore_service.dart';
import '../domain/marketplace_cart_item.dart';

class MarketplaceCartRepository {
  Stream<List<MarketplaceCartItem>> watchCart(String uid) {
    if (!FirestoreService.isAvailable || uid.isEmpty) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceCartItems(uid).snapshots().map((snap) {
      return snap.docs
          .map(MarketplaceCartItem.fromDoc)
          .whereType<MarketplaceCartItem>()
          .toList(growable: false);
    });
  }

  Future<void> upsertItem({
    required String uid,
    required MarketplaceCartItem item,
  }) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceCartItems(uid).doc(item.id).set(item.toWriteMap(), SetOptions(merge: true));
    await FirestoreService.marketplaceCartRoot(uid).set({
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setQuantity({
    required String uid,
    required String itemDocId,
    required int quantity,
    int? pricePaiseSnapshot,
  }) async {
    if (!FirestoreService.isAvailable) return;
    if (quantity <= 0) {
      await removeItem(uid: uid, itemDocId: itemDocId);
      return;
    }
    final patch = <String, dynamic>{
      'quantity': quantity,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (pricePaiseSnapshot != null) {
      patch['price_paise_snapshot'] = pricePaiseSnapshot;
    }
    await FirestoreService.marketplaceCartItems(uid).doc(itemDocId).update(patch);
  }

  Future<void> removeItem({
    required String uid,
    required String itemDocId,
  }) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.marketplaceCartItems(uid).doc(itemDocId).delete();
  }

  Future<void> clearCart(String uid) async {
    if (!FirestoreService.isAvailable) return;
    final batch = FirebaseFirestore.instance.batch();
    final items = await FirestoreService.marketplaceCartItems(uid).get();
    for (final d in items.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}

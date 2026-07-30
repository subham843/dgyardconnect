import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/services/firestore_service.dart';
import '../domain/marketplace_cart_item.dart';
import '../domain/marketplace_order_summary.dart';

class MarketplaceOrderRepository {
  Stream<List<MarketplaceOrderSummary>> watchBuyerOrders(String buyerUid, {int limit = 40}) {
    if (!FirestoreService.isAvailable || buyerUid.isEmpty) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceOrders()
        .where('buyer_uid', isEqualTo: buyerUid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(MarketplaceOrderSummary.fromDoc)
            .whereType<MarketplaceOrderSummary>()
            .toList(growable: false));
  }

  Stream<List<MarketplaceOrderSummary>> watchAllOrdersForAdmin({int limit = 80}) {
    if (!FirestoreService.isAvailable) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceOrders()
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(MarketplaceOrderSummary.fromDoc)
            .whereType<MarketplaceOrderSummary>()
            .toList(growable: false));
  }

  /// Client-side order creation is disabled — use [MarketplaceCheckoutService] + Cloud Functions.
  @Deprecated('Use MarketplaceCheckoutService and marketplacePlaceCodOrder / marketplaceCreateRazorpayCheckout')
  Future<String> placeOrderFromCart({
    required List<MarketplaceCartItem> lines,
    required String paymentMethod,
  }) async {
    throw UnsupportedError(
      'Marketplace orders must be created via Cloud Functions (checkout service).',
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getOrderDoc(String orderId) async {
    if (!FirestoreService.isAvailable) return null;
    final doc = await FirestoreService.marketplaceOrders().doc(orderId).get();
    if (!doc.exists) return null;
    return doc;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getOrderLines(String orderId) async {
    if (!FirestoreService.isAvailable) return const [];
    final q = await FirestoreService.marketplaceOrderLines(orderId).get();
    return q.docs;
  }
}

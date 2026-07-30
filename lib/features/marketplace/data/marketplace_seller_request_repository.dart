import '../../../shared/services/firestore_service.dart';
import '../domain/marketplace_seller_order_request.dart';

class MarketplaceSellerRequestRepository {
  Stream<List<MarketplaceSellerOrderRequest>> watchForSeller(String sellerUid, {int limit = 48}) {
    if (!FirestoreService.isAvailable || sellerUid.isEmpty) {
      return Stream.value(const []);
    }
    return FirestoreService.marketplaceSellerOrderRequests()
        .where('seller_uid', isEqualTo: sellerUid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(MarketplaceSellerOrderRequest.fromDoc)
            .whereType<MarketplaceSellerOrderRequest>()
            .toList(growable: false));
  }

  Future<MarketplaceSellerOrderRequest?> getRequest(String requestId) async {
    if (!FirestoreService.isAvailable) return null;
    final doc = await FirestoreService.marketplaceSellerOrderRequests().doc(requestId).get();
    return MarketplaceSellerOrderRequest.fromDoc(doc);
  }
}

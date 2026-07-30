import 'package:cloud_firestore/cloud_firestore.dart';

/// Seller-facing row for one order line (no buyer PII).
class MarketplaceSellerOrderRequest {
  const MarketplaceSellerOrderRequest({
    required this.id,
    required this.orderId,
    required this.lineId,
    required this.catalogProductId,
    required this.titleSnapshot,
    required this.quantity,
    required this.unitPricePaise,
    required this.lineTotalPaise,
    required this.sellerUid,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String lineId;
  final String catalogProductId;
  final String titleSnapshot;
  final int quantity;
  final int unitPricePaise;
  final int lineTotalPaise;
  final String sellerUid;
  final String status;
  final DateTime? createdAt;

  static MarketplaceSellerOrderRequest? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return MarketplaceSellerOrderRequest(
      id: doc.id,
      orderId: (data['order_id'] as String?) ?? '',
      lineId: (data['line_id'] as String?) ?? '',
      catalogProductId: (data['catalog_product_id'] as String?) ?? '',
      titleSnapshot: (data['title_snapshot'] as String?)?.trim() ?? 'Item',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitPricePaise: (data['unit_price_paise'] as num?)?.toInt() ?? 0,
      lineTotalPaise: (data['line_total_paise'] as num?)?.toInt() ?? 0,
      sellerUid: (data['seller_uid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'open',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

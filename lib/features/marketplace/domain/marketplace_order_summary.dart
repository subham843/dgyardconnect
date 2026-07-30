import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceOrderSummary {
  const MarketplaceOrderSummary({
    required this.id,
    required this.buyerUid,
    required this.status,
    required this.totalPaise,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String buyerUid;
  final String status;
  final int totalPaise;
  final String paymentMethod;
  final DateTime? createdAt;

  static MarketplaceOrderSummary? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return MarketplaceOrderSummary(
      id: doc.id,
      buyerUid: (data['buyer_uid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'created',
      totalPaise: (data['total_paise'] as num?)?.toInt() ?? 0,
      paymentMethod: (data['payment_method'] as String?) ?? 'unknown',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

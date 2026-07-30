import 'shop_product.dart';

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.firebaseUid,
    required this.status,
    required this.subtotal,
    required this.totalAmount,
    required this.createdAt,
    this.shippingAddress,
  });

  final String id;
  final String firebaseUid;
  final String status;
  final double subtotal;
  final double totalAmount;
  final DateTime? createdAt;
  final Map<String, dynamic>? shippingAddress;

  factory ShopOrder.fromRow(Map<String, dynamic> row) {
    return ShopOrder(
      id: row['id'] as String,
      firebaseUid: row['firebase_uid'] as String? ?? '',
      status: row['status'] as String? ?? 'draft',
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) : null,
      shippingAddress: row['shipping_address'] is Map
          ? Map<String, dynamic>.from(row['shipping_address'] as Map)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending_payment':
        return 'Pending payment';
      case 'paid':
        return 'Paid';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
  }
}

class ShopOrderLineItem {
  const ShopOrderLineItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
  });

  final String id;
  final String productId;
  final String productName;
  final String sku;
  final double unitPrice;
  final int qty;
  final double lineTotal;

  factory ShopOrderLineItem.fromRow(Map<String, dynamic> row) {
    return ShopOrderLineItem(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      productName: row['product_name'] as String? ?? 'Product',
      sku: row['sku'] as String? ?? '',
      unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
      qty: (row['qty'] as num?)?.toInt() ?? 1,
      lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ShopCartItem {
  const ShopCartItem({
    required this.id,
    required this.productId,
    required this.qty,
    this.product,
  });

  final String id;
  final String productId;
  final int qty;
  final ShopProduct? product;

  double get lineTotal => (product?.basePrice ?? 0) * qty;
}

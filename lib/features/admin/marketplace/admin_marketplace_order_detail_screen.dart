import 'package:flutter/material.dart';

import '../../marketplace/presentation/marketplace_order_detail_screen.dart';

/// Admin reuses buyer-safe line renderer; Firestore rules allow superadmin read.
class AdminMarketplaceOrderDetailScreen extends StatelessWidget {
  const AdminMarketplaceOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return MarketplaceOrderDetailScreen(orderId: orderId);
  }
}

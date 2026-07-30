import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/marketplace_premium_shell.dart';

class MarketplaceSellerShipmentDetailScreen extends StatelessWidget {
  const MarketplaceSellerShipmentDetailScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context) {
    return MarketplacePremiumShell(
      appBar: AppBar(title: Text('Shipment $shipmentId')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text('Inbound detail', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

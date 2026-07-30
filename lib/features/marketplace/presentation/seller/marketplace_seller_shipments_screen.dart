import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/marketplace_premium_shell.dart';

class MarketplaceSellerShipmentsScreen extends StatelessWidget {
  const MarketplaceSellerShipmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Ship to hub')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Create inbound shipments to D.G.Yard with AWB, photos, and packing list. Backend workflow hooks land in the next integration pass.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

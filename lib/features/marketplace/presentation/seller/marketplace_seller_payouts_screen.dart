import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/marketplace_premium_shell.dart';

class MarketplaceSellerPayoutsScreen extends StatelessWidget {
  const MarketplaceSellerPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Payouts')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Payouts release only after delivery, QC, and settlement rules. Ledger integration will mirror technician payout controls.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

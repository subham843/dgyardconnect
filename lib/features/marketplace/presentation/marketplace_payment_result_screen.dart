import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplacePaymentResultScreen extends StatelessWidget {
  const MarketplacePaymentResultScreen({
    super.key,
    required this.orderId,
    required this.method,
    this.paymentVerified = false,
  });

  final String orderId;
  final String method;
  final bool paymentVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarketplacePremiumShell(
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Icon(Icons.check_circle_rounded, size: 72, color: AppColors.success),
                    const SizedBox(height: 20),
                    Text(
                      'Order recorded',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      method == 'razorpay'
                          ? (paymentVerified
                              ? 'Payment confirmed. Order $orderId. You will get dispatch updates from D.G.Yard.'
                              : 'Reference: $orderId. If you paid online, confirmation may arrive via webhook shortly.')
                          : 'Reference: $orderId. COD subject to admin verification before dispatch.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => context.go(RouteNames.marketplaceOrders),
                      child: const Text('View orders'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => context.go(RouteNames.marketplaceHome),
                      child: const Text('Back to marketplace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

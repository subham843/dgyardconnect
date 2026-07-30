import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/marketplace_premium_shell.dart';

class MarketplaceSellerHubScreen extends StatelessWidget {
  const MarketplaceSellerHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'List through D.G.Yard',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Submissions are reviewed by admin. Published items appear in the buyer catalog without exposing your identity.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 28),
        _Tile(
          icon: Icons.edit_note_rounded,
          title: 'My listings',
          subtitle: 'Drafts, review, and published mapping',
          onTap: () => context.push(RouteNames.marketplaceSellerListings),
        ),
        _Tile(
          icon: Icons.inbox_rounded,
          title: 'Order requests',
          subtitle: 'Accept or reject within SLA (ops-controlled)',
          onTap: () => context.push(RouteNames.marketplaceSellerRequests),
        ),
        _Tile(
          icon: Icons.local_shipping_outlined,
          title: 'Ship to hub',
          subtitle: 'Inbound to D.G.Yard',
          onTap: () => context.push(RouteNames.marketplaceSellerShipments),
        ),
        _Tile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payouts',
          subtitle: 'After delivery & settlement rules',
          onTap: () => context.push(RouteNames.marketplaceSellerPayouts),
        ),
      ],
    );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Seller workspace')),
      body: Column(
        children: [
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

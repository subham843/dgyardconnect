import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../marketplace/presentation/widgets/marketplace_premium_shell.dart';

class AdminMarketplaceHomeScreen extends StatelessWidget {
  const AdminMarketplaceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'B2B trade desk',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Catalog, pricing, fulfillment, and payouts stay admin-governed. Buyer-facing surfaces never expose seller identity.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 20),
        _CardNav(
          title: 'Categories & features',
          subtitle: 'Category → subcategory → options sellers must pick',
          icon: Icons.category_rounded,
          color: const Color(0xFF6366F1),
          onTap: () => context.push(RouteNames.adminMarketplaceTaxonomy),
        ),
        _CardNav(
          title: 'Listing review queue',
          subtitle: 'Approve, price, publish to catalog',
          icon: Icons.fact_check_rounded,
          color: const Color(0xFF059669),
          onTap: () => context.push(RouteNames.adminMarketplaceProductsQueue),
        ),
        _CardNav(
          title: 'All catalog products',
          subtitle: 'Search, edit, or remove live catalog SKUs',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF0D9488),
          onTap: () => context.push(RouteNames.adminMarketplaceCatalogProducts),
        ),
        _CardNav(
          title: 'Pricing desk',
          subtitle: 'Margins, fees, shipping allocation presets',
          icon: Icons.price_change_rounded,
          color: const Color(0xFF2563EB),
          onTap: () => context.push(RouteNames.adminMarketplacePricing),
        ),
        _CardNav(
          title: 'Orders',
          subtitle: 'Lifecycle, holds, reassignments',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () => context.push(RouteNames.adminMarketplaceOrders),
        ),
        _CardNav(
          title: 'RFQ inbox',
          subtitle: 'Bulk quotes and conversions',
          icon: Icons.request_quote_rounded,
          color: const Color(0xFF7C3AED),
          onTap: () => context.push(RouteNames.adminMarketplaceRfq),
        ),
        _CardNav(
          title: 'COD rules',
          subtitle: 'Trust, pincode, amount gates',
          icon: Icons.payments_rounded,
          color: const Color(0xFF0EA5E9),
          onTap: () => context.push(RouteNames.adminMarketplaceCodRules),
        ),
        _CardNav(
          title: 'Inward · QC · Dispatch',
          subtitle: 'Operational desks',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF64748B),
          onTap: () => context.push(RouteNames.adminMarketplaceInward),
        ),
        _CardNav(
          title: 'Seller registry',
          subtitle: 'KYC, strikes linkage, suspension',
          icon: Icons.store_mall_directory_rounded,
          color: const Color(0xFFDB2777),
          onTap: () => context.push(RouteNames.adminMarketplaceSellers),
        ),
        _CardNav(
          title: 'Payout batches',
          subtitle: 'Settlement after delivery + policy',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF10B981),
          onTap: () => context.push(RouteNames.adminMarketplacePayouts),
        ),
        _CardNav(
          title: 'Marketplace audit',
          subtitle: 'Immutable admin action trail',
          icon: Icons.history_edu_rounded,
          color: const Color(0xFF334155),
          onTap: () => context.push(RouteNames.adminMarketplaceAudit),
        ),
      ],
    );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Marketplace control')),
      body: Column(
        children: [
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _CardNav extends StatelessWidget {
  const _CardNav({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
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

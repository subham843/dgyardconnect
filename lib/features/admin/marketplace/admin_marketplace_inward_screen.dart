import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_order_repository.dart';
import '../../marketplace/domain/marketplace_order_summary.dart';
import '../../marketplace/presentation/marketplace_format.dart';
import '../../marketplace/presentation/widgets/marketplace_status_chip.dart';

/// Hub ops entry: recent paid / in-flight orders + shortcuts to QC & dispatch.
class AdminMarketplaceInwardScreen extends StatelessWidget {
  const AdminMarketplaceInwardScreen({super.key});

  static const _hubStatuses = {
    'payment_pending',
    'paid',
    'awaiting_confirmation',
    'seller_request_open',
    'seller_accepted',
    'awaiting_inbound',
    'inbound_received',
    'qc_pending',
    'qc_passed',
    'repacked',
  };

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceOrderRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Inward & hub')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Goods receipt, mismatch handling, and quarantine. Tie each inbound package to seller order lines before QC.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push(RouteNames.adminMarketplaceQc),
                    child: const Text('Open QC desk'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(RouteNames.adminMarketplaceDispatch),
                    child: const Text('Dispatch desk'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Orders in hub pipeline',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<MarketplaceOrderSummary>>(
              stream: repo.watchAllOrdersForAdmin(limit: 60),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered =
                    snap.data!.where((o) => _hubStatuses.contains(o.status)).toList(growable: false);
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No orders in hub statuses yet. Use Marketplace orders for the full list.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final o = filtered[i];
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            MarketplaceStatusChip(
                              label: o.status.replaceAll('_', ' '),
                              tone: MarketplaceChipTone.neutral,
                            ),
                          ],
                        ),
                        trailing: Text(marketplaceFormatInr(o.totalPaise), style: Theme.of(context).textTheme.titleSmall),
                        onTap: () => context.push(RouteNames.adminMarketplaceOrderDetail(o.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

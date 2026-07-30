import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_order_repository.dart';
import '../../marketplace/domain/marketplace_order_summary.dart';
import '../../marketplace/presentation/marketplace_format.dart';
import '../../marketplace/presentation/widgets/marketplace_status_chip.dart';

class AdminMarketplaceOrdersScreen extends StatelessWidget {
  const AdminMarketplaceOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceOrderRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace orders')),
      body: StreamBuilder<List<MarketplaceOrderSummary>>(
        stream: repo.watchAllOrdersForAdmin(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Text('No orders', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final o = list[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      MarketplaceStatusChip(label: o.status.replaceAll('_', ' '), tone: MarketplaceChipTone.neutral),
                      Text('Buyer: ${o.buyerUid}', style: Theme.of(context).textTheme.labelSmall),
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
    );
  }
}

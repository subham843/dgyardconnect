import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../data/marketplace_order_repository.dart';
import '../domain/marketplace_order_summary.dart';
import 'marketplace_format.dart';
import 'widgets/marketplace_status_chip.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceOrdersScreen extends StatelessWidget {
  const MarketplaceOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repo = MarketplaceOrderRepository();
    final theme = Theme.of(context);

    final body = uid.isEmpty
        ? const Center(child: Text('Sign in required'))
        : StreamBuilder<List<MarketplaceOrderSummary>>(
            stream: repo.watchBuyerOrders(uid),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No marketplace orders yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push(RouteNames.marketplaceOrderDetail(o.id)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order ${o.id.length > 8 ? o.id.substring(0, 8) : o.id}…',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  MarketplaceStatusChip(
                                    label: o.status.replaceAll('_', ' '),
                                    tone: o.status == 'completed'
                                        ? MarketplaceChipTone.success
                                        : MarketplaceChipTone.neutral,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              marketplaceFormatInr(o.totalPaise),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('My Orders')),
      body: Column(
        children: [
          Expanded(child: body),
        ],
      ),
    );
  }
}

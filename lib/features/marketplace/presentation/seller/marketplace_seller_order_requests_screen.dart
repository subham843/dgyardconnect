import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/marketplace_seller_request_repository.dart';
import '../../domain/marketplace_seller_order_request.dart';
import '../marketplace_format.dart';
import '../widgets/marketplace_premium_shell.dart';

class MarketplaceSellerOrderRequestsScreen extends StatelessWidget {
  const MarketplaceSellerOrderRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repo = MarketplaceSellerRequestRepository();

    final bodyWidget = uid.isEmpty
        ? const Center(child: Text('Sign in required'))
        : StreamBuilder<List<MarketplaceSellerOrderRequest>>(
            stream: repo.watchForSeller(uid),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}', textAlign: TextAlign.center));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 56, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)),
                      const SizedBox(height: 16),
                      Text(
                        'Accept / reject queue',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'New line items appear here after a buyer pays (or places COD). Buyer identity stays masked.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No active requests',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = items[i];
                  return Card(
                    child: ListTile(
                      title: Text(r.titleSnapshot, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        'Qty ${r.quantity} · Line ${marketplaceFormatInr(r.lineTotalPaise)} · ${r.status}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(RouteNames.marketplaceSellerRequestDetail(r.id)),
                    ),
                  );
                },
              );
            },
          );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Order requests')),
      body: Column(
        children: [
          Expanded(child: bodyWidget),
        ],
      ),
    );
  }
}

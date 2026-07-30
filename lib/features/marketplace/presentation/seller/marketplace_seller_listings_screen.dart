import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/marketplace_listing_repository.dart';
import '../../domain/marketplace_listing.dart';
import '../widgets/marketplace_status_chip.dart';
import '../marketplace_format.dart';
import '../widgets/marketplace_premium_shell.dart';

class MarketplaceSellerListingsScreen extends StatelessWidget {
  const MarketplaceSellerListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repo = MarketplaceListingRepository();

    final bodyWidget = uid.isEmpty
        ? const Center(child: Text('Sign in required'))
        : StreamBuilder<List<MarketplaceListing>>(
            stream: repo.watchForSeller(uid),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No listings yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.push(RouteNames.marketplaceSellerListingNew),
                          child: const Text('Create draft'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final l = list[i];
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (l.status == 'draft' || l.status == 'rejected') {
                          context.push(RouteNames.marketplaceSellerListingEdit(l.id));
                        } else if (l.status == 'published' && (l.catalogProductId ?? '').isNotEmpty) {
                          context.push(RouteNames.marketplaceSellerListingManage(l.id));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.title,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                MarketplaceStatusChip(
                                  label: l.status.replaceAll('_', ' '),
                                  tone: l.status == 'published'
                                      ? MarketplaceChipTone.success
                                      : l.status == 'rejected'
                                          ? MarketplaceChipTone.error
                                          : MarketplaceChipTone.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              marketplaceFormatInr(l.proposedPricePaise),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (l.rejectionReason != null && l.rejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Reason: ${l.rejectionReason}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                              ),
                            ],
                            if (l.hasAdminTaxonomySuggestion) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Admin suggested a category — open edit to apply.',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
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
      appBar: AppBar(
        title: const Text('My listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(RouteNames.marketplaceSellerListingNew),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: bodyWidget),
        ],
      ),
    );
  }
}

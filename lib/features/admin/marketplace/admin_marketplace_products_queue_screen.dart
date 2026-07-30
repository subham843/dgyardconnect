import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_listing_repository.dart';
import '../../marketplace/domain/marketplace_listing.dart';
import '../../marketplace/presentation/marketplace_format.dart';
import '../../marketplace/presentation/widgets/marketplace_status_chip.dart';

class AdminMarketplaceProductsQueueScreen extends StatelessWidget {
  const AdminMarketplaceProductsQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceListingRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Listing review queue')),
      body: StreamBuilder<List<MarketplaceListing>>(
        stream: repo.watchPendingReview(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No submissions in review.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final l = list[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(RouteNames.adminMarketplaceProductReview(l.id)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text(
                                'Seller (internal): ${l.sellerUid}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Proposed ${marketplaceFormatInr(l.proposedPricePaise)}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const MarketplaceStatusChip(label: 'Review', tone: MarketplaceChipTone.warning),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

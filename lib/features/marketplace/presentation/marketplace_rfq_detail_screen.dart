import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/firestore_service.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceRfqDetailScreen extends StatelessWidget {
  const MarketplaceRfqDetailScreen({super.key, required this.rfqId});

  final String rfqId;

  @override
  Widget build(BuildContext context) {
    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('RFQ Status')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirestoreService.marketplaceRfqs().doc(rfqId).get(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = snap.data!;
                if (!d.exists || d.data() == null) {
                  return const Center(child: Text('RFQ not found'));
                }
                final m = d.data()!;
                final theme = Theme.of(context);
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      m['title'] as String? ?? '',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text('Status: ${m['status']}', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Text(m['notes'] as String? ?? '', style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                    const SizedBox(height: 24),
                    Text(
                      'Admin will quote through D.G.Yard. You will be notified when the quote is ready.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

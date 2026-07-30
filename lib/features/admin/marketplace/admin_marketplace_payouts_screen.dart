import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/firestore_service.dart';

/// Reads `marketplace_payout_batches` (create rows via Console / future function).
class AdminMarketplacePayoutsScreen extends StatelessWidget {
  const AdminMarketplacePayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout batches')),
      body: !FirestoreService.isAvailable
          ? const Center(child: Text('Firebase is not configured.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.marketplacePayoutBatches()
                  .orderBy('created_at', descending: true)
                  .limit(40)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'If this is an index error, deploy firestore:indexes or create the composite index from the console link in the error.\n\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No payout batches yet. After delivery + return window, finance can record batches in '
                          '`marketplace_payout_batches` (superadmin). High-value payouts: use dual approval in process, not only in-app.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data();
                    final status = '${m['status'] ?? '—'}';
                    final amount = (m['total_paise'] as num?)?.toInt();
                    final sub = amount != null ? ' · ${(amount / 100).toStringAsFixed(0)} INR (paise snapshot)' : '';
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        title: Text(d.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Text('$status$sub', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

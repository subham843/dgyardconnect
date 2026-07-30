import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/firestore_service.dart';

class AdminMarketplaceRfqScreen extends StatelessWidget {
  const AdminMarketplaceRfqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RFQ inbox')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.marketplaceRfqs().orderBy('created_at', descending: true).limit(60).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No RFQs', style: TextStyle(color: AppColors.textSecondary)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = docs[i].data();
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  title: Text(m['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'Buyer: ${m['buyer_uid']}\n${m['status']}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

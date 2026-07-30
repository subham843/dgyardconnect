import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/service_completion_record_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/minimal_app_bar.dart';

/// Dealer list of their service completion records (by dealerId).
class ServiceCompletionRecordsScreen extends StatelessWidget {
  const ServiceCompletionRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: MinimalAppBar(title: 'Service Completion Records'),
        body: const Center(child: Text('Sign in required')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MinimalAppBar(
        title: 'Service Completion Records',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.serviceCompletionRecords()
            .where('dealerId', isEqualTo: uid)
            .orderBy('completionDate', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No service completion records yet. Records are created when you approve a completed job.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final dateFormat = DateFormat('dd MMM yyyy');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final record = ServiceCompletionRecordModel.fromFirestore(docs[index]);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => context.push(RouteNames.dealerServiceRecord(record.jobId)),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.serviceType ?? 'Service',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(record.recordStatus).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                record.warrantyStatusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _statusColor(record.recordStatus),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Record ID: ${record.displayRecordId}', style: Theme.of(context).textTheme.bodySmall),
                        Text('Job ID: ${record.displayJobId}', style: Theme.of(context).textTheme.bodySmall),
                        Text('Technician: ${record.technicianName}', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          'Completed: ${record.completionDate != null ? dateFormat.format(record.completionDate!) : "—"}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'View record →',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  static Color _statusColor(String? status) {
    switch (status) {
      case 'warranty_active':
        return Colors.green;
      case 'warranty_expired':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }
}

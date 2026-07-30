import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: View audit logs (super admin only). Filter by action type.
class AdminAuditLogsScreen extends StatelessWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit logs')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.auditLogs()
            .orderBy('timestamp', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No audit logs yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final actionType = d['actionType'] as String? ?? '—';
              final adminId = d['adminId'] as String? ?? '—';
              final targetUserId = d['targetUserId'] as String?;
              final details = d['details'] as Map<String, dynamic>?;
              final ts = d['timestamp'] is Timestamp
                  ? (d['timestamp'] as Timestamp).toDate()
                  : null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    _formatAction(actionType),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Admin: ${adminId.toString().length > 12 ? '${adminId.toString().substring(0, 12)}…' : adminId}'
                    '${targetUserId != null ? ' · User: ${targetUserId.toString().substring(0, 8)}…' : ''}'
                    '${ts != null ? '\n${_formatDate(ts)}' : ''}'
                    '${details != null && details.isNotEmpty ? '\n${details.toString()}' : ''}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatAction(String action) {
    const map = {
      'trust_score_adjusted': 'Trust score adjusted',
      'dispute_resolved': 'Dispute resolved',
      'technician_level_changed': 'Technician level changed',
      'refund_issued': 'Refund issued',
      'user_suspended': 'User suspended',
      'user_reactivated': 'User reactivated',
      'strike_added': 'Strike added',
      'strike_removed': 'Strike removed',
      'fraud_flag_removed': 'Fraud flag removed',
      'reliability_score_adjusted': 'Reliability score adjusted',
    };
    return map[action] ?? action;
  }

  static String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

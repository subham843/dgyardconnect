import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: List job evidence records (tamper-proof evidence for completed jobs).
class AdminJobEvidenceListScreen extends StatelessWidget {
  const AdminJobEvidenceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job evidence locker')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job evidence locker'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobEvidenceCollection()
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No job evidence records yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              final jobId = doc.id;
              final beforeCount = (d['beforeWorkPhotos'] as List?)?.length ?? 0;
              final afterCount = (d['afterWorkPhotos'] as List?)?.length ?? 0;
              final createdAt = d['createdAt'] is Timestamp
                  ? (d['createdAt'] as Timestamp).toDate()
                  : null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder_special, color: Colors.amber),
                  title: Text('Job: ${jobId.length > 12 ? '${jobId.substring(0, 12)}…' : jobId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Before: $beforeCount · After: $afterCount'
                    '${createdAt != null ? ' · ${createdAt.day}/${createdAt.month}/${createdAt.year}' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.adminJobEvidenceView(jobId)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

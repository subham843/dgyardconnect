import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: View a single job evidence record (read-only).
class AdminJobEvidenceViewScreen extends StatelessWidget {
  const AdminJobEvidenceViewScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job evidence')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job evidence'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminJobEvidence),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobEvidence(jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Evidence not found.'));
          }
          final d = snapshot.data!.data() ?? {};
          final beforePhotos = (d['beforeWorkPhotos'] as List?) ?? [];
          final afterPhotos = (d['afterWorkPhotos'] as List?) ?? [];
          final pickupPhotos = (d['pickupPhotos'] as List?) ?? [];
          final materialReturnPhotos = (d['materialReturnPhotos'] as List?) ?? [];
          final materialList = (d['materialList'] as List?) ?? [];
          final jobStart = d['jobStartTimestamp'] is Timestamp ? (d['jobStartTimestamp'] as Timestamp).toDate().toString() : '—';
          final jobEnd = d['jobCompletionTimestamp'] is Timestamp ? (d['jobCompletionTimestamp'] as Timestamp).toDate().toString() : '—';
          final locked = d['locked'] as bool? ?? false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (locked)
                Card(
                  color: Colors.green.shade50,
                  child: const ListTile(
                    leading: Icon(Icons.lock, color: Colors.green),
                    title: Text('Evidence locked (tamper-proof)', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              const SizedBox(height: 8),
              _Section(title: 'Before work photos', count: beforePhotos.length, items: beforePhotos),
              _Section(title: 'After work photos', count: afterPhotos.length, items: afterPhotos),
              _Section(title: 'Pickup photos', count: pickupPhotos.length, items: pickupPhotos),
              _Section(title: 'Material return photos', count: materialReturnPhotos.length, items: materialReturnPhotos),
              const SizedBox(height: 12),
              Text('Job start', style: Theme.of(context).textTheme.labelLarge),
              Text(jobStart),
              const SizedBox(height: 8),
              Text('Job completion', style: Theme.of(context).textTheme.labelLarge),
              Text(jobEnd),
              if (materialList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Material list (${materialList.length} items)', style: Theme.of(context).textTheme.labelLarge),
                ...materialList.map<Widget>((e) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• ${e.toString()}'),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.count, required this.items});

  final String title;
  final int count;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title ($count)', style: Theme.of(context).textTheme.titleSmall),
          if (items.isEmpty)
            const Text('—')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map<Widget>((e) {
                final url = e is Map ? (e['url'] as String? ?? e['photoUrl'] as String?) : null;
                if (url == null || url.isEmpty) return const SizedBox.shrink();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

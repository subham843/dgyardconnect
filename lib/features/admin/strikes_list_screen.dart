import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: View technician strikes, add or remove strikes.
class AdminStrikesListScreen extends StatelessWidget {
  const AdminStrikesListScreen({super.key});

  static String _displayId(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '—';
    return v.length <= 8 ? v : v.substring(0, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Technician strikes')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician strikes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.technicianStrikes()
            .where('removed', isEqualTo: false)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No strikes recorded.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final technicianId = d['technician_id'] as String? ?? '—';
              final reason = d['strike_reason'] as String? ?? '—';
              final level = d['strike_level'] as int? ?? 1;
              final ts = d['timestamp'] is Timestamp
                  ? (d['timestamp'] as Timestamp).toDate()
                  : null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    _formatReason(reason),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Technician: ${_displayId(technicianId)} · Level $level${ts != null ? ' · ${_formatDate(ts)}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeStrike(context, docs[index].id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStrikeDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add strike'),
      ),
    );
  }

  static String _formatReason(String reason) {
    final map = {
      'job_cancellation_after_acceptance': 'Job cancellation after acceptance',
      'no_show': 'No-show at job location',
      'dispute_loss': 'Dispute loss',
      'warranty_claim_failure': 'Warranty claim failure',
      'fake_completion_attempt': 'Fake completion attempt',
    };
    return map[reason] ?? reason;
  }

  static String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> _removeStrike(BuildContext context, String strikeId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove strike'),
        content: const Text(
          'Mark this strike as removed? The technician\'s block may be cleared if strike count drops below 2.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('removeTechnicianStrike').call({'strikeId': strikeId});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Strike removed.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    }
  }

  static Future<void> _showAddStrikeDialog(BuildContext context) async {
    final technicianId = TextEditingController();
    final reason = ValueNotifier<String>('job_cancellation_after_acceptance');
    final jobId = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add strike'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: technicianId,
                  decoration: const InputDecoration(labelText: 'Technician ID'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason.value,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(value: 'job_cancellation_after_acceptance', child: Text('Job cancellation after acceptance')),
                    DropdownMenuItem(value: 'no_show', child: Text('No-show at job')),
                    DropdownMenuItem(value: 'dispute_loss', child: Text('Dispute loss')),
                    DropdownMenuItem(value: 'warranty_claim_failure', child: Text('Warranty claim failure')),
                    DropdownMenuItem(value: 'fake_completion_attempt', child: Text('Fake completion attempt')),
                  ],
                  onChanged: (v) {
                    if (v != null) reason.value = v;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: jobId,
                  decoration: const InputDecoration(labelText: 'Job ID (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final tid = technicianId.text.trim();
                if (tid.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await FirebaseFunctions.instance.httpsCallable('addTechnicianStrike').call({
                    'technicianId': tid,
                    'reason': reason.value,
                    'jobId': jobId.text.trim().isEmpty ? null : jobId.text.trim(),
                    'strikeLevel': 1,
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Strike added.')));
                  }
                } on FirebaseFunctionsException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

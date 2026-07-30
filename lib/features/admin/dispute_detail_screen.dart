import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import '../../core/constants/route_names.dart';
import '../../core/constants/trust_reputation_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_dispute_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminDisputeDetailScreen extends StatelessWidget {
  const AdminDisputeDetailScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  Widget build(BuildContext context) {
    final disputeRef = FirestoreService.jobDisputes().doc(disputeId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispute'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: disputeRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Dispute not found.'));
          }
          final dispute = JobDisputeModel.fromFirestore(snapshot.data!);
          final dateFormat = DateFormat('MMM d, y HH:mm');

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(label: 'Job ID', value: dispute.displayJobId),
                      _Row(
                        label: 'Dealer',
                        value: dispute.dealerName ??
                            UserModel(uid: dispute.dealerId, userCode: dispute.dealerCode).displayId,
                      ),
                      _Row(label: 'Status', value: dispute.status),
                      if (dispute.createdAt != null)
                        _Row(label: 'Created', value: dateFormat.format(dispute.createdAt!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push(RouteNames.adminJobEvidenceView(dispute.jobId)),
                icon: const Icon(Icons.folder_special, size: 18),
                label: const Text('View job evidence'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push(RouteNames.adminJobDetail(dispute.jobId)),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open job'),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(dispute.description),
                    ],
                  ),
                ),
              ),
              if (dispute.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photos',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: dispute.photoUrls
                              .map((url) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (dispute.videoUrl != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.video_file),
                  label: const Text('View video'),
                ),
              ],
              if (dispute.status == 'open') ...[
                const SizedBox(height: 24),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resolve',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _resolveDispute(context, disputeId, 'approved_tech', 'Release payment to technician'),
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Approve technician payment'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _resolveDispute(context, disputeId, 'refund_dealer', 'Refund dealer'),
                          icon: const Icon(Icons.money_off, size: 20),
                          label: const Text('Refund dealer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _resolveDispute(BuildContext context, String disputeId, String resolution, String label) async {
    String severity = 'medium';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Resolve: $label'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Dispute severity (trust score deduction):'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: severity,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: TrustReputationConstants.disputeSeverityLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          severity = v;
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: c,
                      decoration: const InputDecoration(labelText: 'Admin notes (optional)'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, {'notes': c.text.trim(), 'severity': severity}),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    if (context.mounted && result != null) {
      try {
        await FirebaseFunctions.instance.httpsCallable('resolveJobDispute').call({
          'disputeId': disputeId,
          'resolution': resolution,
          'disputeSeverity': result['severity'] ?? 'medium',
          if (result['notes']?.isNotEmpty == true) 'adminNotes': result['notes'],
        });
        if (context.mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute resolved.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString())),
          );
        }
      }
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

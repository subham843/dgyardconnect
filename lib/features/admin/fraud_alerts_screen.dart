import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/empty_error_states.dart';

class AdminFraudAlertsScreen extends StatefulWidget {
  const AdminFraudAlertsScreen({super.key});

  @override
  State<AdminFraudAlertsScreen> createState() => _AdminFraudAlertsScreenState();
}

class _AdminFraudAlertsScreenState extends State<AdminFraudAlertsScreen> {
  String _status = 'open'; // open | reviewed | resolved | all
  String _type = 'all'; // all | duplicate_job | repeat_cancellation | warranty_abuse | fake_completion

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fraud alerts'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(RouteNames.adminHome),
          ),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    Query<Map<String, dynamic>> q = FirestoreService.fraudAlerts()
        .orderBy('createdAt', descending: true)
        .limit(200);
    if (_status != 'all') {
      q = q.where('status', isEqualTo: _status);
    }
    if (_type != 'all') {
      q = q.where('type', isEqualTo: _type);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud alerts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Open',
                  selected: _status == 'open',
                  onTap: () => setState(() => _status = 'open'),
                ),
                _FilterChip(
                  label: 'Reviewed',
                  selected: _status == 'reviewed',
                  onTap: () => setState(() => _status = 'reviewed'),
                ),
                _FilterChip(
                  label: 'Resolved',
                  selected: _status == 'resolved',
                  onTap: () => setState(() => _status = 'resolved'),
                ),
                _FilterChip(
                  label: 'All',
                  selected: _status == 'all',
                  onTap: () => setState(() => _status = 'all'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All types',
                    selected: _type == 'all',
                    onTap: () => setState(() => _type = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Duplicate job',
                    selected: _type == 'duplicate_job',
                    onTap: () => setState(() => _type = 'duplicate_job'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Repeat cancel',
                    selected: _type == 'repeat_cancellation',
                    onTap: () => setState(() => _type = 'repeat_cancellation'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Warranty abuse',
                    selected: _type == 'warranty_abuse',
                    onTap: () => setState(() => _type = 'warranty_abuse'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Fake completion',
                    selected: _type == 'fake_completion',
                    onTap: () => setState(() => _type = 'fake_completion'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.report_outlined,
                    title: _status == 'all' ? 'No fraud alerts yet' : 'No ${_status.replaceAll('_', ' ')} alerts',
                    subtitle: _status == 'all'
                        ? 'Alerts will appear here when suspicious activity is detected.'
                        : 'Try changing the filter to see more.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final type = (d['type'] as String?) ?? 'unknown';
                    final status = (d['status'] as String?) ?? 'open';
                    final jobId = d['jobId'] as String?;
                    final userId = d['userId'] as String?;
                    final risk = (d['riskScore'] as num?)?.toDouble();
                    final createdAt = d['createdAt'] is Timestamp
                        ? (d['createdAt'] as Timestamp).toDate()
                        : null;

                    return Card(
                      child: ListTile(
                        onTap: () => context.push(
                          '/admin/fraud-alerts/${doc.id}',
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                          child: Icon(_typeIcon(type), color: _statusColor(status)),
                        ),
                        title: Text(_titleFor(type)),
                        subtitle: Text(
                          '${_chip(status)}'
                          '${risk != null ? ' · Risk: ${risk.toStringAsFixed(0)}' : ''}'
                          '${jobId != null ? '\nJob: ${jobId.substring(0, 8)}…' : ''}'
                          '${userId != null ? ' · User: ${userId.substring(0, 8)}…' : ''}'
                          '${createdAt != null ? '\n${_fmt(createdAt)}' : ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _titleFor(String type) {
    switch (type) {
      case 'duplicate_job':
        return 'Duplicate job suspected';
      case 'repeat_cancellation':
        return 'Repeated cancellations';
      case 'fake_completion':
        return 'Fake completion suspected';
      case 'warranty_abuse':
        return 'Warranty abuse suspected';
      default:
        return type.replaceAll('_', ' ').trim().isEmpty ? 'Fraud alert' : type.replaceAll('_', ' ');
    }
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'duplicate_job':
        return Icons.copy_all_rounded;
      case 'repeat_cancellation':
        return Icons.cancel_schedule_send_rounded;
      case 'fake_completion':
        return Icons.verified_rounded;
      case 'warranty_abuse':
        return Icons.privacy_tip_rounded;
      default:
        return Icons.report_rounded;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'reviewed':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  static String _chip(String status) => status.toUpperCase();

  static String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}


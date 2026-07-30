import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

class AdminSupportTicketsListScreen extends StatefulWidget {
  const AdminSupportTicketsListScreen({super.key});

  @override
  State<AdminSupportTicketsListScreen> createState() =>
      _AdminSupportTicketsListScreenState();
}

class _AdminSupportTicketsListScreenState
    extends State<AdminSupportTicketsListScreen> {
  String _status = 'open'; // open | in_progress | closed | all

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Support tickets'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(RouteNames.adminHome),
          ),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .limit(200);
    if (_status != 'all') {
      q = q.where('status', isEqualTo: _status);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support tickets'),
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
                  label: 'In progress',
                  selected: _status == 'in_progress',
                  onTap: () => setState(() => _status = 'in_progress'),
                ),
                _FilterChip(
                  label: 'Closed',
                  selected: _status == 'closed',
                  onTap: () => setState(() => _status = 'closed'),
                ),
                _FilterChip(
                  label: 'All',
                  selected: _status == 'all',
                  onTap: () => setState(() => _status = 'all'),
                ),
              ],
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
                  return const Center(child: Text('No tickets.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final subject = d['subject'] as String? ?? '—';
                    final uid = d['uid'] as String? ?? '—';
                    final status = d['status'] as String? ?? 'open';
                    final createdAt = d['createdAt'] is Timestamp
                        ? (d['createdAt'] as Timestamp).toDate()
                        : null;
                    return Card(
                      child: ListTile(
                        onTap: () => context.push(
                          RouteNames.adminSupportTicketDetail(doc.id),
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              _statusColor(status).withValues(alpha: 0.12),
                          child: Icon(
                            Icons.confirmation_number_rounded,
                            color: _statusColor(status),
                          ),
                        ),
                        title: Text(
                          subject,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Status: ${status.toUpperCase()}\nUser: ${uid.substring(0, uid.length >= 8 ? 8 : uid.length)}…'
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

  static Color _statusColor(String status) {
    switch (status) {
      case 'closed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  static String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
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


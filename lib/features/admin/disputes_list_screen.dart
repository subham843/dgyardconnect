import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_dispute_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminDisputesListScreen extends StatefulWidget {
  const AdminDisputesListScreen({super.key, this.initialJobId});

  /// When set (e.g. from Admin Job Detail "View dispute"), open that dispute's detail on first load.
  final String? initialJobId;

  @override
  State<AdminDisputesListScreen> createState() => _AdminDisputesListScreenState();
}

class _AdminDisputesListScreenState extends State<AdminDisputesListScreen> {
  String _filter = 'open'; // open | resolved
  bool _openedInitialDispute = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialJobId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialDisputeIfAny());
    }
  }

  Future<void> _openInitialDisputeIfAny() async {
    if (_openedInitialDispute || widget.initialJobId == null) return;
    final snap = await FirestoreService.jobDisputes()
        .where('jobId', isEqualTo: widget.initialJobId)
        .limit(1)
        .get();
    if (!mounted || _openedInitialDispute) return;
    if (snap.docs.isNotEmpty) {
      setState(() => _openedInitialDispute = true);
      final dispute = JobDisputeModel.fromFirestore(snap.docs.first);
      if (mounted) context.push(RouteNames.adminDisputeDetail(dispute.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job disputes')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    Query<Map<String, dynamic>> query;
    if (_filter == 'open') {
      query = FirestoreService.jobDisputes()
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .limit(200);
    } else if (_filter == 'resolved') {
      query = FirestoreService.jobDisputes()
          .where('status', whereIn: ['approved_tech', 'refund_dealer', 'partial'])
          .orderBy('createdAt', descending: true)
          .limit(200);
    } else {
      query = FirestoreService.jobDisputes()
          .orderBy('createdAt', descending: true)
          .limit(200);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job disputes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Open',
                  selected: _filter == 'open',
                  onTap: () => setState(() => _filter = 'open'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Resolved',
                  selected: _filter == 'resolved',
                  onTap: () => setState(() => _filter = 'resolved'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No disputes match the filter.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final dispute = JobDisputeModel.fromFirestore(docs[index]);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          dispute.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Job: ${dispute.jobId} • ${dispute.status}${dispute.createdAt != null ? ' • ${DateFormat('MMM d, HH:mm').format(dispute.createdAt!)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(RouteNames.adminDisputeDetail(dispute.id)),
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

}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}


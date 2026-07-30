import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/service_completion_record_model.dart';
import '../../shared/services/firestore_service.dart';
import '../shared/service_completion_record_screen.dart' as shared;

class AdminServiceCompletionRecordsScreen extends StatefulWidget {
  const AdminServiceCompletionRecordsScreen({super.key});

  @override
  State<AdminServiceCompletionRecordsScreen> createState() => _AdminServiceCompletionRecordsScreenState();
}

class _AdminServiceCompletionRecordsScreenState extends State<AdminServiceCompletionRecordsScreen> {
  String _filter = 'all'; // all | warranty_active | warranty_expired | active
  bool _runningBackfill = false;

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service completion records')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    Query<Map<String, dynamic>> query = FirestoreService.serviceCompletionRecords()
        .orderBy('completionDate', descending: true)
        .limit(200);
    if (_filter != 'all') {
      query = query.where('recordStatus', isEqualTo: _filter);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service completion records'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
        actions: [
          IconButton(
            tooltip: 'Fix old warranty records',
            onPressed: _runningBackfill ? null : () => _runWarrantyBackfill(context),
            icon: _runningBackfill
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.build_circle_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active warranty',
                  selected: _filter == 'warranty_active',
                  onTap: () => setState(() => _filter = 'warranty_active'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Expired warranty',
                  selected: _filter == 'warranty_expired',
                  onTap: () => setState(() => _filter = 'warranty_expired'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active',
                  selected: _filter == 'active',
                  onTap: () => setState(() => _filter = 'active'),
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
                  return const Center(child: Text('No records match the filter.'));
                }
                final dateFormat = DateFormat('dd MMM yyyy');
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final record = ServiceCompletionRecordModel.fromFirestore(docs[index]);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          record.serviceType ?? 'Service',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${record.dealerName} · ${record.technicianName}\n'
                          'Record: ${record.displayRecordId} · Job: ${record.displayJobId}\n'
                          'Completed: ${record.completionDate != null ? dateFormat.format(record.completionDate!) : "—"} · ${record.warrantyStatusLabel}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'view') {
                              context.push(
                                RouteNames.adminServiceCompletionRecordView(record.jobId),
                              );
                            } else if (value == 'download') {
                              _downloadPdf(context, record);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'view', child: Text('View record')),
                            const PopupMenuItem(value: 'download', child: Text('Download PDF')),
                          ],
                        ),
                        onTap: () => context.push(RouteNames.adminServiceCompletionRecordView(record.jobId)),
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

  Future<void> _downloadPdf(BuildContext context, ServiceCompletionRecordModel record) async {
    await shared.ServiceCompletionRecordScreen.downloadPdf(context, record);
  }

  Future<void> _runWarrantyBackfill(BuildContext context) async {
    setState(() => _runningBackfill = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('adminBackfillServiceRecordWarranty');
      final result = await callable.call(<String, dynamic>{'limit': 600, 'dryRun': false});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Warranty fix done: scanned ${data['scanned'] ?? 0}, updated ${data['fixed'] ?? 0}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Warranty fix failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _runningBackfill = false);
    }
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

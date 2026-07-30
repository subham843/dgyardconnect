import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/warranty_claim_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminWarrantyClaimsListScreen extends StatefulWidget {
  const AdminWarrantyClaimsListScreen({super.key});

  @override
  State<AdminWarrantyClaimsListScreen> createState() => _AdminWarrantyClaimsListScreenState();
}

class _AdminWarrantyClaimsListScreenState extends State<AdminWarrantyClaimsListScreen> {
  String _filter = 'all'; // all | pending | technician_failed | resolved

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Warranty claims')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    Query<Map<String, dynamic>> query = FirestoreService.warrantyClaims()
        .orderBy('claimTime', descending: true)
        .limit(200);
    if (_filter != 'all') {
      query = query.where('claimStatus', isEqualTo: _filter);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranty claims'),
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
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pending',
                  selected: _filter == 'pending',
                  onTap: () => setState(() => _filter = 'pending'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Technician failed',
                  selected: _filter == 'technician_failed',
                  onTap: () => setState(() => _filter = 'technician_failed'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Resolved',
                  selected: _filter == 'resolved',
                  onTap: () => setState(() => _filter = 'resolved'),
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
                  return const Center(child: Text('No claims match the filter.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final claim = WarrantyClaimModel.fromFirestore(docs[index]);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          claim.problemDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Job: ${claim.jobId} • ${claim.statusLabel}${claim.claimTime != null ? ' • ${DateFormat('MMM d').format(claim.claimTime!)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(RouteNames.adminWarrantyClaimDetail(claim.id)),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminEscrowApprovalsScreen extends StatefulWidget {
  const AdminEscrowApprovalsScreen({super.key});

  @override
  State<AdminEscrowApprovalsScreen> createState() => _AdminEscrowApprovalsScreenState();
}

class _AdminEscrowApprovalsScreenState extends State<AdminEscrowApprovalsScreen> {
  String _filter = 'under_admin_review'; // under_admin_review | locked_due_to_claim | all
  String _query = '';
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _query);
    _controller.addListener(() {
      final next = _controller.text;
      if (next == _query) return;
      setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matchesQuery(String jobId, Map<String, dynamic> d) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final title = (d['title'] as String?) ?? '';
    final dealerId = (d['dealerId'] as String?) ?? '';
    final technicianId = (d['technicianId'] as String?) ?? '';
    final reason = (d['escrowLockReason'] as String?) ?? '';
    return jobId.toLowerCase().contains(q) ||
        title.toLowerCase().contains(q) ||
        dealerId.toLowerCase().contains(q) ||
        technicianId.toLowerCase().contains(q) ||
        reason.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escrow approvals')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    Query<Map<String, dynamic>> query = FirestoreService.jobs().limit(300);
    if (_filter != 'all') {
      query = query.where('escrowStatus', isEqualTo: _filter);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Escrow approvals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final docs = snapshot.data!.docs
              .where((doc) => _matchesQuery(doc.id, doc.data()))
              .toList(growable: false);
          if (docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Filters(
                  filter: _filter,
                  onFilter: (v) => setState(() => _filter = v),
                  controller: _controller,
                  onClear: () => _controller.clear(),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No escrow items match your filter/search.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return _Filters(
                  filter: _filter,
                  onFilter: (v) => setState(() => _filter = v),
                  controller: _controller,
                  onClear: () => _controller.clear(),
                );
              }

              final doc = docs[i - 1];
              final d = doc.data();
              final hold = (d['holdPaymentAmount'] as num?)?.toDouble() ?? 0.0;
              final lockReason = (d['escrowLockReason'] as String?) ?? '—';
              final warrantyEnd = (d['warrantyEndDate'] as Timestamp?)?.toDate();
              final title = (d['title'] as String?) ?? 'Job';
              final jobCode = (d['jobCode'] as String?)?.trim();
              final displayJobId = (jobCode != null && jobCode.isNotEmpty)
                  ? jobCode
                  : (doc.id.length <= 8 ? doc.id : doc.id.substring(0, 8).toUpperCase());
              final dealerCode = (d['dealerCode'] as String?)?.trim();
              final technicianCode = (d['technicianCode'] as String?)?.trim();
              final dealerId = (d['dealerId'] as String?) ?? '';
              final technicianId = (d['technicianId'] as String?) ?? '';
              final displayDealerId = dealerCode != null && dealerCode.isNotEmpty
                  ? dealerCode
                  : (dealerId.isEmpty ? '—' : UserModel(uid: dealerId).displayId);
              final displayTechnicianId = technicianCode != null && technicianCode.isNotEmpty
                  ? technicianCode
                  : (technicianId.isEmpty ? '—' : UserModel(uid: technicianId).displayId);
              final status = (d['status'] as String?) ?? '—';
              final escrowStatus = (d['escrowStatus'] as String?) ?? '—';

              final chipColor = escrowStatus == 'under_admin_review'
                  ? AppColors.warning
                  : escrowStatus == 'locked_due_to_claim'
                      ? AppColors.error
                      : AppColors.textSecondary;

              return Card(
                child: ListTile(
                  onTap: escrowStatus == 'under_admin_review'
                      ? () => context.push(RouteNames.adminEscrowApprovalDetail(doc.id))
                      : null,
                  leading: CircleAvatar(
                    backgroundColor: chipColor.withValues(alpha: 0.12),
                    child: Icon(
                      escrowStatus == 'locked_due_to_claim'
                          ? Icons.lock_rounded
                          : Icons.lock_clock_rounded,
                      color: chipColor,
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Escrow: $escrowStatus • Job: $displayJobId • Status: $status'
                    '\nDealer: $displayDealerId • Tech: $displayTechnicianId'
                    '\nHold: ₹${hold.toStringAsFixed(0)} • Reason: $lockReason'
                    '${warrantyEnd != null ? '\nWarranty end: ${warrantyEnd.day}/${warrantyEnd.month}/${warrantyEnd.year}' : ''}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: escrowStatus == 'under_admin_review'
                      ? const Icon(Icons.chevron_right_rounded)
                      : const Icon(Icons.lock_outline_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.onFilter,
    required this.controller,
    required this.onClear,
  });

  final String filter;
  final ValueChanged<String> onFilter;
  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Under review'),
                selected: filter == 'under_admin_review',
                onSelected: (_) => onFilter('under_admin_review'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Locked'),
                selected: filter == 'locked_due_to_claim',
                onSelected: (_) => onFilter('locked_due_to_claim'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('All'),
                selected: filter == 'all',
                onSelected: (_) => onFilter('all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search by jobId, title, dealerId, technicianId...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}


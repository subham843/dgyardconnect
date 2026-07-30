import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dealer_payment_receipt_model.dart';
import '../../shared/models/job_dispute_model.dart';
import '../../shared/models/technician_payment_receipt_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/warranty_claim_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminJobDetailScreen extends StatelessWidget {
  const AdminJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  static const _bgLight = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Job detail', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    final jobRef = FirestoreService.jobs().doc(jobId);
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Job detail', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: jobRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Job not found.'));
          }
          final d = snapshot.data!.data() ?? {};
          final title = d['title'] as String? ?? 'Job';
          final status = d['status'] as String? ?? '—';
          final jobCode = (d['jobCode'] as String?)?.trim();
          final dealerId = d['dealerId'] as String?;
          final dealerCode = (d['dealerCode'] as String?)?.trim();
          final technicianId = d['technicianId'] as String?;
          final technicianCode = (d['technicianCode'] as String?)?.trim();
          final displayDealerId = dealerCode != null && dealerCode.isNotEmpty
              ? dealerCode
              : (dealerId == null || dealerId.isEmpty)
                  ? '—'
                  : UserModel(uid: dealerId).displayId;
          final displayTechnicianId = technicianCode != null && technicianCode.isNotEmpty
              ? technicianCode
              : (technicianId == null || technicianId.isEmpty)
                  ? '—'
                  : UserModel(uid: technicianId).displayId;
          final agreed = (d['agreedAmount'] ?? d['dealerRate'] ?? 0) as num;
          final duplicate = d['duplicateJobFlag'] == true;
          final paymentStatus = d['paymentStatus'] as String?;
          final agreedAmount = (d['agreedAmount'] ?? d['dealerRate'] ?? 0) as num;
          final payoutAmount = (d['technicianPayoutAmount'] as num?)?.toDouble();
          final holdAmount = (d['holdPaymentAmount'] as num?)?.toDouble();
          final warrantyStatus = d['warrantyStatus'] as String?;
          final warrantyEnd = (d['warrantyEndDate'] as Timestamp?)?.toDate();
          final warrantyStart = (d['warrantyStartDate'] as Timestamp?)?.toDate();
          final dateFormat = DateFormat('d MMM y');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Chip(label: Text('STATUS: ${status.toUpperCase()}'), backgroundColor: AppColors.primary.withValues(alpha: 0.12)),
                        Chip(label: Text('AMOUNT: ₹${agreed.toStringAsFixed(0)}')),
                        if (duplicate) const Chip(label: Text('DUPLICATE FLAG')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Job ID: ${jobCode != null && jobCode.isNotEmpty ? jobCode : jobId}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                    Text('Dealer: $displayDealerId', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                    Text('Technician: $displayTechnicianId', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
                ),
                child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (jobId.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          RouteNames.adminJobEvidenceView(jobId),
                        ),
                        icon: const Icon(Icons.folder_special_rounded),
                        label: const Text('Evidence'),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: _cardBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          RouteNames.adminServiceCompletionRecordView(jobId),
                        ),
                        icon: const Icon(Icons.assignment_rounded),
                        label: const Text('Service record'),
                      ),
                      if (dealerId != null)
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            RouteNames.adminTrustScoreHistoryForUser(dealerId),
                          ),
                          icon: const Icon(Icons.shield_rounded),
                          label: const Text('Dealer trust'),
                        ),
                      if (technicianId != null)
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            RouteNames.adminTrustScoreHistoryForUser(technicianId),
                          ),
                          icon: const Icon(Icons.shield_rounded),
                          label: const Text('Tech trust'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(RouteNames.adminFraudAlerts),
                        icon: const Icon(Icons.report_rounded),
                        label: const Text('Fraud queue'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(RouteNames.adminDisputes),
                        icon: const Icon(Icons.gavel_rounded),
                        label: const Text('Disputes'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(RouteNames.adminJobChat(jobId)),
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text('Open chat'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _PaymentLocksCard(
                paymentStatus: paymentStatus,
                agreedAmount: agreedAmount.toDouble(),
                payoutAmount: payoutAmount,
                holdAmount: holdAmount,
                jobId: jobId,
                dateFormat: dateFormat,
              ),
              const SizedBox(height: 12),
              _DisputeLinkCard(jobId: jobId),
              const SizedBox(height: 12),
              _WarrantyTimelineCard(
                jobId: jobId,
                warrantyStatus: warrantyStatus,
                warrantyStart: warrantyStart,
                warrantyEnd: warrantyEnd,
                dateFormat: dateFormat,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentLocksCard extends StatelessWidget {
  const _PaymentLocksCard({
    required this.paymentStatus,
    required this.agreedAmount,
    this.payoutAmount,
    this.holdAmount,
    required this.jobId,
    required this.dateFormat,
  });

  final String? paymentStatus;
  final double agreedAmount;
  final double? payoutAmount;
  final double? holdAmount;
  final String jobId;
  final DateFormat dateFormat;

  static String _paymentStatusLabel(String? v) {
    if (v == null || v.isEmpty) return '—';
    switch (v) {
      case 'payment_pending':
        return 'Payment pending';
      case 'payment_escrowed':
        return 'Escrowed (locked)';
      case 'approval_pending':
        return 'Approval pending';
      case 'payment_released':
        return 'Released';
      case 'warranty_hold':
        return 'Warranty hold';
      case 'warranty_released':
        return 'Warranty released';
      default:
        return v;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Payment & locks',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Row(label: 'Payment status', value: _paymentStatusLabel(paymentStatus)),
            _Row(label: 'Agreed amount', value: '₹${agreedAmount.toStringAsFixed(0)}'),
            if (payoutAmount != null)
              _Row(label: 'Technician payout', value: '₹${payoutAmount!.toStringAsFixed(0)}'),
            if (holdAmount != null && holdAmount! > 0)
              _Row(label: 'Hold amount', value: '₹${holdAmount!.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.dealerPaymentReceipts()
                  .where('jobId', isEqualTo: jobId)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                final doc = snapshot.data!.docs.first;
                final receipt = DealerPaymentReceiptModel.fromFirestore(doc);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dealer paid ₹${receipt.paymentAmount.toStringAsFixed(0)}${receipt.paymentDate != null ? ' on ${dateFormat.format(receipt.paymentDate!)}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.technicianPaymentReceipts()
                  .where('jobId', isEqualTo: jobId)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                final doc = snapshot.data!.docs.first;
                final receipt = TechnicianPaymentReceiptModel.fromFirestore(doc);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tech paid ₹${receipt.technicianPaidAmount.toStringAsFixed(0)}${receipt.transferDate != null ? ' on ${dateFormat.format(receipt.transferDate!)}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DisputeLinkCard extends StatelessWidget {
  const _DisputeLinkCard({required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.jobDisputes()
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final doc = snapshot.data!.docs.first;
        final dispute = JobDisputeModel.fromFirestore(doc);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.gavel_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dispute for this job',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${dispute.status}${dispute.createdAt != null ? ' · ${DateFormat('d MMM y').format(dispute.createdAt!)}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => context.push(RouteNames.adminDisputeDetail(dispute.id)),
                  child: const Text('View dispute'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _WarrantyTimelineCard extends StatelessWidget {
  const _WarrantyTimelineCard({
    required this.jobId,
    this.warrantyStatus,
    this.warrantyStart,
    this.warrantyEnd,
    required this.dateFormat,
  });

  final String jobId;
  final String? warrantyStatus;
  final DateTime? warrantyStart;
  final DateTime? warrantyEnd;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Warranty timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Row(
              label: 'Warranty status',
              value: warrantyStatus ?? (warrantyEnd != null && warrantyEnd!.isAfter(DateTime.now()) ? 'active' : '—'),
            ),
            if (warrantyStart != null)
              _Row(label: 'Warranty start', value: dateFormat.format(warrantyStart!)),
            if (warrantyEnd != null)
              _Row(label: 'Warranty end', value: dateFormat.format(warrantyEnd!)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.warrantyClaims()
                  .where('jobId', isEqualTo: jobId)
                  .orderBy('claimTime', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 24, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Text(
                    'No warranty claims for this job.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claims (${docs.length})',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...docs.map((doc) {
                      final claim = WarrantyClaimModel.fromFirestore(doc);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            claim.isResolved ? Icons.check_circle_outline : Icons.schedule,
                            size: 20,
                            color: claim.isResolved ? Colors.green : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(claim.statusLabel, style: Theme.of(context).textTheme.bodyMedium),
                          subtitle: Text(
                            claim.claimTime != null ? dateFormat.format(claim.claimTime!) : '—',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => context.push(RouteNames.adminWarrantyClaimDetail(claim.id)),
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => context.push(RouteNames.adminWarrantyClaims),
                      icon: const Icon(Icons.list_rounded, size: 18),
                      label: const Text('View in warranty claims'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


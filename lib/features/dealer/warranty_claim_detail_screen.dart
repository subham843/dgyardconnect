import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/warranty_claim_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/minimal_app_bar.dart';

class WarrantyClaimDetailScreen extends StatelessWidget {
  const WarrantyClaimDetailScreen({super.key, required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MinimalAppBar(
        title: 'Claim details',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.dealerWarrantyClaims),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.warrantyClaims().doc(claimId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('Claim not found'));
          }
          final claim = WarrantyClaimModel.fromFirestore(doc);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusChip(status: claim.claimStatus),
                const SizedBox(height: 16),
                _Row(label: 'Job ID', value: claim.displayJobId),
                _Row(label: 'Category', value: claim.categoryTitle ?? '—'),
                if (claim.claimTime != null)
                  _Row(
                    label: 'Raised on',
                    value: DateFormat('MMM d, yyyy • HH:mm').format(claim.claimTime!),
                  ),
                if (claim.hasResponseDeadline && claim.claimResponseDeadline != null) ...[
                  const SizedBox(height: 12),
                  _CountdownCard(deadline: claim.claimResponseDeadline!),
                ],
                const SizedBox(height: 16),
                Text(
                  'Problem description',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    claim.problemDescription,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (claim.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Photos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: claim.photoUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: claim.photoUrls[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
                if (claim.rejectionReason != null && claim.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technician rejection reason',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claim.rejectionReason!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final WarrantyClaimStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case WarrantyClaimStatus.pending:
        color = AppColors.warning;
        break;
      case WarrantyClaimStatus.technicianAccepted:
        color = AppColors.primary;
        break;
      case WarrantyClaimStatus.technicianFailed:
        color = AppColors.error;
        break;
      case WarrantyClaimStatus.replacementAssigned:
        color = AppColors.secondary;
        break;
      case WarrantyClaimStatus.resolved:
      case WarrantyClaimStatus.closed:
        color = AppColors.success;
        break;
    }
    final label = status == WarrantyClaimStatus.pending
        ? 'Pending'
        : status == WarrantyClaimStatus.technicianAccepted
            ? 'Technician accepted'
            : status == WarrantyClaimStatus.technicianFailed
                ? 'Technician failed'
                : status == WarrantyClaimStatus.replacementAssigned
                    ? 'Replacement assigned'
                    : status == WarrantyClaimStatus.resolved
                        ? 'Resolved'
                        : 'Closed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatefulWidget {
  const _CountdownCard({required this.deadline});
  final DateTime deadline;

  @override
  State<_CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<_CountdownCard> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = widget.deadline.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final isExpired = remaining.isNegative;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? AppColors.error : AppColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.schedule : Icons.timer_outlined,
            size: 28,
            color: isExpired ? AppColors.error : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Response deadline passed' : 'Technician response deadline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isExpired ? AppColors.error : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isExpired
                      ? 'Platform may assign a replacement technician.'
                      : '${hours}h ${minutes}m remaining',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

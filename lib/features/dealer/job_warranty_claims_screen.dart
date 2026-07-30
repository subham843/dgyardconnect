import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_model.dart';
import '../../shared/models/warranty_claim_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/minimal_app_bar.dart';

class DealerJobWarrantyClaimsScreen extends StatelessWidget {
  const DealerJobWarrantyClaimsScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Warranty claims')),
        body: const Center(child: Text('Sign in required')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MinimalAppBar(
        title: 'Warranty claims (job)',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(jobId).snapshots(),
        builder: (context, jobSnap) {
          final jobExists = jobSnap.data?.exists == true;
          final job = jobExists ? JobModel.fromFirestore(jobSnap.data!) : null;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.warrantyClaims()
                .where('dealerId', isEqualTo: uid)
                .where('jobId', isEqualTo: jobId)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              final docs = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]).toList();
              docs.sort((a, b) {
                final at = (a.data()['claimTime'] as Timestamp?)?.toDate();
                final bt = (b.data()['claimTime'] as Timestamp?)?.toDate();
                if (at == null && bt == null) return 0;
                if (at == null) return 1;
                if (bt == null) return -1;
                return bt.compareTo(at);
              });
              final status = (job?.warrantyStatus ?? '').trim();
              final canRaise = (status == 'active' || job?.hasActiveWarranty == true) && docs.isEmpty;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Job $jobId',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (canRaise)
                            FilledButton.icon(
                              onPressed: () => context.push(
                                RouteNames.dealerWarrantyClaimForm(jobId),
                              ),
                              icon: const Icon(Icons.warning_amber_rounded, size: 20),
                              label: const Text('Raise warranty claim'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Colors.orange,
                              ),
                            )
                          else
                            Text(
                              docs.isNotEmpty
                                  ? 'A warranty claim already exists for this job.'
                                  : 'Warranty is not active for this job.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 64,
                                color: AppColors.primary.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'No warranty claims for this job',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'If you are facing an issue under warranty, raise a claim from above.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'Claims (${docs.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final d in docs)
                      _ClaimCard(
                        claim: WarrantyClaimModel.fromFirestore(d),
                        onTap: () => context.push(
                          RouteNames.dealerWarrantyClaimDetail(d.id),
                        ),
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.onTap});
  final WarrantyClaimModel claim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = claim.isResolved
        ? AppColors.success
        : claim.isTechnicianFailed
            ? AppColors.error
            : AppColors.warning;
    final deadlineStr = claim.claimResponseDeadline != null
        ? DateFormat('MMM d, HH:mm').format(claim.claimResponseDeadline!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      claim.problemDescription,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      claim.statusLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (claim.claimTime != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Raised ${DateFormat('MMM d, yyyy').format(claim.claimTime!)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (claim.hasResponseDeadline && deadlineStr != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Technician must respond by $deadlineStr',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


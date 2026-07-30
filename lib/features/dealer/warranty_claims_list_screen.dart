import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/warranty_claim_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/minimal_app_bar.dart';

class WarrantyClaimsListScreen extends StatelessWidget {
  const WarrantyClaimsListScreen({super.key});

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
        title: 'Warranty claims',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.dealerMyJobs),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.warrantyClaims()
            .where('dealerId', isEqualTo: uid)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No warranty claims yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Raise a claim from a completed job\'s detail screen.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final claim = WarrantyClaimModel.fromFirestore(docs[index]);
              return _ClaimCard(
                claim: claim,
                onTap: () => context.push(RouteNames.dealerWarrantyClaimDetail(claim.id)),
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
                      'Job: ${claim.displayJobId}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                claim.problemDescription,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (claim.claimTime != null) ...[
                const SizedBox(height: 8),
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

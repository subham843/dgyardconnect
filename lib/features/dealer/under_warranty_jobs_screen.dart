import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/dealer_ui_kit.dart';

class DealerUnderWarrantyJobsScreen extends StatelessWidget {
  const DealerUnderWarrantyJobsScreen({super.key});

  bool _isUnderWarranty(JobModel job) {
    final status = (job.warrantyStatus ?? '').trim();
    if (status == 'active' || status == 'claim_open') return true;
    if (job.warrantyEndDate != null && job.warrantyEndDate!.isAfter(DateTime.now())) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        appBar: DealerMinimalAppBar(
          title: 'Under warranty jobs',
          onBack: () => context.go(RouteNames.dealerHome),
        ),
        body: const Center(child: Text('Sign in required.')),
      );
    }

    // Firestore-friendly query: warrantyStatus == active (plus client-side fallback).
    final query = FirestoreService.jobs()
        .where('dealerId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .limit(300);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: DealerMinimalAppBar(
        title: 'Under warranty jobs',
        onBack: () => context.go(RouteNames.dealerHome),
        actions: [
          IconButton(
            tooltip: 'Warranty claims',
            icon: const Icon(Icons.verified_rounded),
            onPressed: () => context.push(RouteNames.dealerWarrantyClaims),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final docs = snapshot.data!.docs;
          final jobs = docs.map(JobModel.fromFirestore).where(_isUnderWarranty).toList();

          if (jobs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 72, color: AppColors.primary.withValues(alpha: 0.4)),
                    const SizedBox(height: 14),
                    Text(
                      'No under-warranty jobs',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completed jobs with active warranty will appear here.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            itemCount: jobs.length,
            itemBuilder: (context, i) {
              final job = jobs[i];
              final status = job.warrantyStatus ?? (job.hasActiveWarranty ? 'active' : '—');
              final chipColor = status == 'claim_open' ? Colors.orange : AppColors.success;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DealerFloatingCard(
                  onTap: () => context.push(RouteNames.dealerJobDetail.replaceFirst(':id', job.id)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: chipColor.withValues(alpha: 0.12),
                        child: Icon(status == 'claim_open' ? Icons.warning_amber_rounded : Icons.verified_rounded, color: chipColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title ?? 'Job',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${job.displayId} • Warranty: ${status == 'claim_open' ? 'claim open' : 'active'}',
                              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (job.canRaiseWarrantyClaim)
                        OutlinedButton(
                          onPressed: () => context.push(RouteNames.dealerWarrantyClaimForm(job.id)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                            foregroundColor: Colors.orange.shade800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Claim'),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


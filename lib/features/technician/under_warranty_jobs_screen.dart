import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';

class TechnicianUnderWarrantyJobsScreen extends StatelessWidget {
  const TechnicianUnderWarrantyJobsScreen({super.key});

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
      return TechnicianLightScope(
        child: Scaffold(
          appBar: const TechnicianGlassAppBar(title: 'Under warranty jobs'),
          body: const TechnicianGlassBackground(
            child: Center(child: Text('Sign in required.')),
          ),
        ),
      );
    }

    final query = FirestoreService.jobs()
        .where('technicianId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .limit(300);

    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Under warranty jobs',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.technicianHome),
        ),
        actions: [
          IconButton(
            tooltip: 'Warranty claims',
            icon: const Icon(Icons.verified_rounded),
            onPressed: () => context.push(RouteNames.technicianWarrantyClaims),
          ),
        ],
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: TechnicianUiTokens.accent, strokeWidth: 2));
          }
          final docs = snapshot.data!.docs;
          final jobs = docs.map(JobModel.fromFirestore).where(_isUnderWarranty).toList();
          if (jobs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No completed jobs under warranty yet.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemCount: jobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final job = jobs[i];
              final status = job.warrantyStatus ?? (job.hasActiveWarranty ? 'active' : '—');
              final pendingClaim = status == 'claim_open';
              final color = pendingClaim ? AppColors.warning : AppColors.success;

              return Card(
                child: ListTile(
                  onTap: () => context.push(RouteNames.technicianJobDetail.replaceFirst(':id', job.id)),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(pendingClaim ? Icons.warning_amber_rounded : Icons.verified_rounded, color: color),
                  ),
                  title: Text(
                    job.title ?? 'Job',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${job.displayId} • Warranty: ${pendingClaim ? 'claim open' : 'active'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      )),
    ),
    );
  }
}


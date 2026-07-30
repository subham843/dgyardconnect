import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_dispute_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';

class TechnicianDisputesScreen extends StatelessWidget {
  const TechnicianDisputesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
          appBar: const TechnicianGlassAppBar(title: 'Disputes'),
          body: const TechnicianGlassBackground(
            child: Center(child: Text('Sign in required.')),
          ),
        ),
      );
    }

    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Disputes',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.technicianHome),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobDisputes()
            .where('technicianId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: TechnicianUiTokens.accent, strokeWidth: 2),
            );
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No disputes found for your jobs yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final dispute = JobDisputeModel.fromFirestore(docs[i]);
              final open = dispute.status == 'open';
              final color = open ? AppColors.warning : AppColors.success;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      open ? Icons.gavel_rounded : Icons.check_rounded,
                      color: color,
                    ),
                  ),
                  title: Text(
                    'Job ${dispute.jobId.substring(0, dispute.jobId.length >= 8 ? 8 : dispute.jobId.length)}…',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${dispute.status.toUpperCase()}\n${dispute.description}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
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


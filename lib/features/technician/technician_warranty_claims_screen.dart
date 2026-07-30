import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/warranty_claim_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';

class TechnicianWarrantyClaimsScreen extends StatelessWidget {
  const TechnicianWarrantyClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
          appBar: const TechnicianGlassAppBar(title: 'Warranty claims'),
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
        title: 'Warranty claims',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.technicianHome),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.warrantyClaims()
            .where('technicianId', isEqualTo: uid)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: TechnicianUiTokens.accent, strokeWidth: 2),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Warranty claims load nahi ho paaye.\nPlease try again.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final docs = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]).toList();
          docs.sort((a, b) {
            final at = (a.data()['claimTime'] as Timestamp?)?.toDate();
            final bt = (b.data()['claimTime'] as Timestamp?)?.toDate();
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No warranty claims yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final claim = WarrantyClaimModel.fromFirestore(docs[i]);
              final pending = claim.isPending;
              final color = pending ? AppColors.warning : AppColors.success;
              return Card(
                child: ListTile(
                  onTap: () => context.push(
                    RouteNames.technicianWarrantyClaimDetail(claim.id),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      pending ? Icons.warning_amber_rounded : Icons.check_rounded,
                      color: color,
                    ),
                  ),
                  title: Text(
                    'Job ${claim.displayJobId}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${claim.statusLabel}'
                    '${claim.categoryTitle != null ? ' • ${claim.categoryTitle}' : ''}'
                    '\n${claim.problemDescription}',
                    maxLines: 3,
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


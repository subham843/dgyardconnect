import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/technician_ui_tokens.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/widgets/technician_glass_kit.dart';

class TechnicianJobsTab extends StatelessWidget {
  const TechnicianJobsTab({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jobs', style: TechnicianUiTokens.textTitle1())
              .animate()
              .fadeIn(duration: TechnicianUiTokens.motionMedium)
              .slideY(begin: 0.06, curve: TechnicianUiTokens.motionCurve),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.jobs()
                  .where('technicianId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(60)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: TechnicianUiTokens.accent,
                      strokeWidth: 2,
                    ),
                  );
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No jobs yet',
                      style: TechnicianUiTokens.textSubhead(),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final jobId = doc.id;
                    final title = (d['title'] as String?)?.trim();
                    final status = (d['status'] ?? 'pending').toString();
                    return _JobRowGlass(
                      title: (title == null || title.isEmpty)
                          ? 'Job #${jobId.substring(0, jobId.length > 8 ? 8 : jobId.length)}'
                          : title,
                      subtitle: status,
                      onTap: () => context.push('/technician/jobs/$jobId'),
                    )
                        .animate(delay: (40 * i).ms)
                        .fadeIn(duration: TechnicianUiTokens.motionFast)
                        .slideX(begin: 0.03, curve: TechnicianUiTokens.motionCurve);
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

class _JobRowGlass extends StatelessWidget {
  const _JobRowGlass({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TechnicianUiTokens.rLg),
        child: TechnicianGlassCard(
          radius: TechnicianUiTokens.rLg,
          blurSigma: TechnicianUiTokens.blurMedium,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      TechnicianUiTokens.accent.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.5),
                    ],
                  ),
                  border: Border.all(
                    color: TechnicianUiTokens.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(Icons.work_outline_rounded, color: TechnicianUiTokens.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TechnicianUiTokens.textHeadline(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TechnicianUiTokens.textCaption1(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: TechnicianUiTokens.labelTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

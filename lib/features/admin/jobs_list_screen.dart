import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminJobsListScreen extends StatelessWidget {
  const AdminJobsListScreen({super.key});

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
          title: Text('Jobs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go(RouteNames.adminHome)),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Jobs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.jobs().orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final job = JobModel.fromFirestore(docs[index]);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  onTap: () => context.push(RouteNames.adminJobDetail(job.id)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: const Icon(Icons.work_rounded, color: AppColors.primary)),
                  title: Text(job.title ?? 'Job', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF0F172A))),
                  subtitle: Text(
                    '${job.displayId} · ${job.status.name} · ₹${(job.agreedAmount ?? job.dealerRate ?? 0).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

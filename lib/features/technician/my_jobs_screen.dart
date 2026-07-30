import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

class TechnicianMyJobsScreen extends StatefulWidget {
  const TechnicianMyJobsScreen({super.key});

  @override
  State<TechnicianMyJobsScreen> createState() => _TechnicianMyJobsScreenState();
}

enum _JobsFilter { all, running, completed }

class _TechnicianMyJobsScreenState extends State<TechnicianMyJobsScreen> {
  _JobsFilter _filter = _JobsFilter.all;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
          appBar: const TechnicianGlassAppBar(title: 'My jobs'),
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
          title: 'My Jobs',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go(RouteNames.technicianHome),
          ),
        ),
        body: TechnicianGlassBackground(
          child: StreamBuilder(
            stream: FirestoreService.jobs()
                .where('technicianId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('${AppConstants.errorGeneric} ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: TechnicianUiTokens.accent,
                    strokeWidth: 2,
                  ),
                );
              }

              final allJobs = snapshot.data!.docs.map(JobModel.fromFirestore).toList();
              final runningJobs = allJobs.where(_isRunning).toList();
              final completedJobs = allJobs.where((j) => j.status == JobStatus.completed).toList();

              final jobs = switch (_filter) {
                _JobsFilter.running => runningJobs,
                _JobsFilter.completed => completedJobs,
                _JobsFilter.all => allJobs,
              };

              final totalEarnings = allJobs
                  .fold<double>(0, (sum, j) => sum + (j.technicianPayoutAmount ?? j.agreedAmount ?? 0));

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                children: [
                  TechnicianGlassCard(
                    radius: 24,
                    blurSigma: 28,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Total earnings',
                            value: '₹${totalEarnings.toStringAsFixed(0)}',
                            color: AppColors.brandWarmSoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Total jobs',
                            value: '${allJobs.length}',
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TechnicianGlassCard(
                    radius: 20,
                    blurSigma: 26,
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FilterChip(
                            label: 'All',
                            active: _filter == _JobsFilter.all,
                            onTap: () => setState(() => _filter = _JobsFilter.all),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FilterChip(
                            label: 'Running',
                            active: _filter == _JobsFilter.running,
                            onTap: () => setState(() => _filter = _JobsFilter.running),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FilterChip(
                            label: 'Completed',
                            active: _filter == _JobsFilter.completed,
                            onTap: () => setState(() => _filter = _JobsFilter.completed),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (jobs.isEmpty)
                    TechnicianGlassCard(
                      radius: 24,
                      blurSigma: 28,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 18),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_late_outlined,
                            size: 56,
                            color: TechnicianUiTokens.labelTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text('No jobs yet', style: TechnicianUiTokens.textTitle2()),
                        ],
                      ),
                    )
                  else
                    ...jobs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final job = entry.value;
                      final amount = job.technicianPayoutAmount ?? job.agreedAmount ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _JobGlassCard(
                          job: job,
                          amount: amount,
                          onTap: () => context.push(
                            RouteNames.technicianJobDetail.replaceFirst(':id', job.id),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: i * 36))
                            .slideY(begin: 0.03, curve: Curves.easeOutCubic),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _isRunning(JobModel job) {
  return {
    JobStatus.inProgress,
    JobStatus.pendingDealerConfirm,
    JobStatus.paid,
    JobStatus.agreed,
    JobStatus.paymentPending,
    JobStatus.bidding,
    JobStatus.posted,
  }.contains(job.status);
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TechnicianUiTokens.textCaption1()),
        const SizedBox(height: 6),
        Text(
          value,
          style: TechnicianUiTokens.textLargeTitle(color: color).copyWith(fontSize: 30),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: active ? TechnicianUiTokens.accent.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.45),
            border: Border.all(
              color: active
                  ? TechnicianUiTokens.accent.withValues(alpha: 0.35)
                  : TechnicianUiTokens.hairlineOnGlass,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TechnicianUiTokens.textCaption1(
                color: active ? TechnicianUiTokens.accent : TechnicianUiTokens.labelSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JobGlassCard extends StatefulWidget {
  const _JobGlassCard({
    required this.job,
    required this.amount,
    required this.onTap,
  });

  final JobModel job;
  final double amount;
  final VoidCallback onTap;

  @override
  State<_JobGlassCard> createState() => _JobGlassCardState();
}

class _JobGlassCardState extends State<_JobGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final (badgeText, badgeColor) = _statusView(widget.job.status);
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: TechnicianGlassCard(
        radius: 20,
        blurSigma: 26,
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TechnicianUiTokens.accentSoft,
                ),
                child: Icon(_jobIcon(widget.job), color: TechnicianUiTokens.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.title?.trim().isNotEmpty == true
                          ? widget.job.title!.trim()
                          : 'Job #${widget.job.displayId}',
                      style: TechnicianUiTokens.textHeadline(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.28)),
                      ),
                      child: Text(
                        badgeText,
                        style: TechnicianUiTokens.textCaption2(color: badgeColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDateTime(widget.job.createdAt),
                      style: TechnicianUiTokens.textCaption2(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${widget.amount.toStringAsFixed(0)}',
                    style: TechnicianUiTokens.textTitle2(color: TechnicianUiTokens.accent),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right_rounded, color: TechnicianUiTokens.labelTertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(String, Color) _statusView(JobStatus status) {
  if (status == JobStatus.completed) return ('Completed', const Color(0xFF059669));
  if (_isRunningStatus(status)) return ('Running', AppColors.brandWarmLight);
  return ('Pending', const Color(0xFFEA580C));
}

bool _isRunningStatus(JobStatus status) {
  return {
    JobStatus.inProgress,
    JobStatus.pendingDealerConfirm,
    JobStatus.paid,
    JobStatus.agreed,
    JobStatus.paymentPending,
  }.contains(status);
}

IconData _jobIcon(JobModel job) {
  final title = (job.title ?? '').toLowerCase();
  if (title.contains('cctv')) return Icons.videocam_outlined;
  if (title.contains('ac') || title.contains('air')) return Icons.ac_unit_rounded;
  return Icons.handyman_rounded;
}

String _formatDateTime(DateTime? dt) {
  if (dt == null) return 'Date unavailable';
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yy = dt.year.toString();
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'PM' : 'AM';
  return '$dd/$mm/$yy • $h:$m $ap';
}

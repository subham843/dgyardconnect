import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';
import '../../shared/services/account_completion_guard.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';

class TechnicianQuickStartScreen extends StatelessWidget {
  const TechnicianQuickStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
          appBar: const TechnicianGlassAppBar(title: 'Quick start'),
          body: const TechnicianGlassBackground(
            child: Center(child: Text(AppConstants.signInRequired)),
          ),
        ),
      );
    }

    return TechnicianLightScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: TechnicianGlassAppBar(
          title: 'Quick Start',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go(RouteNames.technicianHome),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.users().doc(uid).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final approved = data?['approved'] as bool? ?? false;
            final kycStatus = (data?['kycStatus'] as String?) ?? 'pending';
            final skills = data?['skills'] as List<dynamic>? ?? const [];
            final serviceArea = data?['serviceArea'] as Map<String, dynamic>?;
            final hasServiceArea = serviceArea != null && serviceArea.isNotEmpty;
            final hasSkills = skills.isNotEmpty;
            final hasSettlement = (data?['bankDetails'] as Map<String, dynamic>?)?.isNotEmpty == true;

            final steps = <_QuickStep>[
              _QuickStep(
                done: true,
                title: 'View profile',
                subtitle: 'Check name and contact details',
                icon: Icons.person_rounded,
                onTap: () => context.push(RouteNames.technicianProfile),
              ),
              _QuickStep(
                done: approved,
                title: 'Approval status',
                subtitle: approved
                    ? 'Your profile is approved'
                    : 'Pending approval (you’ll get a notification)',
                icon: approved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                onTap: () => context.push(RouteNames.technicianKyc),
              ),
              _QuickStep(
                done: _isKycVerified(kycStatus),
                title: 'Complete KYC',
                subtitle: _kycSubtitle(kycStatus),
                icon: Icons.verified_user_rounded,
                requiredPill: !_isKycVerified(kycStatus),
                highlight: !_isKycVerified(kycStatus),
                onTap: approved
                    ? () async {
                        final allowed =
                            await AccountCompletionGuard.ensureTechnicianCanOpenKyc(
                          context,
                        );
                        if (!context.mounted || !allowed) return;
                        context.push(RouteNames.technicianKyc);
                      }
                    : null,
              ),
              _QuickStep(
                done: hasSkills,
                title: 'Add skills',
                subtitle: hasSkills
                    ? 'Skills added'
                    : 'Select sectors and sub-options you can service',
                icon: Icons.workspace_premium_rounded,
                onTap: approved
                    ? () => context.push(RouteNames.technicianEditSkills)
                    : null,
              ),
              _QuickStep(
                done: hasServiceArea,
                title: 'Set service area',
                subtitle: hasServiceArea
                    ? 'Service area saved'
                    : 'Set your working radius on map',
                icon: Icons.map_rounded,
                onTap: approved
                    ? () => context.push(RouteNames.technicianEditServiceArea)
                    : null,
              ),
              _QuickStep(
                done: hasSettlement,
                title: 'Add settlement account',
                subtitle: hasSettlement
                    ? 'Settlement account added'
                    : 'Required to withdraw earnings',
                icon: Icons.account_balance_rounded,
                onTap: approved
                    ? () => context.push(RouteNames.technicianSettlementAccount)
                    : null,
              ),
            ];

            final completed = steps.where((s) => s.done).length;
            final pending = steps.where((s) => !s.done).toList();
            final done = steps.where((s) => s.done).toList();
            final progress = steps.isEmpty ? 0.0 : completed / steps.length;

            final cta = !_isKycVerified(kycStatus) ? 'Complete KYC Now' : 'Finish Setup';
            final onCtaTap = !_isKycVerified(kycStatus)
                ? () async {
                    final allowed = await AccountCompletionGuard.ensureTechnicianCanOpenKyc(context);
                    if (!context.mounted || !allowed) return;
                    context.push(RouteNames.technicianKyc);
                  }
                : () => context.push(RouteNames.technicianHome);

            return Stack(
              children: [
                const Positioned.fill(
                  child: TechnicianGlassBackground(child: SizedBox.shrink()),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
                  children: [
                    TechnicianGlassCard(
                      radius: TechnicianUiTokens.rXl,
                      blurSigma: TechnicianUiTokens.blurHeavy,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You\'re almost ready!', style: TechnicianUiTokens.textTitle2()),
                          const SizedBox(height: 4),
                          Text(
                            'Complete remaining steps to start receiving jobs',
                            style: TechnicianUiTokens.textSubhead(),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.45),
                              color: AppColors.brandWarmLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$completed/${steps.length} steps completed',
                            style: TechnicianUiTokens.textCaption2(),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _pill(
                                context,
                                approved ? 'Approved' : 'Under review',
                                approved ? AppColors.success : AppColors.warning,
                              ),
                              _pill(
                                context,
                                _isKycVerified(kycStatus) ? 'KYC Verified' : 'KYC Pending',
                                _isKycVerified(kycStatus)
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...pending.map(
                      (s) => _stepTile(context, step: s).paddingOnly(bottom: 10),
                    ),
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Completed steps',
                        style: TechnicianUiTokens.textCaption1(
                          color: TechnicianUiTokens.labelSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...done.map(
                        (s) => Opacity(
                          opacity: 0.78,
                          child: _stepTile(context, step: s).paddingOnly(bottom: 8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Start earning once setup is complete',
                      textAlign: TextAlign.center,
                      style: TechnicianUiTokens.textCaption1(),
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18,
                  child: _QuickStartCta(label: cta, onTap: onCtaTap),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  static Widget _stepTile(BuildContext context, {required _QuickStep step}) {
    final color = step.done ? AppColors.success : AppColors.warning;
    final tile = _QuickStepTile(step: step, color: color);
    if (step.highlight) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TechnicianUiTokens.rLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: tile,
      );
    }
    return tile;
  }

  static bool _isKycVerified(String status) => status == 'verified';

  static String _kycSubtitle(String status) {
    switch (status) {
      case 'verified':
        return 'KYC verified';
      case 'rejected':
        return 'KYC rejected — resubmit documents';
      default:
        return 'Upload Aadhaar and PAN documents';
    }
  }

}

class _QuickStep {
  const _QuickStep({
    required this.done,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlight = false,
    this.requiredPill = false,
  });

  final bool done;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlight;
  final bool requiredPill;
}

class _QuickStepTile extends StatefulWidget {
  const _QuickStepTile({required this.step, required this.color});
  final _QuickStep step;
  final Color color;

  @override
  State<_QuickStepTile> createState() => _QuickStepTileState();
}

class _QuickStepTileState extends State<_QuickStepTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: TechnicianGlassCard(
        radius: TechnicianUiTokens.rLg,
        blurSigma: TechnicianUiTokens.blurMedium,
        padding: const EdgeInsets.all(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.step.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.step.done ? Icons.check_rounded : widget.step.icon,
                    color: widget.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.step.title,
                              style: TechnicianUiTokens.textHeadline(),
                            ),
                          ),
                          if (widget.step.requiredPill)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Required',
                                style: TechnicianUiTokens.textCaption2(
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(widget.step.subtitle, style: TechnicianUiTokens.textSubhead()),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: TechnicianUiTokens.labelTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStartCta extends StatelessWidget {
  const _QuickStartCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandWarmLight.withValues(alpha: 0.92),
                AppColors.brandWarmSoft,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TechnicianUiTokens.textHeadline(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

extension _WidgetPadX on Widget {
  Widget paddingOnly({double bottom = 0}) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: this,
      );
}


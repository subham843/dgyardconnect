import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';
import '../../shared/models/user_model.dart';
import '../../shared/router/app_router.dart';
import '../../shared/services/account_completion_guard.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/squircle_avatar.dart';
import '../../shared/widgets/technician_glass_kit.dart';

class TechnicianProfileScreen extends StatelessWidget {
  const TechnicianProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: TechnicianGlassAppBar(
            title: 'Profile',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.go(RouteNames.technicianHome),
            ),
          ),
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
          title: 'Profile',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go(RouteNames.technicianHome),
          ),
        ),
        body: TechnicianGlassBackground(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.users().doc(uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                );
              }
              final doc = snapshot.data!;
              if (!doc.exists) {
                return const Center(child: Text('Profile not found.'));
              }

              final user = UserModel.fromFirestore(doc);
              final raw = doc.data() ?? const <String, dynamic>{};
              final profile = user.profile ?? {};

              final name = (profile['name'] as String? ?? '').trim();
              final email = (user.email ?? '').trim();
              final phone = (profile['phone'] as String? ?? '').trim();
              final photoUrl = profile['photoUrl'] as String?;
              final alternatePhone = (profile['alternatePhone'] as String? ?? '').trim();
              final dobStr = (profile['dateOfBirth'] as String? ?? '').trim();
              final dob = dobStr.isNotEmpty ? DateTime.tryParse(dobStr) : null;
              final dobDisplay = dob != null ? DateFormat('dd-MM-yyyy').format(dob) : '';
              final gender = (profile['gender'] as String? ?? '').trim();
              final maritalStatus = (profile['maritalStatus'] as String? ?? '').trim();
              final pending = raw['profilePendingApproval'] as bool? ?? false;
              final kycStatus = (raw['kycStatus'] as String? ?? 'pending').trim();
              final kycLabel = _kycLabel(kycStatus);
              final kycColor = _kycBadgeColor(kycStatus);
              final missingFields = AccountCompletionGuard.technicianMissingFields(raw);

              final usage = raw['jobLimitUsage'] as Map<String, dynamic>? ?? {};
              final overrides = raw['jobLimitOverrides'] as Map<String, dynamic>? ?? {};
              final techUsed = (usage['technicianAccepted'] as num?)?.toInt() ?? 0;
              final techLimitOverride =
                  (overrides['technicianAcceptFreeLimit'] as num?)?.toInt();

              final shownName = name.isEmpty ? 'Technician' : name;
              final shownEmail = email.isEmpty ? 'Add details' : email;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                children: [
                  _ProfileHeaderCard(
                    name: shownName,
                    email: shownEmail,
                    photoUrl: photoUrl,
                    onEdit: () => context.push(RouteNames.technicianEditProfile),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.04),
                  if (pending) ...[
                    const SizedBox(height: 12),
                    TechnicianGlassCard(
                      radius: TechnicianUiTokens.rLg,
                      blurSigma: TechnicianUiTokens.blurMedium,
                      padding: const EdgeInsets.all(14),
                      child: const Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: AppColors.warning),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Profile update pending approval.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (missingFields.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TechnicianGlassCard(
                      radius: TechnicianUiTokens.rLg,
                      blurSigma: TechnicianUiTokens.blurMedium,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Profile incomplete: ${missingFields.length} field(s) remaining - ${missingFields.join(', ')}',
                              style: TechnicianUiTokens.textSubhead(
                                color: TechnicianUiTokens.warning,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TechnicianGlassCard(
                    radius: TechnicianUiTokens.rXl,
                    blurSigma: TechnicianUiTokens.blurHeavy,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Personal Info', style: TechnicianUiTokens.textHeadline()),
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: phone),
                        _InfoRow(
                          icon: Icons.call_rounded,
                          label: 'Alternate Phone',
                          value: alternatePhone,
                        ),
                        _InfoRow(
                          icon: Icons.cake_rounded,
                          label: 'Date of Birth',
                          value: dobDisplay,
                        ),
                        _InfoRow(icon: Icons.wc_rounded, label: 'Gender', value: gender),
                        _InfoRow(
                          icon: Icons.favorite_rounded,
                          label: 'Marital Status',
                          value: maritalStatus,
                          isLast: true,
                        ),
                      ],
                    ),
                  ).animate(delay: 60.ms).fadeIn(duration: 220.ms).slideY(begin: 0.04),
                  const SizedBox(height: 12),
                  TechnicianGlassCard(
                    radius: TechnicianUiTokens.rXl,
                    blurSigma: TechnicianUiTokens.blurHeavy,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('KYC Status', style: TechnicianUiTokens.textHeadline()),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: kycColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: kycColor.withValues(alpha: 0.32)),
                              ),
                              child: Text(
                                kycLabel == 'Verified' ? 'Approved' : kycLabel,
                                style: TechnicianUiTokens.textCaption1(color: kycColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          kycLabel == 'Verified'
                              ? 'Your KYC is approved and active.'
                              : 'Complete KYC to unlock full profile access and fast approvals.',
                          style: TechnicianUiTokens.textSubhead(),
                        ),
                        const SizedBox(height: 12),
                        _ActionButton(
                          label: 'Complete KYC',
                          icon: Icons.arrow_forward_rounded,
                          onTap: () async {
                            final allowed =
                                await AccountCompletionGuard.ensureTechnicianCanOpenKyc(
                              context,
                            );
                            if (!context.mounted || !allowed) return;
                            context.push(RouteNames.technicianKyc);
                          },
                        ),
                      ],
                    ),
                  ).animate(delay: 120.ms).fadeIn(duration: 240.ms).slideY(begin: 0.04),
                  const SizedBox(height: 12),
                  TechnicianGlassCard(
                    radius: TechnicianUiTokens.rXl,
                    blurSigma: TechnicianUiTokens.blurHeavy,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.stacked_line_chart_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text('Account Usage', style: TechnicianUiTokens.textHeadline()),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _MetricRow(label: 'Job acceptance limit', value: '$techUsed used'),
                        _MetricRow(
                          label: 'Free limit override',
                          value: techLimitOverride?.toString() ?? 'Default',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'After free limit, an acceptance fee may apply as per admin config.',
                          style: TechnicianUiTokens.textCaption2(),
                        ),
                      ],
                    ),
                  ).animate(delay: 170.ms).fadeIn(duration: 260.ms).slideY(begin: 0.04),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Edit Profile',
                          icon: Icons.edit_rounded,
                          onTap: () => context.push(RouteNames.technicianEditProfile),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          label: 'Logout',
                          icon: Icons.logout_rounded,
                          destructive: true,
                          onTap: () async {
                            await AuthService().signOut();
                            if (context.mounted) {
                              rootNavigatorKey.currentContext?.go(AuthPostLogin.postLogoutRoute());
                            }
                          },
                        ),
                      ),
                    ],
                  ).animate(delay: 220.ms).fadeIn(duration: 280.ms),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: TechnicianUiTokens.rXl,
      blurSigma: TechnicianUiTokens.blurHeavy,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.55),
                      AppColors.primaryLight.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SquircleAvatar(
                    size: 84,
                    photoUrl: photoUrl,
                    backgroundColor: Colors.white.withValues(alpha: 0.84),
                    fallbackText: name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'T',
                    fallbackTextColor: AppColors.primaryDark,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.92),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TechnicianUiTokens.textTitle1()),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TechnicianUiTokens.textSubhead(
                    color: TechnicianUiTokens.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _kycLabel(String status) {
  switch (status) {
    case 'verified':
      return 'Verified';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Pending';
  }
}

Color _kycBadgeColor(String status) {
  switch (status) {
    case 'verified':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    default:
      return AppColors.warning;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: TechnicianUiTokens.separator),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TechnicianUiTokens.textCaption2(
                    color: TechnicianUiTokens.labelSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : 'Add details',
                  style: TechnicianUiTokens.textSubhead(
                    color: hasValue
                        ? TechnicianUiTokens.labelPrimary
                        : TechnicianUiTokens.labelTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TechnicianUiTokens.textSubhead())),
          Text(value, style: TechnicianUiTokens.textHeadline()),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final start = widget.destructive
        ? AppColors.error.withValues(alpha: 0.9)
        : AppColors.primary;
    final end = widget.destructive ? AppColors.error : AppColors.primaryDark;
    const fg = Colors.white;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [start, end],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: fg, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TechnicianUiTokens.textSubhead(color: fg).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


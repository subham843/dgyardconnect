import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/technician_ui_tokens.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/auth_post_login.dart';
import '../../../shared/widgets/technician_glass_kit.dart';
import 'technician_shell_actions.dart';

/// Profile tab: keep brand mostly neutral + blue accents (less saffron).
const _kIconMuted = Color(0xFF64748B);
const _kIconAccent = Color(0xFF5A7BFF);
const _kIconTeal = Color(0xFF0D9488);

class TechnicianProfileTab extends StatelessWidget {
  const TechnicianProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Center(
        child: Text(
          'Sign in required.',
          style: TechnicianUiTokens.textSubhead(),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final profile = data['profile'] as Map<String, dynamic>? ?? {};
        final name = (profile['name'] as String?)?.trim();
        final photoUrl = (profile['photoUrl'] as String?)?.trim();
        final kycStatus = (data['kycStatus'] as String?)?.trim().toLowerCase() ?? 'pending';
        final kycVerified = kycStatus == 'verified';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 128),
          children: [
            Text('Profile', style: TechnicianUiTokens.textTitle1())
                .animate()
                .fadeIn(duration: TechnicianUiTokens.motionMedium)
                .slideY(begin: 0.06, curve: TechnicianUiTokens.motionCurve),
            const SizedBox(height: 14),
            _ProfileHeader(
              name: name?.isNotEmpty == true ? name! : 'Technician',
              photoUrl: photoUrl,
              kycVerified: kycVerified,
              onEditTap: () => context.push(RouteNames.technicianEditProfile),
            ),
            if (!kycVerified) ...[
              const SizedBox(height: 12),
              _KycAlertCard(onTap: () => openTechnicianKycWithProfileGate(context)),
            ],
            const SizedBox(height: 14),
            const _ProfileSectionTitle('Account'),
            _ProfileSectionCard(
              children: [
                _ProfileItem(
                  label: 'My profile',
                  icon: Icons.person_rounded,
                  iconColor: _kIconAccent,
                  onTap: () => context.push(RouteNames.technicianProfile),
                ),
                _ProfileItem(
                  label: 'Edit profile',
                  icon: Icons.edit_rounded,
                  iconColor: _kIconMuted,
                  onTap: () => context.push(RouteNames.technicianEditProfile),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _ProfileSectionTitle('Work Setup'),
            _ProfileSectionCard(
              children: [
                _ProfileItem(
                  label: 'KYC',
                  icon: Icons.verified_user_rounded,
                  iconColor: kycVerified ? AppColors.success : AppColors.warning,
                  badgeText: kycVerified ? 'Verified' : 'Pending',
                  badgeColor: kycVerified ? AppColors.success : AppColors.warning,
                  onTap: () => openTechnicianKycWithProfileGate(context),
                ),
                _ProfileItem(
                  label: 'Skills',
                  icon: Icons.handyman_rounded,
                  iconColor: _kIconTeal,
                  onTap: () => context.push(RouteNames.technicianEditSkills),
                ),
                _ProfileItem(
                  label: 'Service area',
                  icon: Icons.location_on_rounded,
                  iconColor: _kIconTeal,
                  onTap: () => context.push(RouteNames.technicianEditServiceArea),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _ProfileSectionTitle('App'),
            _ProfileSectionCard(
              children: [
                _ProfileItem(
                  label: 'Settings',
                  icon: Icons.settings_rounded,
                  iconColor: _kIconMuted,
                  onTap: () => context.push(RouteNames.settings),
                ),
                _ProfileItem(
                  label: 'Notifications',
                  icon: Icons.notifications_rounded,
                  iconColor: _kIconMuted,
                  onTap: () => context.push(RouteNames.technicianNotifications),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _ProfileSectionTitle('Support'),
            _ProfileSectionCard(
              children: [
                _ProfileItem(
                  label: 'Help & support',
                  icon: Icons.support_agent_rounded,
                  iconColor: _kIconMuted,
                  onTap: () => context.push(RouteNames.supportHomeForRole('technician')),
                ),
                _ProfileItem(
                  label: 'Legal',
                  icon: Icons.gavel_rounded,
                  iconColor: _kIconMuted,
                  onTap: () => context.push(RouteNames.legalMenu),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LogoutDangerCard(
              onTap: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  rootNavigatorKey.currentContext?.go(AuthPostLogin.postLogoutRoute());
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.photoUrl,
    required this.kycVerified,
    required this.onEditTap,
  });

  final String name;
  final String? photoUrl;
  final bool kycVerified;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: 18,
      blurSigma: TechnicianUiTokens.blurHeavy,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFE8EEF7),
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: TechnicianUiTokens.textHeadline(color: _kIconAccent),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TechnicianUiTokens.textTitle2()),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: (kycVerified ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.16),
                  ),
                  child: Text(
                    kycVerified ? 'KYC Verified' : 'KYC Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kycVerified ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditTap,
            icon: const Icon(Icons.edit_rounded, color: _kIconMuted),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.04);
  }
}

class _KycAlertCard extends StatelessWidget {
  const _KycAlertCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: 16,
      blurSigma: TechnicianUiTokens.blurMedium,
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete your KYC to receive payments',
                  style: TechnicianUiTokens.textSubhead(color: const Color(0xFF92400E)),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: TechnicianUiTokens.labelTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        title,
        style: TechnicianUiTokens.textCaption1(color: TechnicianUiTokens.labelSecondary),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: 16,
      blurSigma: TechnicianUiTokens.blurMedium,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                color: TechnicianUiTokens.separator.withValues(alpha: 0.6),
                indent: 64,
                endIndent: 12,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: iconColor.withValues(alpha: 0.14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TechnicianUiTokens.textHeadline()),
              ),
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: (badgeColor ?? AppColors.warning).withValues(alpha: 0.16),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right_rounded, color: TechnicianUiTokens.labelTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutDangerCard extends StatelessWidget {
  const _LogoutDangerCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Material(
        color: const Color(0xFFFEE2E2).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Logout',
                    style: TechnicianUiTokens.textHeadline(color: const Color(0xFFB91C1C)),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

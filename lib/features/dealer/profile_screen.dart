import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/trust_reputation_constants.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/account_completion_guard.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/dealer_ui_kit.dart';

class DealerProfileScreen extends StatelessWidget {
  const DealerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: DealerMinimalAppBar(
          title: 'Profile',
          onBack: () => context.go(RouteNames.dealerHome),
        ),
        body: const Center(child: Text(AppConstants.signInRequired)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: DealerMinimalAppBar(
        title: 'Profile',
        onBack: () => context.go(RouteNames.dealerHome),
        actions: [
          if (FirestoreService.isAvailable)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.users().doc(uid).snapshots(),
              builder: (context, snapshot) {
                final approved = snapshot.data?.data()?['approved'] as bool? ?? false;
                return IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    color: approved ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: approved ? () => context.push(RouteNames.dealerEditProfile) : null,
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.users().doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('Profile not found.'));
          }
          final user = UserModel.fromFirestore(doc);
          final profile = user.profile ?? {};
          final data = doc.data() ?? {};
          final proposed = data['proposedProfile'] as Map<String, dynamic>? ?? {};
          final profileToShow = (data['profilePendingApproval'] as bool? ?? false) && proposed.isNotEmpty ? proposed : profile;
          final name = profileToShow['name'] as String? ?? profile['name'] as String? ?? '—';
          final phone = profileToShow['phone'] as String? ?? profile['phone'] as String? ?? '—';
          final photoUrl = profile['photoUrl'] as String?;
          final dobStr = profileToShow['dateOfBirth'] as String? ?? profile['dateOfBirth'] as String?;
          final dobStr2 = dobStr != null && dobStr.isNotEmpty
              ? (() {
                  final d = DateTime.tryParse(dobStr);
                  return d != null ? DateFormat('dd-MM-yyyy').format(d) : '—';
                })()
              : '—';
          final gender = profileToShow['gender'] as String? ?? profile['gender'] as String? ?? '—';
          final maritalStatus = profileToShow['maritalStatus'] as String? ?? profile['maritalStatus'] as String? ?? '—';
          final pending = doc.data()?['profilePendingApproval'] as bool? ?? false;
          final approved = doc.data()?['approved'] as bool? ?? false;
          final usage = doc.data()?['jobLimitUsage'] as Map<String, dynamic>? ?? {};
          final overrides = doc.data()?['jobLimitOverrides'] as Map<String, dynamic>? ?? {};
          final used = (usage['dealerPosted'] as num?)?.toInt() ?? 0;
          final limitOverride = (overrides['dealerPostFreeLimit'] as num?)?.toInt();
          final missingFields = AccountCompletionGuard.dealerMissingFields(data);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: DealerSquircleAvatar(
                    photoUrl: photoUrl,
                    size: 96,
                    fallbackText: name.isNotEmpty ? name.substring(0, 1) : 'D',
                  ),
                ).animate().fadeIn().scale(curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                if (pending)
                  DealerFloatingCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: AppColors.warning, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Profile update pending approval.',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                if (pending) const SizedBox(height: 20),
                if (missingFields.isNotEmpty) ...[
                  DealerFloatingCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Profile incomplete: ${missingFields.length} field(s) remaining - ${missingFields.join(', ')}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                DealerFloatingCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Name', value: name),
                      _InfoRow(label: 'Email', value: user.email ?? '—'),
                      _InfoRow(label: 'Phone', value: phone),
                      _InfoRow(label: 'Date of Birth', value: dobStr2),
                      _InfoRow(label: 'Gender', value: gender),
                      _InfoRow(label: 'Marital Status', value: maritalStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _DealerTrustScoreCard(uid: uid),
                const SizedBox(height: 12),
                _DealerServiceSectorsCard(uid: uid, approved: approved),
                const SizedBox(height: 12),
                _DealerServiceAreaCard(uid: uid, approved: approved),
                const SizedBox(height: 20),
                DealerFloatingCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job posting limit',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Used: $used',
                        style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                      ),
                      Text(
                        'Custom free limit: ${limitOverride?.toString() ?? 'Default'}',
                        style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'After free limit, platform commission may apply (as per admin config).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DealerFloatingCard(
                  onTap: approved
                      ? () async {
                          final allowed =
                              await AccountCompletionGuard.ensureDealerCanOpenKyc(context);
                          if (!context.mounted || !allowed) return;
                          context.push(RouteNames.dealerKyc);
                        }
                      : null,
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'KYC',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DealerFloatingCard(
                  onTap: approved ? () => context.push(RouteNames.dealerSettlementAccount) : null,
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Settlement Account',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DealerFloatingCard(
                  onTap: () {},
                  child: Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Help & Support',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealerTrustScoreCard extends StatelessWidget {
  const _DealerTrustScoreCard({required this.uid});
  final String uid;

  static String? _levelKeyFromScore(double? score) {
    if (score == null) return null;
    if (score >= 85) return 'elite';
    if (score >= 70) return 'trusted';
    if (score >= 50) return 'standard';
    if (score >= 25) return 'risky';
    return 'restricted';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snapshot) {
        final score = (snapshot.data?.data()?['trustScore'] as num?)?.toDouble();
        final levelKey = _levelKeyFromScore(score);
        final levelLabel = levelKey != null ? TrustReputationConstants.labelForReputationLevel(levelKey) : '—';
        return DealerFloatingCard(
          onTap: () => context.push(RouteNames.supportFaqForRole('dealer')),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.shield_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trust score',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score != null ? '${score.toInt()}/100 · $levelLabel' : '—',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'How it works',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        );
      },
    );
  }
}

class _DealerServiceSectorsCard extends StatelessWidget {
  const _DealerServiceSectorsCard({required this.uid, required this.approved});
  final String uid;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    return DealerFloatingCard(
      onTap: approved ? () => context.push(RouteNames.dealerEditProfile) : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.category_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.users().doc(uid).snapshots(),
              builder: (context, userSnap) {
                final sectorIds = (userSnap.data?.data()?['dealerSectors'] as List<dynamic>?)?.cast<String>() ?? [];
                if (sectorIds.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service sectors',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Not set · Tap to add',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  );
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.sectorSubOptions().snapshots(),
                  builder: (context, subSnap) {
                    final docs = subSnap.data?.docs ?? [];
                    final names = <String>[];
                    for (final id in sectorIds) {
                      final d = docs.where((e) => e.id == id).firstOrNull;
                      if (d != null) names.add(d.data()['name'] as String? ?? id);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service sectors',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          names.isEmpty ? sectorIds.join(', ') : names.join(', '),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class _DealerServiceAreaCard extends StatelessWidget {
  const _DealerServiceAreaCard({required this.uid, required this.approved});
  final String uid;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    return DealerFloatingCard(
      onTap: approved ? () => context.push(RouteNames.dealerEditProfile) : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.users().doc(uid).snapshots(),
              builder: (context, snapshot) {
                final sa = snapshot.data?.data()?['serviceArea'] as Map<String, dynamic>?;
                final label = (sa?['city'] ?? sa?['addressLabel']) as String?;
                final hasArea = label != null && label.toString().trim().isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service area',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasArea ? label : 'Not set · Tap to add',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

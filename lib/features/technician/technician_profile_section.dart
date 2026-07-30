import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:go_router/go_router.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_ui_tokens.dart';
import '../../core/constants/trust_reputation_constants.dart';
import '../../shared/services/area_count_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/brand_kit_provider.dart';
import '../../shared/widgets/brand_squircle_icon.dart';
import '../../shared/widgets/level_badge.dart';
import '../../shared/widgets/squircle_avatar.dart';

/// Hero-area profile content: photo, name, level, ratings, service area, dealers count, KYC.
/// For use inside the collapsible dashboard hero (white/light text on gradient).
class TechnicianHeroProfileContent extends StatelessWidget {
  const TechnicianHeroProfileContent({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ),
          );
        }
        final data = userSnapshot.data!.data();
        final profile = data?['profile'] as Map<String, dynamic>? ?? {};
        final avgRating = (data?['avgRating'] as num?)?.toDouble();
        final serviceArea = data?['serviceArea'] as Map<String, dynamic>?;
        final serviceTown =
            (serviceArea?['city'] ?? serviceArea?['addressLabel']) as String? ??
            'Service Area';
        final levelRaw =
            data?['adminOverrideLevel'] as String? ??
            data?['technicianLevel'] as String?;
        final levelLabel = levelRaw != null && levelRaw.isNotEmpty
            ? TrustReputationConstants.labelForTechnicianLevel(levelRaw)
            : null;
        final kycStatus = data?['kycStatus'] as String? ?? 'pending';
        final approved = data?['approved'] as bool? ?? false;
        final isOnline = approved ? (data?['online'] as bool? ?? false) : false;
        final availabilityStatus = data?['availabilityStatus'] as String?;
        final isBusy = availabilityStatus == 'busy';
        final trustScore = (data?['trustScore'] as num?)?.toDouble();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.jobs()
              .where('technicianId', isEqualTo: uid)
              .snapshots(),
          builder: (context, jobsSnapshot) {
            int totalRatings = 0;
            double ratingSum = 0;
            final dealerIds = <String>{};
            if (jobsSnapshot.hasData) {
              for (final doc in jobsSnapshot.data!.docs) {
                final d = doc.data();
                final dealerRating = _toStarValue(
                  d['dealerRatingToTechnician'],
                );
                final customerRating = _toStarValue(
                  d['customerRatingToTechnician'],
                );
                if (dealerRating != null) {
                  ratingSum += dealerRating;
                  totalRatings++;
                }
                if (customerRating != null) {
                  ratingSum += customerRating;
                  totalRatings++;
                }
                final did = d['dealerId'] as String?;
                if (did != null) dealerIds.add(did);
              }
            }
            final calculatedAvg = totalRatings > 0
                ? ratingSum / totalRatings
                : (avgRating ?? 0.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo left + app name & tagline right (from brand kit)
                    Builder(
                      builder: (context) {
                        final kit = BrandKitProvider.of(context);
                        final appName = kit.appName ?? 'D.G.Yard Connect';
                        final tagline =
                            kit.tagline ?? 'Connect. Dispatch. Deliver.';
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandSquircleIcon(
                              size: 56,
                              glowBlur: 0,
                              glowSpread: 0,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    appName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tagline,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // User name | Badge | Total ratings | Stars (left aligned)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        profile['name'] as String? ??
                                            'Technician',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      if (levelLabel != null &&
                                          levelLabel.isNotEmpty) ...[
                                        LevelBadge(
                                          label: levelLabel,
                                          color: _levelColor(
                                            levelRaw ?? levelLabel,
                                          ),
                                        ),
                                      ],
                                      if ((avgRating != null &&
                                              avgRating > 0) ||
                                          totalRatings > 0) ...[
                                        Text(
                                          '${calculatedAvg.toStringAsFixed(1)}/$totalRatings',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        ...List.generate(5, (i) {
                                          final filled =
                                              i < calculatedAvg.round();
                                          return Icon(
                                            filled
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            size: 12,
                                            color: filled
                                                ? const Color(0xFFFFD54F)
                                                : Colors.white.withValues(
                                                    alpha: 0.5,
                                                  ),
                                          );
                                        }),
                                      ],
                                      TextButton(
                                        onPressed: () =>
                                            _showReviewsModal(context, uid),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 0,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text(
                                          'View all',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.white
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Service area + Dealers (in area) + KYC row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              icon: Icons.location_on_rounded,
                              label: 'Service area',
                              value: serviceTown,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          Expanded(
                            child: FutureBuilder<int>(
                              future: AreaCountService.getDealerCountInArea(serviceArea),
                              builder: (context, snap) {
                                final inArea = snap.data ?? 0;
                                final display = inArea > 0
                                    ? '$inArea'
                                    : (dealerIds.isEmpty ? '—' : '${dealerIds.length}');
                                return _HeroStat(
                                  icon: Icons.store_rounded,
                                  label: 'Dealers',
                                  value: display,
                                );
                              },
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          Expanded(
                            child: _HeroStat(
                              icon: kycStatus == 'verified'
                                  ? Icons.verified_rounded
                                  : Icons.pending_rounded,
                              label: 'KYC',
                              value: _kycLabel(kycStatus),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trustScore != null) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => context.push(
                          RouteNames.supportFaqForRole('technician'),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded, size: 18, color: Colors.white.withValues(alpha: 0.95)),
                              const SizedBox(width: 6),
                              Text(
                                'Trust ${trustScore.toInt()}/100',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.info_outline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Online/Offline – button + short formal hint
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeroOnlineOfflineButton(
                            uid: uid,
                            isOnline: isOnline,
                            approved: approved,
                            isBusy: isBusy,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Stay Offline when you\'re not available for work. Switch to Online when you\'re ready to accept jobs.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Color _levelColor(String level) {
    final l = level.toLowerCase();
    if (l == 'bronze') return AppColors.bronze;
    if (l == 'silver') return AppColors.silver;
    if (l == 'gold') return AppColors.gold;
    if (l == 'elite' || l == 'platinum') return AppColors.elite;
    if (l == 'trainee') {
      return const Color(0xFFFFD54F); // Amber - visible on gradient
    }
    return const Color(0xFFFFD54F); // Default amber for other levels
  }

  static double? _toStarValue(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final d = v.toDouble();
      return d >= 1 && d <= 5 ? d : null;
    }
    if (v is String) {
      final d = double.tryParse(v);
      return d != null && d >= 1 && d <= 5 ? d : null;
    }
    return null;
  }

  static String _kycLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  static void _showReviewsModal(BuildContext context, String technicianId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReviewsModal(technicianId: technicianId),
    );
  }
}

class _HeroOnlineOfflineButton extends StatelessWidget {
  const _HeroOnlineOfflineButton({
    required this.uid,
    required this.isOnline,
    required this.approved,
    this.isBusy = false,
  });

  final String uid;
  final bool isOnline;
  final bool approved;
  final bool isBusy;

  static const _busyMessage =
      'You are currently assigned to an active job. Complete the job to become available.';

  @override
  Widget build(BuildContext context) {
    final isBusyState = isBusy;
    final label = isBusyState ? 'Busy' : (isOnline ? 'Online' : 'Offline');
    final color = isBusyState
        ? Colors.amber
        : (isOnline ? AppColors.success : const Color(0xFF94A3B8));
    final dotColor = isBusyState
        ? Colors.amber
        : (isOnline ? Colors.white : const Color(0xFF94A3B8));

    return GestureDetector(
      onTap: () async {
        if (!approved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your profile is under review. You will receive a notification when approved, then you can go online.',
              ),
            ),
          );
          return;
        }
        if (isBusyState) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text(_busyMessage)));
          return;
        }
        try {
          if (isOnline) {
            await FirestoreService.users().doc(uid).update({
              'availabilityStatus': 'offline',
              'online': false,
            });
          } else {
            await FirestoreService.users().doc(uid).update({
              'availabilityStatus': 'online',
              'online': true,
            });
          }
        } catch (_) {}
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isBusyState
              ? color.withValues(alpha: 0.9)
              : (isOnline
                    ? AppColors.success.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isBusyState
                ? color.withValues(alpha: 0.7)
                : (isOnline
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.35)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  if (isOnline && !isBusyState)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Apple-quality user profile section: ratings, service town, location, profile pic.
/// Tap "View Reviews" to see dealers and customers reviews in separate sections.
class TechnicianProfileSection extends StatelessWidget {
  const TechnicianProfileSection({
    super.key,
    required this.uid,
    this.forHeader = false,
  });

  final String uid;

  /// When true, uses a more opaque background for visibility on gradient headers.
  final bool forHeader;

  @override
  Widget build(BuildContext context) {
    final forHeader = this.forHeader;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();
        final data = userSnapshot.data!.data();
        final profile = data?['profile'] as Map<String, dynamic>? ?? {};
        final name = profile['name'] as String? ?? 'Technician';
        final photoUrl = profile['photoUrl'] as String?;
        final avgRating = (data?['avgRating'] as num?)?.toDouble();
        final serviceArea = data?['serviceArea'] as Map<String, dynamic>?;
        final serviceTown =
            (serviceArea?['city'] ?? serviceArea?['addressLabel']) as String? ??
            'Service Area';

        return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService.jobs()
                    .where('technicianId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, jobsSnapshot) {
                  int totalRatings = 0;
                  if (jobsSnapshot.hasData) {
                    for (final doc in jobsSnapshot.data!.docs) {
                      final d = doc.data();
                      if (d['dealerRatingToTechnician'] != null) totalRatings++;
                      if (d['customerRatingToTechnician'] != null) {
                        totalRatings++;
                      }
                    }
                  }

                  final cardColor = forHeader
                      ? Colors.white.withValues(alpha: 0.92)
                      : AppColors.primary.withValues(alpha: 0.06);
                  final borderColor = forHeader
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppColors.primary.withValues(alpha: 0.12);

                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Profile picture
                              SquircleAvatar(
                                size: 72,
                                photoUrl: photoUrl,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                fallbackText: name.isNotEmpty ? name[0] : 'T',
                                fallbackTextColor: AppColors.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (avgRating != null) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          ...List.generate(5, (i) {
                                            final filled =
                                                i < avgRating.round();
                                            return Icon(
                                              filled
                                                  ? Icons.star_rounded
                                                  : Icons.star_outline_rounded,
                                              size: 18,
                                              color: filled
                                                  ? const Color(0xFFFFB800)
                                                  : AppColors.textSecondary
                                                        .withValues(alpha: 0.4),
                                            );
                                          }),
                                          const SizedBox(width: 6),
                                          Text(
                                            avgRating.toStringAsFixed(1),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (totalRatings > 0) ...[
                                            Text(
                                              '  ·  ',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    color: AppColors
                                                        .textSecondary
                                                        .withValues(alpha: 0.6),
                                                  ),
                                            ),
                                            Text(
                                              '$totalRatings total',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 16,
                                          color: AppColors.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            serviceTown,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () =>
                                          _showReviewsModal(context, uid),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: AppColors.primary,
                                      ),
                                      child: Text(
                                        'View all reviews',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  void _showReviewsModal(BuildContext context, String technicianId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReviewsModal(technicianId: technicianId),
    );
  }
}

class _ReviewsModal extends StatelessWidget {
  const _ReviewsModal({required this.technicianId});

  final String technicianId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TechnicianUiTokens.rXl)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(TechnicianUiTokens.rXl)),
                border: Border.all(color: TechnicianUiTokens.separator),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TechnicianUiTokens.labelTertiary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          'Reviews & Ratings',
                          style: TechnicianUiTokens.textTitle1(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.jobs()
                          .where('technicianId', isEqualTo: technicianId)
                          .snapshots(),
                      builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: TechnicianUiTokens.accent,
                          strokeWidth: 2,
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final dealerReviews = <Map<String, dynamic>>[];
                    final customerReviews = <Map<String, dynamic>>[];
                    for (final doc in docs) {
                      final d = doc.data();
                      final dealerRating = d['dealerRatingToTechnician'];
                      final dealerReview =
                          d['dealerReviewToTechnician'] as String?;
                      final customerRating = d['customerRatingToTechnician'];
                      final customerReview =
                          d['customerReviewToTechnician'] as String?;
                      if (dealerRating != null) {
                        dealerReviews.add({
                          'jobId': doc.id,
                          'dealerId': d['dealerId'],
                          'rating': (dealerRating as num).toInt(),
                          'review': dealerReview,
                          'jobTitle': d['title'] as String?,
                        });
                      }
                      if (customerRating != null) {
                        customerReviews.add({
                          'jobId': doc.id,
                          'rating': (customerRating as num).toInt(),
                          'review': customerReview,
                          'jobTitle': d['title'] as String?,
                        });
                      }
                    }
                    if (dealerReviews.isEmpty && customerReviews.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 64,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete jobs to receive reviews',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      children: [
                        if (dealerReviews.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Dealer Reviews',
                            count: dealerReviews.length,
                            color: AppColors.secondary,
                            icon: Icons.store_rounded,
                          ),
                          const SizedBox(height: 12),
                          ...dealerReviews.map(
                            (r) => _DealerReviewCard(data: r),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (customerReviews.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Customer Reviews',
                            count: customerReviews.length,
                            color: TechnicianUiTokens.accent,
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 12),
                          ...customerReviews.map(
                            (r) => _CustomerReviewCard(data: r),
                          ),
                        ],
                      ],
                    );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _DealerReviewCard extends StatelessWidget {
  const _DealerReviewCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirestoreService.users().doc(data['dealerId'] as String?).get(),
      builder: (context, snapshot) {
        final dealerName = snapshot.data?.data()?['profile'] is Map
            ? ((snapshot.data!.data()!['profile'] as Map)['name'] as String?)
            : null;
        return _ReviewCard(
          reviewerName: dealerName ?? 'Dealer',
          rating: data['rating'] as int,
          review: data['review'] as String?,
          accentColor: AppColors.secondary,
          jobTitle: data['jobTitle'] as String?,
        );
      },
    );
  }
}

class _CustomerReviewCard extends StatelessWidget {
  const _CustomerReviewCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
        return _ReviewCard(
      reviewerName: 'Customer',
      rating: data['rating'] as int,
      review: data['review'] as String?,
      accentColor: TechnicianUiTokens.accent,
      jobTitle: data['jobTitle'] as String?,
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.reviewerName,
    required this.rating,
    this.review,
    required this.accentColor,
    this.jobTitle,
  });

  final String reviewerName;
  final int rating;
  final String? review;
  final Color accentColor;
  final String? jobTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
        border: Border.all(color: TechnicianUiTokens.hairlineOnGlass),
        boxShadow: TechnicianUiTokens.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reviewerName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: filled
                        ? const Color(0xFFFFB800)
                        : AppColors.textSecondary.withValues(alpha: 0.3),
                  );
                }),
              ),
            ],
          ),
          if (jobTitle != null && jobTitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              jobTitle!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (review != null && review!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Call from anywhere to show technician reviews & ratings bottom sheet.
void showTechnicianReviewsModal(BuildContext context, String technicianId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReviewsModal(technicianId: technicianId),
  );
}

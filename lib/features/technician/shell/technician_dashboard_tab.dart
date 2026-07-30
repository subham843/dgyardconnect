import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/remote_config/app_remote_config_controller_export.dart';
import '../../marketplace/config/marketplace_feature_flags.dart';
import '../../calculator/presentation/calculator_screens.dart';
import '../../../core/theme/technician_ui_tokens.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/widgets/status_reels_strip.dart';
import '../../../shared/widgets/home_shortcuts_banner.dart';
import '../../../shared/widgets/glass_ui_kit.dart';
import '../../../shared/widgets/technician_glass_kit.dart';
import '../slider_ads_section.dart';
import '../../../shared/widgets/brand_kit_provider.dart';
import '../../../shared/widgets/brand_squircle_icon.dart';
import '../technician_profile_section.dart' show showTechnicianReviewsModal;
import 'technician_shell_actions.dart';

const _kTechScreenPadding = 16.0;
const _kTechGap = 12.0;
const _kTechSectionGap = 22.0;

class TechnicianDashboardTab extends StatefulWidget {
  const TechnicianDashboardTab({
    super.key,
    required this.uid,
    required this.guideKeys,
    this.onTopTabChanged,
  });

  final String uid;
  final Map<String, GlobalKey> guideKeys;
  final ValueChanged<int>? onTopTabChanged;

  @override
  State<TechnicianDashboardTab> createState() => _TechnicianDashboardTabState();
}

class _TechnicianDashboardTabState extends State<TechnicianDashboardTab> {
  int _topTabIndex = 0;
  late final TextEditingController _homeSearchCtrl;

  @override
  void initState() {
    super.initState();
    _homeSearchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _homeSearchCtrl.dispose();
    super.dispose();
  }

  void _setTopTab(int index) {
    if (_topTabIndex == index) return;
    setState(() => _topTabIndex = index);
    widget.onTopTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(widget.uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final profile = data?['profile'] as Map<String, dynamic>? ?? {};
        final fullName = (profile['name'] as String?)?.trim();
        final firstName = (fullName == null || fullName.isEmpty)
            ? 'Technician'
            : fullName.split(RegExp(r'\s+')).first;
        final photoUrl = profile['photoUrl'] as String?;
        final approved = data?['approved'] as bool? ?? false;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  _kTechGap,
                  _kTechScreenPadding,
                  0,
                ),
                child: _TechnicianTopSearchRow(
                  searchCtrl: _homeSearchCtrl,
                  onSubmitSearch: (_) => context.push(RouteNames.technicianMyJobs),
                  onNotificationsTap: () => context.push(RouteNames.technicianNotifications),
                  onSettingsTap: () => context.push(RouteNames.settings),
                  onProfileTap: () => context.push(RouteNames.technicianProfile),
                  profilePhotoUrl: photoUrl,
                  fallbackName: firstName,
                ),
              )
                  .animate()
                  .fadeIn(duration: TechnicianUiTokens.motionMedium)
                  .slideY(begin: 0.05, curve: TechnicianUiTokens.motionCurve),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  18,
                  _kTechScreenPadding,
                  2,
                ),
                child: _TechnicianDashboardHeading(firstName: firstName),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  14,
                  _kTechScreenPadding,
                  8,
                ),
                child: _TechnicianTopTabStrip(
                  index: _topTabIndex,
                  onChanged: _setTopTab,
                ),
              ),
            ),
            if (_topTabIndex == 0) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  8,
                  _kTechScreenPadding,
                  10,
                ),
                child: _QuickStats(uid: widget.uid),
              )
                  .animate(delay: 50.ms)
                  .fadeIn(duration: TechnicianUiTokens.motionMedium)
                  .slideY(begin: 0.04, curve: TechnicianUiTokens.motionCurve),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  _kTechSectionGap,
                  _kTechScreenPadding,
                  0,
                ),
                child: _HeroGlass(
                  uid: widget.uid,
                  approved: approved,
                  onPrimary: () => approved
                      ? context.push(RouteNames.technicianMyJobs)
                      : showTechnicianUnderReviewDialog(context),
                  onSecondary: () => context.push(RouteNames.technicianQuickStart),
                ),
              )
                  .animate(delay: 60.ms)
                  .fadeIn(duration: TechnicianUiTokens.motionMedium)
                  .slideY(begin: 0.06, curve: TechnicianUiTokens.motionCurve),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  8,
                  _kTechScreenPadding,
                  10,
                ),
                child: Text('Shortcuts', style: TechnicianUiTokens.textHeadline()),
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: TechnicianUiTokens.motionFast),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  0,
                  _kTechScreenPadding,
                  _kTechGap,
                ),
                child: Consumer<AppRemoteConfigController>(
                  builder: (context, rc, _) {
                    final mp = MarketplaceFeatureFlags.isMarketplaceEnabled(rc.config);
                    return _TechnicianDashboardShortcutsSection(
                      guideKeys: widget.guideKeys,
                      marketplaceEnabled: mp,
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(6, _kTechGap, 6, 8),
                child: _CompactPosterBanner(),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _kTechScreenPadding,
                      _kTechSectionGap,
                      _kTechScreenPadding,
                      6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sponsored ads',
                            style: TechnicianUiTokens.textHeadline(),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: TechnicianUiTokens.labelTertiary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(TechnicianUiTokens.rPill),
                            border: Border.all(color: TechnicianUiTokens.separator),
                          ),
                          child: Text(
                            'Ad',
                            style: TechnicianUiTokens.textCaption2(color: TechnicianUiTokens.labelSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: _kTechScreenPadding),
                      child: TechnicianGlassCard(
                        radius: TechnicianUiTokens.rXl,
                        blurSigma: TechnicianUiTokens.blurMedium,
                        padding: EdgeInsets.all(10),
                        child: SliderAdsSection(heroMode: false),
                      ),
                    ),
                  ),
                ],
              )
                  .animate(delay: 220.ms)
                  .fadeIn(duration: TechnicianUiTokens.motionMedium)
                  .slideY(begin: 0.03, curve: TechnicianUiTokens.motionCurve),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _kTechScreenPadding,
                  0,
                  _kTechScreenPadding,
                  120,
                ),
                child: StatusReelsStrip(role: 'technician'),
              ),
            ),
            ] else if (_topTabIndex == 1) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kTechScreenPadding,
                    18,
                    _kTechScreenPadding,
                    120,
                  ),
                  child: const CalculatorPanel(),
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kTechScreenPadding,
                    18,
                    _kTechScreenPadding,
                    12,
                  ),
                  child: _TechnicianSellBuyPanel(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _greetingLine(String firstName) {
  final hour = DateTime.now().hour;
  final base = (hour >= 4 && hour < 12)
      ? 'Good morning'
      : (hour >= 12 && hour < 17)
          ? 'Good afternoon'
          : (hour >= 17 && hour < 21)
              ? 'Good evening'
              : 'Good night';
  return '$base, $firstName';
}

class _TechnicianTopTabStrip extends StatelessWidget {
  const _TechnicianTopTabStrip({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;
  static const double _gap = 10;
  static const double _radiusLarge = 28;
  static const double _radiusSmall = 22;

  static const Color _ink = Color(0xFF1C1C1E);
  static const Color _inkSoft = Color(0xFF64748B);

  static double _cellEmphasis(int tabIndex, int selectedIndex) {
    return tabIndex == selectedIndex ? 1.0 : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final e0 = _cellEmphasis(0, index);
    final e1 = _cellEmphasis(1, index);
    final e2 = _cellEmphasis(2, index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopPrimaryTabCard(
          emphasis: e0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(height: _gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TopSecondaryTabCard(
                title: 'Estimate Cost',
                subtitle: 'Cost estimate for your jobs',
                icon: Icons.calculate_rounded,
                emphasis: e1,
                borderRadius: _radiusSmall,
                palette: _TopTabPalette.estimate,
                onTap: () => onChanged(1),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _TopSecondaryTabCard(
                title: 'Buy Equipment',
                subtitle: 'Buy & sell tools and parts',
                icon: Icons.shopping_cart_rounded,
                emphasis: e2,
                borderRadius: _radiusSmall,
                palette: _TopTabPalette.shop,
                onTap: () => onChanged(2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopPrimaryTabCard extends StatelessWidget {
  const _TopPrimaryTabCard({required this.emphasis, required this.onTap});

  final double emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutCubic.transform(emphasis.clamp(0.0, 1.0));
    final scale = lerpDouble(0.985, 1.0, e)!;
    final r = BorderRadius.circular(_TechnicianTopTabStrip._radiusLarge);

    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9EC4FF).withValues(alpha: 0.2),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.11),
              blurRadius: 22,
              spreadRadius: -1,
              offset: Offset(0, 7 + e * 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.075),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: r,
                splashColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                highlightColor: Colors.black.withValues(alpha: 0.04),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.68),
                        const Color(0xFFD6E7FF).withValues(alpha: 0.56),
                        const Color(0xFF9EC4FF).withValues(alpha: 0.15),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    border: Border.all(
                      color: e > 0.55
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.3 + 0.18 * e)
                          : const Color(0xFF93C5FD).withValues(alpha: 0.35),
                      width: e > 0.55 ? 1.9 : 1.25,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.5),
                                const Color(0xFF9EC4FF).withValues(alpha: 0.18),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.handyman_rounded,
                            color: Color(0xFF2563EB),
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Find Job',
                                style: GoogleFonts.inter(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Search and connect with field jobs',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                  height: 1.28,
                                  letterSpacing: -0.08,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF64748B),
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSecondaryTabCard extends StatelessWidget {
  const _TopSecondaryTabCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emphasis,
    required this.borderRadius,
    required this.palette,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double emphasis;
  final double borderRadius;
  final _TopTabPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutCubic.transform(emphasis.clamp(0.0, 1.0));
    final scale = lerpDouble(0.98, 1.0, e)!;

    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: palette.icon.withValues(alpha: 0.12),
              highlightColor: Colors.black.withValues(alpha: 0.04),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.64),
                      palette.glassMid.withValues(alpha: 0.52),
                      palette.patternTint.withValues(alpha: 0.12),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(
                    color: e > 0.55
                        ? palette.borderActive.withValues(alpha: 0.28 + 0.22 * e)
                        : Color.lerp(
                            Colors.white.withValues(alpha: 0.72),
                            palette.borderIdleBlend.withValues(alpha: 0.24),
                            0.35,
                          )!,
                    width: e > 0.55 ? 1.75 : 1.15,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.55),
                      blurRadius: 2,
                      spreadRadius: -1,
                      offset: const Offset(-0.5, -1.5),
                    ),
                    BoxShadow(
                      color: palette.shadowTint.withValues(alpha: 0.09),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: Offset(0, 5 + 2 * e),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05 + 0.035 * e),
                      blurRadius: 14 + 6 * e,
                      offset: Offset(0, 6 + 2 * e),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: palette.icon, size: 26),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _TechnicianTopTabStrip._ink,
                          letterSpacing: -0.35,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: _TechnicianTopTabStrip._inkSoft,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopTabPalette {
  const _TopTabPalette({
    required this.patternTint,
    required this.glassMid,
    required this.icon,
    required this.borderActive,
    required this.borderIdleBlend,
    required this.shadowTint,
  });

  final Color patternTint;
  final Color glassMid;
  final Color icon;
  final Color borderActive;
  final Color borderIdleBlend;
  final Color shadowTint;

  static final _TopTabPalette estimate = _TopTabPalette(
    patternTint: const Color(0xFF8EECC4),
    glassMid: Color.lerp(Colors.white, const Color(0xFF8EECC4), 0.22)!,
    icon: const Color(0xFF0F766E),
    borderActive: const Color(0xFF14B8A6),
    borderIdleBlend: const Color(0xFF5EEAD4),
    shadowTint: const Color(0xFF0D9488),
  );

  static final _TopTabPalette shop = _TopTabPalette(
    patternTint: const Color(0xFFFFDCA8),
    glassMid: Color.lerp(Colors.white, const Color(0xFFFFDCA8), 0.26)!,
    icon: const Color(0xFFC2410C),
    borderActive: const Color(0xFFF59E0B),
    borderIdleBlend: const Color(0xFFFCD34D),
    shadowTint: const Color(0xFFD97706),
  );
}

class _TechnicianSellBuyPanel extends StatelessWidget {
  const _TechnicianSellBuyPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppRemoteConfigController>(
      builder: (context, rc, _) {
        final mp = MarketplaceFeatureFlags.isMarketplaceEnabled(rc.config);
        if (!mp) {
          return TechnicianGlassCard(
            radius: TechnicianUiTokens.rXl,
            blurSigma: TechnicianUiTokens.blurHeavy,
            padding: const EdgeInsets.all(20),
            child: Text(
              'The supply hub is off for your region right now. Check back soon or contact support.',
              style: TechnicianUiTokens.textSubhead(),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supply & sales', style: TechnicianUiTokens.textHeadline()),
            const SizedBox(height: 10),
            _TechShopHeroCard(
              title: 'Browse shop',
              subtitle: 'CCTV, networking & security products',
              icon: Icons.shopping_bag_outlined,
              accent: const Color(0xFF34C759),
              onTap: () => context.push(RouteNames.shopHome),
            ),
            const SizedBox(height: 12),
            _TechShopHeroCard(
              title: 'My orders',
              subtitle: 'Track purchases, reorder anytime',
              icon: Icons.description_outlined,
              accent: const Color(0xFF0A84FF),
              onTap: () => context.push(RouteNames.accountOrders),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TechShopCompactCard(
                    label: 'My account',
                    icon: Icons.person_outline_rounded,
                    onTap: () => context.push(RouteNames.accountHome),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TechShopCompactCard(
                    label: 'Cart',
                    icon: Icons.shopping_cart_outlined,
                    onTap: () => context.push(RouteNames.shopCart),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TechShopHeroCard extends StatelessWidget {
  const _TechShopHeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: TechnicianUiTokens.rXl,
      blurSigma: TechnicianUiTokens.blurHeavy,
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TechnicianUiTokens.rXl),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TechnicianUiTokens.textHeadline()),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TechnicianUiTokens.textCaption1()),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: TechnicianUiTokens.labelSecondary),
          ],
        ),
      ),
    );
  }
}

class _TechShopCompactCard extends StatelessWidget {
  const _TechShopCompactCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: TechnicianUiTokens.rLg,
      blurSigma: TechnicianUiTokens.blurMedium,
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TechnicianUiTokens.rLg),
        child: Row(
          children: [
            Icon(icon, color: TechnicianUiTokens.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TechnicianUiTokens.textCaption1(color: TechnicianUiTokens.labelPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: TechnicianUiTokens.labelTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TechnicianTopSearchRow extends StatelessWidget {
  const _TechnicianTopSearchRow({
    required this.searchCtrl,
    required this.onSubmitSearch,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onProfileTap,
    required this.profilePhotoUrl,
    required this.fallbackName,
  });

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSubmitSearch;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;
  final String? profilePhotoUrl;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _DealerLikeSearchBar(ctrl: searchCtrl, onSubmitted: onSubmitSearch),
        ),
        const SizedBox(width: 12),
        _DealerLikeActionIcon(
          icon: Icons.notifications_none_rounded,
          iconColor: AppColors.brandWarmLight,
          showBadge: true,
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: 10),
        _DealerLikeActionIcon(
          icon: Icons.settings_outlined,
          iconColor: const Color(0xFF8E8E93),
          onTap: onSettingsTap,
        ),
        const SizedBox(width: 10),
        _DealerLikeAvatarChip(
          photoUrl: profilePhotoUrl,
          fallbackName: fallbackName,
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

class _DealerLikeSearchBar extends StatelessWidget {
  const _DealerLikeSearchBar({required this.ctrl, required this.onSubmitted});

  final TextEditingController ctrl;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    const r = 22.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 9),
            spreadRadius: -3,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(0, -1.5),
          ),
        ],
      ),
      child: GlassBox(
        radius: r,
        opacity: 0.52,
        blurSigma: 28,
        showBorder: true,
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
          ),
          child: TextField(
            controller: ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.15,
              height: 1.25,
              color: const Color(0xFF1C1C1E),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search jobs, sites...',
              hintStyle: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
                color: const Color(0xFF636366).withValues(alpha: 0.68),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.4),
                size: 20,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _DealerLikeActionIcon extends StatelessWidget {
  const _DealerLikeActionIcon({
    required this.icon,
    required this.iconColor,
    this.showBadge = false,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const r = 16.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Material(
                color: Colors.white.withValues(alpha: 0.52),
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(icon, color: iconColor, size: 21),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
      ],
    );
  }
}

class _DealerLikeAvatarChip extends StatelessWidget {
  const _DealerLikeAvatarChip({
    required this.photoUrl,
    required this.fallbackName,
    required this.onTap,
  });

  final String? photoUrl;
  final String fallbackName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            backgroundImage: (photoUrl != null && photoUrl!.trim().isNotEmpty)
                ? NetworkImage(photoUrl!.trim())
                : null,
            child: (photoUrl == null || photoUrl!.trim().isEmpty)
                ? Text(
                    fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : 'T',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _TechnicianDashboardHeading extends StatelessWidget {
  const _TechnicianDashboardHeading({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TECHNICIAN DASHBOARD',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.25,
            color: const Color(0xFF3A3A41),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _greetingLine(firstName),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.42),
            letterSpacing: -0.15,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _CompactPosterBanner extends StatelessWidget {
  const _CompactPosterBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const HomeShortcutsBanner(role: 'technician'),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroGlass extends StatelessWidget {
  const _HeroGlass({
    required this.uid,
    required this.approved,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String uid;
  final bool approved;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final kit = BrandKitProvider.of(context);
    final appName = kit.appName ?? 'D.G.Yard Connect';
    final punchline = kit.tagline ?? 'Trusted service. Faster payouts.';

    return TechnicianGlassCard(
      radius: TechnicianUiTokens.rXl,
      blurSigma: TechnicianUiTokens.blurHeavy,
      padding: const EdgeInsets.all(18),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.users().doc(uid).snapshots(),
        builder: (context, userSnap) {
          final avgRating = (userSnap.data?.data()?['avgRating'] as num?)?.toDouble();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.jobs().where('technicianId', isEqualTo: uid).snapshots(),
            builder: (context, jobsSnap) {
              int totalRatings = 0;
              double sum = 0;
              if (jobsSnap.hasData) {
                for (final doc in jobsSnap.data!.docs) {
                  final d = doc.data();
                  final dealer = d['dealerRatingToTechnician'];
                  final customer = d['customerRatingToTechnician'];
                  if (dealer is num) {
                    sum += dealer.toDouble();
                    totalRatings++;
                  }
                  if (customer is num) {
                    sum += customer.toDouble();
                    totalRatings++;
                  }
                }
              }
              final effectiveAvg =
                  totalRatings > 0 ? (sum / totalRatings) : (avgRating ?? 0.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BrandSquircleIcon(
                        size: 44,
                        glowBlur: 0,
                        glowSpread: 0,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appName,
                              style: TechnicianUiTokens.textTitle2(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              punchline,
                              style: TechnicianUiTokens.textSubhead(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your workspace',
                          style: TechnicianUiTokens.textHeadline(),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: approved
                              ? TechnicianUiTokens.success.withValues(alpha: 0.12)
                              : TechnicianUiTokens.warning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(TechnicianUiTokens.rPill),
                          border: Border.all(color: TechnicianUiTokens.separator),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              approved ? Icons.check_circle_rounded : Icons.schedule_rounded,
                              size: 15,
                              color: approved ? TechnicianUiTokens.success : TechnicianUiTokens.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              approved ? 'Approved' : 'In review',
                              style: TechnicianUiTokens.textCaption2(color: TechnicianUiTokens.labelPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(TechnicianUiTokens.rPill),
                          border: Border.all(color: TechnicianUiTokens.separator),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(5, (i) {
                              final filled = i < effectiveAvg.round();
                              return Icon(
                                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 14,
                                color: filled
                                    ? TechnicianUiTokens.warning
                                    : TechnicianUiTokens.labelTertiary.withValues(alpha: 0.5),
                              );
                            }),
                            const SizedBox(width: 6),
                            Text(
                              effectiveAvg > 0 ? effectiveAvg.toStringAsFixed(1) : '—',
                              style: TechnicianUiTokens.textCaption1(color: TechnicianUiTokens.labelPrimary),
                            ),
                            if (totalRatings > 0)
                              Text(
                                '  ·  $totalRatings',
                                style: TechnicianUiTokens.textCaption2(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => showTechnicianReviewsModal(context, uid),
                          borderRadius: BorderRadius.circular(TechnicianUiTokens.rPill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: TechnicianUiTokens.accentSoft,
                              borderRadius: BorderRadius.circular(TechnicianUiTokens.rPill),
                              border: Border.all(color: TechnicianUiTokens.separator),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.rate_review_rounded, size: 15, color: TechnicianUiTokens.accent),
                                const SizedBox(width: 6),
                                Text(
                                  'Reviews',
                                  style:
                                      TechnicianUiTokens.textCaption2(color: TechnicianUiTokens.labelPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Accept jobs, track earnings, and keep your profile sharp — all in one calm place.',
                    style: TechnicianUiTokens.textSubhead(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroCta(
                          label: 'Open jobs',
                          icon: Icons.work_outline_rounded,
                          filled: true,
                          onTap: onPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroCta(
                          label: 'Quick start',
                          icon: Icons.bolt_rounded,
                          filled: false,
                          onTap: onSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
            gradient: filled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFB347),
                      const Color(0xFFF97316),
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.62),
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: 0.3)
                  : TechnicianUiTokens.hairlineOnGlass,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppColors.brandWarmLight.withValues(alpha: 0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: filled ? Colors.white : AppColors.brandWarmLight,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TechnicianUiTokens.textCaption1(
                    color: filled ? Colors.white : AppColors.brandWarmLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechnicianDashboardShortcutsSection extends StatelessWidget {
  const _TechnicianDashboardShortcutsSection({
    required this.guideKeys,
    required this.marketplaceEnabled,
  });

  final Map<String, GlobalKey> guideKeys;
  final bool marketplaceEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Main actions', style: TechnicianUiTokens.textCaption1()),
        const SizedBox(height: 8),
        _TechShortcutHero(
          tileKey: guideKeys['incoming'],
          label: 'Incoming jobs',
          subtitle: 'Open and respond quickly',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFF97316),
          onTap: () => context.push(RouteNames.technicianIncomingJob),
        ),
        const SizedBox(height: _kTechGap),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 98,
                child: _TechShortcutTile(
                  tileKey: guideKeys['my_jobs'],
                  label: 'My jobs',
                  icon: Icons.work_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => context.push(RouteNames.technicianMyJobs),
                ),
              ),
            ),
            const SizedBox(width: _kTechGap),
            Expanded(
              child: SizedBox(
                height: 98,
                child: _TechShortcutTile(
                  tileKey: guideKeys['payouts'],
                  label: 'Payouts',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => context.push(RouteNames.technicianPayoutHistory),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _kTechSectionGap),
        Text('Account', style: TechnicianUiTokens.textCaption1()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 98,
                child: _TechShortcutTile(
                  tileKey: guideKeys['wallet'],
                  label: 'Wallet',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF22C55E),
                  onTap: () => context.push(RouteNames.technicianWallet),
                ),
              ),
            ),
            const SizedBox(width: _kTechGap),
            Expanded(
              child: SizedBox(
                height: 98,
                child: _TechShortcutTile(
                  tileKey: guideKeys['profile'],
                  label: 'Profile',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push(RouteNames.technicianProfile),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _kTechSectionGap),
        Text('Services', style: TechnicianUiTokens.textCaption1()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 98,
                child: _TechShortcutTile(
                  tileKey: guideKeys['warranty'],
                  label: 'Warranty',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => context.push(RouteNames.technicianWarrantyClaims),
                ),
              ),
            ),
            const SizedBox(width: _kTechGap),
            Expanded(
              child: SizedBox(
                height: 98,
                child: _TechShortcutTile(
                  tileKey: guideKeys['receipts'],
                  label: 'Records',
                  icon: Icons.assignment_rounded,
                  color: const Color(0xFF38BDF8),
                  onTap: () => context.push(RouteNames.technicianPaymentReceipts),
                ),
              ),
            ),
            const SizedBox(width: _kTechGap),
            Expanded(
              child: SizedBox(
                height: 98,
                child: _TechShortcutTile(
                  tileKey: guideKeys['skills'],
                  label: 'Documents',
                  icon: Icons.folder_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => context.push(RouteNames.technicianEditSkills),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const PageStorageKey<String>('technician_dashboard_view_all_shortcuts'),
            tilePadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
            collapsedShape: const RoundedRectangleBorder(),
            shape: const RoundedRectangleBorder(),
            visualDensity: VisualDensity.compact,
            title: Text(
              'View all shortcuts',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFF64748B),
              size: 26,
            ),
            children: [
              const SizedBox(height: 2),
              SizedBox(
                height: 88,
                width: double.infinity,
                child: _TechShortcutTile(
                  tileKey: guideKeys['uw_jobs'],
                  label: 'Under warranty',
                  icon: Icons.security_update_good_rounded,
                  color: const Color(0xFF14B8A6),
                  onTap: () => context.push(RouteNames.technicianUnderWarrantyJobs),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TechShortcutHero extends StatelessWidget {
  const _TechShortcutHero({
    required this.tileKey,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Key? tileKey;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: TechnicianUiTokens.rXl,
      blurSigma: TechnicianUiTokens.blurHeavy,
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: tileKey,
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TechnicianUiTokens.textTitle2()),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TechnicianUiTokens.textSubhead()),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: TechnicianUiTokens.labelSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechShortcutTile extends StatelessWidget {
  const _TechShortcutTile({
    required this.tileKey,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Key? tileKey;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: TechnicianUiTokens.rLg,
      blurSigma: TechnicianUiTokens.blurMedium,
      padding: const EdgeInsets.all(10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TechnicianUiTokens.textCaption1(color: const Color(0xFF1C1C1E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.jobs().where('technicianId', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final running = docs
            .where((d) =>
                ['inProgress', 'pendingDealerConfirm', 'paid'].contains((d.data()['status'] ?? '').toString()))
            .length;
        final completed =
            docs.where((d) => (d.data()['status'] ?? '').toString() == 'completed').length;
        final total = docs.length;
        return Row(
          children: [
            Expanded(
              child: _StatGlass(
                label: 'Running',
                value: '$running',
                valueColor: const Color(0xFFEA580C),
                icon: Icons.play_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGlass(
                label: 'Done',
                value: '$completed',
                valueColor: const Color(0xFF059669),
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGlass(
                label: 'Total',
                value: '$total',
                valueColor: const Color(0xFF1E3A8A),
                icon: Icons.insights_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatGlass extends StatelessWidget {
  const _StatGlass({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: TechnicianUiTokens.rLg,
      blurSigma: TechnicianUiTokens.blurHeavy,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: valueColor.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF48484A),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    letterSpacing: 0.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 42,
              height: 1.0,
              letterSpacing: -1.25,
              shadows: [
                Shadow(
                  color: valueColor.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
                Shadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 0,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

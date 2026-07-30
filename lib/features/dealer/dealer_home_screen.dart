import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/route_names.dart';
import '../../core/remote_config/app_remote_config_controller_export.dart';
import '../marketplace/config/marketplace_feature_flags.dart';
import '../shop/config/shop_feature_flags.dart';
import '../shop/presentation/shop_home_screen.dart'
    if (dart.library.html) '../shop/presentation/shop_home_web_stub.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dealer_ui_tokens.dart';
import '../../shared/services/account_completion_guard.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/services/fcm_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/walkthrough_service.dart';
import '../../shared/utils/firestore_dynamic.dart';
import '../../shared/widgets/glass_ui_kit.dart';
import '../../shared/widgets/brand_kit_provider.dart';
import '../../shared/widgets/brand_squircle_icon.dart';
import '../../shared/widgets/organic_pattern_background.dart';
import '../../shared/widgets/guide_highlight_overlay.dart';
import '../../shared/widgets/home_shortcuts_banner.dart';
import '../../shared/widgets/status_reels_strip.dart';
import '../../shared/widgets/profile_under_review_dialog.dart';
import '../technician/slider_ads_section.dart';
import 'widgets/dealer_connect_shop_home_shell.dart';

const String _keyDealerFullScreenPromptShown =
    'dealer_full_screen_notification_prompt_shown';

const _kRunningStatuses = [
  'bidding',
  'agreed',
  'paymentPending',
  'paid',
  'inProgress',
  'pendingDealerConfirm',
];

const _dealerV2Text = Color(0xFF1C1C1E);
const _dealerV2TextSoft = Color(0xFF636366);
const _sectionHeadingNavy = Color(0xFF0F2744);

/// Warm orange — same as dealer bottom nav selected / hover (see [AppColors.brandWarm]).
const _dealerAccentOrange = AppColors.brandWarm;
const _dealerAccentOrangeLight = AppColors.brandWarmLight;
const _dealerAccentOrangeGlow = AppColors.brandWarmSoft;

const _kShortcutsScreenPadding = 16.0;
const _kShortcutsGap = 12.0;
const _kHomeSectionGap = 22.0;

TextStyle _dealerSectionHeadingStyle() => GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: _sectionHeadingNavy,
      letterSpacing: 0.65,
      height: 1.25,
    );

TextStyle _dealerSponsoredHeadingStyle() => GoogleFonts.inter(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
      letterSpacing: 0.4,
      height: 1.2,
    );

/// Divider + label so sponsored block reads separate from dashboard content.
class _SponsoredSectionHeader extends StatelessWidget {
  const _SponsoredSectionHeader();

  @override
  Widget build(BuildContext context) {
    final line = Colors.grey.shade400.withValues(alpha: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _kShortcutsGap),
        Row(
          children: [
            Expanded(
              child: Divider(height: 1, thickness: 1, color: line),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Sponsored',
                style: _dealerSponsoredHeadingStyle(),
              ),
            ),
            Expanded(
              child: Divider(height: 1, thickness: 1, color: line),
            ),
          ],
        ),
      ],
    );
  }
}

TextStyle _shortcutGroupLabelStyle() => GoogleFonts.inter(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: const Color(0xFF64748B),
      height: 1.2,
    );

void _showUnderReviewPopup(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => ProfileUnderReviewDialog(
      message:
          'Your profile is under review. Once approved, you will be able to access all features. '
          'This may take up to 24 hours. You will receive a notification when approved.',
    ),
  );
}

void _requireApproved(
  BuildContext context,
  bool approved,
  VoidCallback action,
) {
  if (approved) return action();
  _showUnderReviewPopup(context);
}

Future<void> _openDealerKycWithProfileGate(BuildContext context) async {
  final allowed = await AccountCompletionGuard.ensureDealerCanOpenKyc(context);
  if (!context.mounted || !allowed) return;
  context.push(RouteNames.dealerKyc);
}

Future<void> _openDealerPostJobWithCompletionGate(BuildContext context) async {
  final allowed = await AccountCompletionGuard.ensureDealerCanCreateJob(
    context,
  );
  if (!context.mounted || !allowed) return;
  context.push(RouteNames.dealerPostJob);
}

/// Dealer main shell (premium v2). Full rebuild: app bar, hero, shortcuts, and bottom nav.
class DealerHomeScreen extends StatefulWidget {
  const DealerHomeScreen({super.key});

  @override
  State<DealerHomeScreen> createState() => _DealerHomeScreenState();
}

class _DealerHomeScreenState extends State<DealerHomeScreen> {
  int _index = 0;
  bool _profileReviewDialogShown = false;

  /// Home subtabs: Connect (0) → Calculate (1) → Shop (2); drives page tint + bottom nav accent.
  final ValueNotifier<double> _connectShopTab = ValueNotifier<double>(0.0);
  final Map<String, GlobalKey> _guideKeys = {
    'post': GlobalKey(),
    'drafts': GlobalKey(),
    'my_jobs': GlobalKey(),
    'wallet': GlobalKey(),
    'profile': GlobalKey(),
    'warranty': GlobalKey(),
    'under_warranty': GlobalKey(),
    'records': GlobalKey(),
    'documents': GlobalKey(),
    'support': GlobalKey(),
  };
  final Map<String, GlobalKey> _navGuideKeys = {
    'nav_home': GlobalKey(),
    'nav_jobs': GlobalKey(),
    'nav_wallet': GlobalKey(),
    'nav_profile': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runEntryFlow();
    });
  }

  @override
  void dispose() {
    _connectShopTab.dispose();
    super.dispose();
  }

  Future<void> _runEntryFlow() async {
    await _maybeShowFullScreenPrompt();
    await _maybeShowProfileUnderReviewDialog();
    await _refreshFcmToken();
    await _maybeShowDealerHomeGuide();
  }

  Future<void> _maybeShowDealerHomeGuide() async {
    final seen = await WalkthroughService.isRoleHomeGuideSeen('dealer');
    if (seen || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    final doc = await FirestoreService.users().doc(uid).get();
    final approved = boolFromFirestore(doc.data()?['approved']);
    if (!approved) return; // show automatically later once approved
    final steps = <_GuideStepSpec>[
      _GuideStepSpec(
        key: _guideKeys['post'],
        title: 'Post Job',
        message:
            'Use this action to create a new service job with complete requirements.',
        onMove: () => setState(() => _index = 0),
      ),
      _GuideStepSpec(
        key: _guideKeys['drafts'],
        title: 'Draft Jobs',
        message: 'Open saved drafts and continue incomplete job submissions.',
        onMove: () => setState(() => _index = 0),
      ),
      _GuideStepSpec(
        key: _guideKeys['my_jobs'],
        title: 'My Jobs',
        message: 'View all created jobs with their latest progress and status.',
        onMove: () => setState(() => _index = 0),
      ),
      _GuideStepSpec(
        key: _navGuideKeys['nav_jobs'],
        title: 'Jobs Tab',
        message:
            'Switch to the Jobs tab to manage job lists and recent updates.',
        onMove: () => setState(() => _index = 1),
      ),
      _GuideStepSpec(
        key: _navGuideKeys['nav_wallet'],
        title: 'Wallet Tab',
        message: 'Open wallet details, balances, and transaction actions here.',
        onMove: () => setState(() => _index = 2),
      ),
      _GuideStepSpec(
        key: _navGuideKeys['nav_profile'],
        title: 'Profile Tab',
        message:
            'Manage profile, KYC, legal, and account-level settings in this tab.',
        onMove: () => setState(() => _index = 3),
      ),
      _GuideStepSpec(
        key: _guideKeys['support'],
        title: 'Support',
        message: 'Contact support, raise tickets, and get assistance quickly.',
        onMove: () => setState(() => _index = 0),
      ),
    ];
    await _runGuideSteps(steps);
    if (!mounted) return;
    await WalkthroughService.markRoleHomeGuideSeen('dealer');
  }

  Future<void> _runGuideSteps(List<_GuideStepSpec> steps) async {
    var i = 0;
    while (mounted && i < steps.length) {
      final step = steps[i];
      step.onMove();
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted || step.key == null) break;
      final action = await _showGuideHighlight(
        key: step.key!,
        title: step.title,
        message: step.message,
        stepText: 'Step ${i + 1}/${steps.length}',
        canBack: i > 0,
        isLast: i == steps.length - 1,
      );
      if (!mounted) return;
      if (action == GuideOverlayAction.skip) return;
      if (action == GuideOverlayAction.back) {
        i = (i - 1).clamp(0, steps.length - 1);
      } else {
        i += 1;
      }
    }
  }

  Future<GuideOverlayAction> _showGuideHighlight({
    required GlobalKey key,
    required String title,
    required String message,
    required String stepText,
    required bool canBack,
    required bool isLast,
  }) async {
    final targetContext = key.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.22,
      );
    }
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return GuideOverlayAction.next;
    final ctx = key.currentContext;
    if (ctx == null) return GuideOverlayAction.next;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return GuideOverlayAction.next;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    if (!mounted) return GuideOverlayAction.next;
    final result = await showGeneralDialog<GuideOverlayAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'guide',
      pageBuilder: (context, _, _) => GuideHighlightOverlay(
        targetRect: rect,
        title: title,
        description: message,
        stepText: stepText,
        canBack: canBack,
        isLast: isLast,
        onBack: () => Navigator.of(context).pop(GuideOverlayAction.back),
        onSkip: () => Navigator.of(context).pop(GuideOverlayAction.skip),
        onNext: () => Navigator.of(context).pop(GuideOverlayAction.next),
      ),
    );
    return result ?? GuideOverlayAction.next;
  }

  Future<void> _refreshFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FcmService.saveTokenToUser(uid);
    } catch (_) {}
  }

  Future<void> _maybeShowProfileUnderReviewDialog() async {
    if (_profileReviewDialogShown) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    final doc = await FirestoreService.users().doc(uid).get();
    if (!mounted) return;
    final approved = boolFromFirestore(doc.data()?['approved']);
    if (!approved) {
      _profileReviewDialogShown = true;
      await showDialog<void>(
        context: context,
        builder: (ctx) => ProfileUnderReviewDialog(
          message:
              'Your profile is currently under review. You will receive a notification once verification is completed.',
        ),
      );
    }
  }

  Future<void> _maybeShowFullScreenPrompt() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyDealerFullScreenPromptShown) == true) return;
    if (!mounted) return;
    _showFullScreenPermissionDialog(context, prefs);
  }

  void _showFullScreenPermissionDialog(
    BuildContext context,
    SharedPreferences prefs,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.notifications_active,
          size: 48,
          color: AppColors.primary,
        ),
        title: const Text('Enable full-screen job notifications'),
        content: const Text(
          'Allow full-screen alerts with ring and vibration when you receive bids, '
          'technician acceptances, or job updates. This helps you respond quickly.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await prefs.setBool(_keyDealerFullScreenPromptShown, true);
            },
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await prefs.setBool(_keyDealerFullScreenPromptShown, true);
              FcmService.openFullScreenIntentSettings();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return const Scaffold(
        backgroundColor: Color(0xFF070A12),
        body: Center(child: Text('Sign in required.')),
      );
    }

    final tabs = <Widget>[
      _DealerDashboardTab(
        uid: uid,
        guideKeys: _guideKeys,
        connectShopTabNotifier: _connectShopTab,
      ),
      _DealerJobsTabV2(uid: uid),
      _DealerWalletTabV2(uid: uid),
      _DealerProfileTabV2(uid: uid),
    ];

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snap) {
        final approved = boolFromFirestore(snap.data?.data()?['approved']);

        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: OrganicPatternPainter.kBase,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              surface: OrganicPatternPainter.kBase,
            ),
          ),
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _connectShopTab,
                  builder: (context, t, _) {
                    return OrganicPatternBackground(
                      tabProgress: _index == 0 ? t : null,
                    );
                  },
                ),
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.viewPaddingOf(context).top,
                      ),
                      child: IndexedStack(index: _index, children: tabs),
                    ),
                  ),
                ),
                if (!approved && _index != 3)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _showUnderReviewPopup(context),
                      onTapDown: (_) => _showUnderReviewPopup(context),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: _DealerBottomNavV2(
              index: _index,
              navKeys: _navGuideKeys,
              onChanged: (i) {
                if (!approved && i != 3) {
                  _showUnderReviewPopup(context);
                  return;
                }
                setState(() => _index = i);
              },
            ),
          ),
        );
      },
    );
  }
}

class _DealerBottomNavV2 extends StatelessWidget {
  const _DealerBottomNavV2({
    required this.index,
    required this.onChanged,
    this.navKeys,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final Map<String, GlobalKey>? navKeys;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.76),
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            padding: EdgeInsets.only(bottom: bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _kShortcutsScreenPadding,
                10,
                _kShortcutsScreenPadding,
                8,
              ),
              child: SizedBox(
                height: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NavIcon(
                      iconKey: navKeys?['nav_home'],
                      label: 'Home',
                      icon: Icons.home_rounded,
                      selected: index == 0,
                      onTap: () => onChanged(0),
                    ),
                    _NavIcon(
                      iconKey: navKeys?['nav_jobs'],
                      label: 'Jobs',
                      icon: Icons.work_rounded,
                      selected: index == 1,
                      onTap: () => onChanged(1),
                    ),
                    _NavIcon(
                      iconKey: navKeys?['nav_wallet'],
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_rounded,
                      selected: index == 2,
                      onTap: () => onChanged(2),
                    ),
                    _NavIcon(
                      iconKey: navKeys?['nav_profile'],
                      label: 'Profile',
                      icon: Icons.person_rounded,
                      selected: index == 3,
                      onTap: () => onChanged(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatefulWidget {
  const _NavIcon({
    this.iconKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color _idleIcon = Color(0xFF94A3B8);
  static const Color _idleLabel = Color(0xFF64748B);

  final Key? iconKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    const accent = _dealerAccentOrange;
    final iconColor = widget.selected ? accent : _NavIcon._idleIcon;
    final labelColor = widget.selected ? accent : _NavIcon._idleLabel;

    return Expanded(
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 600),
        child: Semantics(
          label: widget.label,
          button: true,
          selected: widget.selected,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              child: Listener(
                behavior: HitTestBehavior.deferToChild,
                onPointerDown: (_) => _setPressed(true),
                onPointerUp: (_) => _setPressed(false),
                onPointerCancel: (_) => _setPressed(false),
                child: InkWell(
                  key: widget.iconKey,
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: accent.withValues(alpha: 0.14),
                  highlightColor: accent.withValues(alpha: 0.07),
                  splashFactory: InkRipple.splashFactory,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: SizedBox.expand(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 3,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  width: widget.selected ? 22 : 0,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              height: 34,
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    opacity: widget.selected ? 1 : 0,
                                    child: IgnorePointer(
                                      child: Container(
                                        width: 54,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          color: accent.withValues(alpha: 0.135),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(widget.icon,
                                      color: iconColor, size: 24),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: widget.selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: labelColor,
                                letterSpacing: 0.15,
                                height: 1.05,
                              ),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
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
          ),
        ),
      ),
    );
  }
}

class _GuideStepSpec {
  const _GuideStepSpec({
    required this.key,
    required this.title,
    required this.message,
    required this.onMove,
  });

  final GlobalKey? key;
  final String title;
  final String message;
  final VoidCallback onMove;
}

class _DealerDashboardTab extends StatelessWidget {
  const _DealerDashboardTab({
    required this.uid,
    required this.guideKeys,
    this.connectShopTabNotifier,
  });
  final String uid;
  final Map<String, GlobalKey> guideKeys;
  final ValueNotifier<double>? connectShopTabNotifier;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final profile = data?['profile'] as Map<String, dynamic>? ?? {};
        final fullName = (profile['name'] as String?)?.trim();
        final firstName = (fullName == null || fullName.isEmpty)
            ? 'Dealer'
            : fullName.split(RegExp(r'\s+')).first;
        final photoUrl = profile['photoUrl'] as String?;
        final approved = boolFromFirestore(data?['approved']);
        final trustScore = (data?['trustScore'] as num?)?.toDouble();
        final reputation = (data?['reputationLevel'] as String?)?.toString();

        return DealerConnectShopHomeShell(
          uid: uid,
          photoUrl: photoUrl,
          userFirstName: firstName,
          approved: approved,
          onNotificationsTap: () =>
              context.push(RouteNames.dealerNotifications),
          onSettingsTap: () => context.push(RouteNames.settings),
          connectShopTabNotifier: connectShopTabNotifier,
          connectSlivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  10,
                  _kShortcutsScreenPadding,
                  _kHomeSectionGap,
                ),
                child: _DealerInsights(uid: uid),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  0,
                  _kShortcutsScreenPadding,
                  0,
                ),
                child: Opacity(
                  opacity: approved ? 1 : 0.72,
                  child: _HeroCardV2(
                    uid: uid,
                    approved: approved,
                    trustScore: trustScore,
                    reputationLevel: reputation,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  _kShortcutsGap,
                  _kShortcutsScreenPadding,
                  4,
                ),
                child: Text('Shortcuts', style: _dealerSectionHeadingStyle()),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  0,
                  _kShortcutsScreenPadding,
                  _kHomeSectionGap,
                ),
                child: _DealerDashboardShortcutsSection(
                  approved: approved,
                  guideKeys: guideKeys,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  _kShortcutsGap,
                  _kShortcutsScreenPadding,
                  0,
                ),
                child: StatusReelsStrip(role: 'dealer'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  _kHomeSectionGap,
                  _kShortcutsScreenPadding,
                  _kShortcutsGap,
                ),
                child: const HomeShortcutsBanner(role: 'dealer'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  _kHomeSectionGap,
                  _kShortcutsScreenPadding,
                  _kShortcutsGap,
                ),
                child: const _SponsoredSectionHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  _kShortcutsGap,
                  _kShortcutsScreenPadding,
                  120,
                ),
                child: const SliderAdsSection(
                  heroMode: false,
                  shellBorderRadius: 24,
                ),
              ),
            ),
          ],
          calculateSlivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  16,
                  _kShortcutsScreenPadding,
                  8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculate',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _dealerV2Text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimates and quick math for jobs and materials will appear here.',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: _dealerV2TextSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kShortcutsScreenPadding,
                  8,
                  _kShortcutsScreenPadding,
                  24,
                ),
                child: GlassBox(
                  radius: 26,
                  opacity: 0.52,
                  blurSigma: 25,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.number_square,
                        size: 44,
                        color: _dealerV2Text.withValues(alpha: 0.38),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Coming soon',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _dealerV2Text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
          shopSlivers: [
            SliverToBoxAdapter(
              child: Consumer<AppRemoteConfigController>(
                builder: (context, rc, _) {
                  if (ShopFeatureFlags.isSupabaseShopEnabled(rc.config)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(_kShortcutsScreenPadding, 12, _kShortcutsScreenPadding, 8),
                          child: Row(
                            children: [
                              Text(
                                'Buy equipment',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _dealerV2Text),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _requireApproved(context, approved, () {
                                  if (kIsWeb) {
                                    context.go(RouteNames.publicStore);
                                  } else {
                                    context.push(RouteNames.shopHome);
                                  }
                                }),
                                child: const Text('Open shop'),
                              ),
                            ],
                          ),
                        ),
                        if (kIsWeb)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(_kShortcutsScreenPadding, 0, _kShortcutsScreenPadding, 24),
                            child: _ShopHeroCard(
                              title: 'Browse online store',
                              subtitle: 'Products, cart & checkout on the web shop',
                              icon: CupertinoIcons.cart,
                              accent: const Color(0xFF007AFF),
                              onTap: () => _requireApproved(context, approved, () => context.go(RouteNames.publicStore)),
                            ),
                          )
                        else
                          const SizedBox(height: 360, child: ShopHomeScreen()),
                      ],
                    );
                  }
                  final mp = MarketplaceFeatureFlags.isMarketplaceEnabled(rc.config);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(_kShortcutsScreenPadding, 12, _kShortcutsScreenPadding, 8),
                        child: Text(
                          'Supply & sales',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _dealerV2Text, letterSpacing: -0.2),
                        ),
                      ),
                      if (!mp)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(_kShortcutsScreenPadding, 8, _kShortcutsScreenPadding, 24),
                          child: GlassBox(
                            radius: 24,
                            opacity: 0.52,
                            blurSigma: 25,
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'The supply hub is off for your region right now. Check back soon or contact support.',
                              style: GoogleFonts.inter(color: _dealerV2TextSoft, fontWeight: FontWeight.w400, fontSize: 13.5, height: 1.35),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(_kShortcutsScreenPadding, 0, _kShortcutsScreenPadding, 12),
                          child: Column(
                            children: [
                              _ShopHeroCard(
                                title: 'Browse shop',
                                subtitle: 'CCTV, networking & security products',
                                icon: CupertinoIcons.bag,
                                accent: const Color(0xFF34C759),
                                onTap: () => _requireApproved(context, approved, () {
                                  if (kIsWeb) {
                                    context.go(RouteNames.publicStore);
                                  } else {
                                    context.push(RouteNames.shopHome);
                                  }
                                }),
                              ),
                              const SizedBox(height: 12),
                              _ShopHeroCard(
                                title: 'My orders',
                                subtitle: 'Track purchases, reorder anytime',
                                icon: CupertinoIcons.doc_text,
                                accent: const Color(0xFF0A84FF),
                                onTap: () => _requireApproved(
                                  context,
                                  approved,
                                  () => context.push(RouteNames.accountOrders),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

class _DealerAvatar extends StatelessWidget {
  const _DealerAvatar({required this.photoUrl, required this.fallback});
  final String? photoUrl;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: DealerUiTokens.glassRimShadows,
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFFF1F5F9),
        backgroundImage: (photoUrl != null && photoUrl!.trim().isNotEmpty)
            ? NetworkImage(photoUrl!.trim())
            : null,
        child: (photoUrl == null || photoUrl!.trim().isEmpty)
            ? Text(
                fallback.isNotEmpty ? fallback[0].toUpperCase() : 'D',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  color: _dealerV2Text,
                ),
              )
            : null,
      ),
    );
  }
}

/// Buckets Firestore `status` strings (camelCase + legacy snake_case) for Command Center copy.
enum _HeroJobActivityBucket { posted, bidding, running, other }

_HeroJobActivityBucket _heroJobActivityBucket(String raw) {
  final s = raw.trim();
  switch (s) {
    case 'posted':
      return _HeroJobActivityBucket.posted;
    case 'bidding':
      return _HeroJobActivityBucket.bidding;
    case 'agreed':
    case 'paymentPending':
    case 'payment_pending':
    case 'paid':
    case 'inProgress':
    case 'in_progress':
    case 'pendingDealerConfirm':
    case 'pending_dealer_confirm':
      return _HeroJobActivityBucket.running;
    default:
      return _HeroJobActivityBucket.other;
  }
}

class _CommandCenterActivityBlock extends StatefulWidget {
  const _CommandCenterActivityBlock({
    required this.uid,
    required this.approved,
  });

  final String uid;
  final bool approved;

  @override
  State<_CommandCenterActivityBlock> createState() =>
      _CommandCenterActivityBlockState();
}

class _CommandCenterActivityBlockState extends State<_CommandCenterActivityBlock> {
  bool _hasDraft = false;

  static String _draftPrefsKey(String uid) => 'dealer_post_job_draft_$uid';

  @override
  void initState() {
    super.initState();
    _loadDraftFlag();
  }

  Future<void> _loadDraftFlag() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_draftPrefsKey(widget.uid));
      if (!mounted) return;
      setState(() {
        _hasDraft = raw != null && raw.trim().isNotEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _hasDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.jobs()
          .where('dealerId', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        var posted = 0;
        var bidding = 0;
        var running = 0;
        for (final d in snapshot.data?.docs ?? const []) {
          switch (_heroJobActivityBucket(
            (d.data()['status'] ?? '').toString(),
          )) {
            case _HeroJobActivityBucket.posted:
              posted++;
              break;
            case _HeroJobActivityBucket.bidding:
              bidding++;
              break;
            case _HeroJobActivityBucket.running:
              running++;
              break;
            case _HeroJobActivityBucket.other:
              break;
          }
        }

        final parts = <String>[];
        if (_hasDraft) {
          parts.add('Job draft saved');
        }
        if (posted > 0) {
          parts.add(
            posted == 1 ? '1 job posted' : '$posted jobs posted',
          );
        }
        if (bidding > 0) {
          parts.add(
            bidding == 1
                ? '1 in bidding'
                : '$bidding jobs in bidding',
          );
        }
        if (running > 0) {
          parts.add(
            running == 1
                ? '1 active / running job'
                : '$running active / running jobs',
          );
        }

        final summary = parts.isEmpty
            ? (widget.approved
                ? 'No recent activity'
                : 'No activity until your account is approved')
            : parts.join(' · ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent activity',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _dealerV2TextSoft,
                letterSpacing: 0.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: _dealerV2Text,
                height: 1.35,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                label: 'My jobs',
                icon: CupertinoIcons.doc_text,
                variant: GlassButtonVariant.secondary,
                enabled: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(RouteNames.dealerMyJobs);
                },
                borderRadius: 22,
                height: 48,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCardV2 extends StatelessWidget {
  const _HeroCardV2({
    required this.uid,
    required this.approved,
    required this.trustScore,
    required this.reputationLevel,
  });

  final String uid;
  final bool approved;
  final double? trustScore;
  final String? reputationLevel;

  @override
  Widget build(BuildContext context) {
    final travelLine = DealerTravelContextLine.of(context);
    final kit = BrandKitProvider.of(context);
    final appName = kit.appName ?? 'D.G.Yard Connect';
    final punchline = kit.tagline ?? 'Trusted service. Faster payouts.';

    return GlassBox(
      radius: 26,
      opacity: 0.52,
      blurSigma: 25,
      borderWidth: 1,
      borderOpacity: 0.42,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const BrandSquircleIcon(
                      size: 40,
                      glowBlur: 0,
                      glowSpread: 0,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: -0.35,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            punchline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _dealerV2TextSoft,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: approved
                      ? const Color(0xFF34C759).withValues(alpha: 0.18)
                      : AppColors.brandWarmLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      approved
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.clock,
                      size: 16,
                      color: approved
                          ? const Color(0xFF34C759)
                          : AppColors.brandWarmLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      approved ? 'Approved' : 'Review',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _dealerV2Text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CommandCenterActivityBlock(uid: uid, approved: approved),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Trust',
                  value: trustScore != null
                      ? '${trustScore!.toInt()}/100'
                      : '—',
                  accent: const Color(0xFF0A84FF),
                ),
              ),
              const SizedBox(width: _kShortcutsGap),
              Expanded(
                child: _MiniStat(
                  label: 'Level',
                  value:
                      (reputationLevel == null ||
                          reputationLevel!.trim().isEmpty)
                      ? '—'
                      : reputationLevel!.trim(),
                  accent: const Color(0xFFAF52DE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            approved
                ? 'Ready to post and manage jobs'
                : 'We\'re reviewing your account',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.45),
              height: 1.25,
            ),
          ),
          if (travelLine.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    travelLine,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.black.withValues(alpha: 0.38),
                      height: 1.3,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  color: _dealerV2Text.withValues(alpha: 0.35),
                  size: 20,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 18,
      opacity: 0.5,
      blurSigma: 25,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _dealerV2TextSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: accent,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colored glyph on a light disc — tile chrome stays neutral glass.
class _FlatShortcutIcon extends StatelessWidget {
  const _FlatShortcutIcon({
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 22,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class _PostShortcutHero extends StatefulWidget {
  const _PostShortcutHero({
    this.tileKey,
    required this.approved,
    required this.onTap,
  });

  final Key? tileKey;
  final bool approved;
  final VoidCallback onTap;

  @override
  State<_PostShortcutHero> createState() => _PostShortcutHeroState();
}

class _PostShortcutHeroState extends State<_PostShortcutHero> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.approved ? 1 : 0.45,
      child: KeyedSubtree(
        key: widget.tileKey,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Listener(
            behavior: HitTestBehavior.deferToChild,
            onPointerDown: (_) => _setPressed(true),
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _dealerAccentOrange.withValues(alpha: 0.18),
                    blurRadius: 26,
                    spreadRadius: 0,
                    offset: const Offset(0, 11),
                  ),
                  BoxShadow(
                    color: _dealerAccentOrangeGlow.withValues(alpha: 0.08),
                    blurRadius: 18,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.085),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: GlassBox(
                radius: 22,
                opacity: 0.5,
                blurSigma: 28,
                tintColors: [
                  _dealerAccentOrange.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onTap();
                },
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _dealerAccentOrangeGlow,
                            _dealerAccentOrange,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _dealerAccentOrange.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Post job',
                            style: GoogleFonts.inter(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              color: _dealerV2Text,
                              letterSpacing: -0.35,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Create a new listing',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _dealerV2TextSoft,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _dealerV2TextSoft,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatefulWidget {
  const _ShortcutTile({
    this.tileKey,
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  })  : iconDiscSize = 40.0,
        iconGlyphSize = 22.0;

  final Key? tileKey;
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final double iconDiscSize;
  final double iconGlyphSize;

  @override
  State<_ShortcutTile> createState() => _ShortcutTileState();
}

class _ShortcutTileState extends State<_ShortcutTile> {
  bool pressed = false;

  void setPressed(bool v) {
    if (pressed != v) setState(() => pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    const tileR = 20.0;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: KeyedSubtree(
        key: widget.tileKey,
        child: AnimatedScale(
          scale: pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Listener(
            behavior: HitTestBehavior.deferToChild,
            onPointerDown: (_) {
              if (widget.enabled) setPressed(true);
            },
            onPointerUp: (_) => setPressed(false),
            onPointerCancel: (_) => setPressed(false),
            child: GlassBox(
              radius: tileR,
              opacity: 0.45,
              blurSigma: 26,
              tintColors: [
                Colors.white.withValues(alpha: 0.40),
                Colors.white.withValues(alpha: 0.06),
              ],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              onTap: widget.enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      widget.onTap();
                    }
                  : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FlatShortcutIcon(
                    icon: widget.icon,
                    color: widget.color,
                    size: widget.iconDiscSize,
                    iconSize: widget.iconGlyphSize,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _dealerV2Text,
                        height: 1.15,
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DealerInsights extends StatelessWidget {
  const _DealerInsights({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.jobs()
          .where('dealerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final running = docs
            .where(
              (d) => _kRunningStatuses.contains(
                (d.data()['status'] ?? '').toString(),
              ),
            )
            .length;
        final completed = docs
            .where((d) => (d.data()['status'] ?? '').toString() == 'completed')
            .length;
        final total = docs.length;

        return Row(
          children: [
            Expanded(
              child: _InsightCard(
                label: 'Active',
                value: '$running',
                accent: const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(width: _kShortcutsGap),
            Expanded(
              child: _InsightCard(
                label: 'Completed',
                value: '$completed',
                accent: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: _kShortcutsGap),
            Expanded(
              child: _InsightCard(
                label: 'Total',
                value: '$total',
                accent: const Color(0xFF1E3A8A),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DealerDashboardShortcutsSection extends StatelessWidget {
  const _DealerDashboardShortcutsSection({
    required this.approved,
    required this.guideKeys,
  });

  final bool approved;
  final Map<String, GlobalKey> guideKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PostShortcutHero(
          tileKey: guideKeys['post'],
          approved: approved,
          onTap: () => _openDealerPostJobWithCompletionGate(context),
        ),
        const SizedBox(height: _kShortcutsGap),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 100,
                child: _ShortcutTile(
                  tileKey: guideKeys['my_jobs'],
                  label: 'My jobs',
                  icon: Icons.work_history_rounded,
                  color: const Color(0xFFF59E0B),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerMyJobs),
                ),
              ),
            ),
            const SizedBox(width: _kShortcutsGap),
            Expanded(
              child: SizedBox(
                height: 100,
                child: _ShortcutTile(
                  label: 'Drafts',
                  icon: Icons.drafts_rounded,
                  color: const Color(0xFF38BDF8),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerDraftJobs),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _kShortcutsGap),
        Text(
          'Account',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _dealerV2TextSoft,
            letterSpacing: 0.25,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 100,
                child: _ShortcutTile(
                  label: 'Wallet',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF22C55E),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerWallet),
                ),
              ),
            ),
            const SizedBox(width: _kShortcutsGap),
            Expanded(
              child: SizedBox(
                height: 100,
                child: _ShortcutTile(
                  label: 'Profile',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF8B5CF6),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerProfile),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _kShortcutsGap),
        Text(
          'Services',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _dealerV2TextSoft,
            letterSpacing: 0.25,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 100,
                child: _ShortcutTile(
                  tileKey: guideKeys['under_warranty'],
                  label: 'Warranty',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF10B981),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerWarrantyClaims),
                ),
              ),
            ),
            const SizedBox(width: _kShortcutsGap),
            Expanded(
              child: SizedBox(
                height: 100,
                child: _ShortcutTile(
                  label: 'Records',
                  icon: Icons.assignment_rounded,
                  color: const Color(0xFF38BDF8),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerServiceCompletionRecords),
                ),
              ),
            ),
            const SizedBox(width: _kShortcutsGap),
            Expanded(
              child: SizedBox(
                height: 100,
                child: _ShortcutTile(
                  label: 'Documents',
                  icon: Icons.folder_rounded,
                  color: const Color(0xFF6366F1),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerDocuments),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 22,
      opacity: 0.48,
      blurSigma: 25,
      tintColors: [
        Colors.white.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.04),
      ],
      tintStops: const [0.0, 1.0],
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF48484A),
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: GoogleFonts.inter(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 42,
              height: 1.0,
              letterSpacing: -1.25,
              shadows: [
                Shadow(
                  color: accent.withValues(alpha: 0.32),
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

class _DealerJobsTabV2 extends StatelessWidget {
  const _DealerJobsTabV2({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kShortcutsScreenPadding,
        14,
        _kShortcutsScreenPadding,
        110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Jobs',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _dealerV2Text,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              GlassIconButton(
                icon: CupertinoIcons.add_circled,
                iconColor: _dealerAccentOrange,
                onTap: () => _openDealerPostJobWithCompletionGate(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassBox(
            radius: 22,
            opacity: 0.5,
            blurSigma: 25,
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
              children: [
                _ShortcutTile(
                  label: 'Post',
                  icon: Icons.add_box_rounded,
                  color: _dealerAccentOrangeLight,
                  enabled: true,
                  onTap: () => _openDealerPostJobWithCompletionGate(context),
                ),
                _ShortcutTile(
                  label: 'Drafts',
                  icon: Icons.drafts_rounded,
                  color: const Color(0xFF0EA5E9),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerDraftJobs),
                ),
                _ShortcutTile(
                  label: 'All jobs',
                  icon: Icons.work_history_rounded,
                  color: const Color(0xFFF59E0B),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerMyJobs),
                ),
                _ShortcutTile(
                  label: 'Warranty',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF10B981),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerWarrantyClaims),
                ),
                _ShortcutTile(
                  label: 'Under w.',
                  icon: Icons.security_update_good_rounded,
                  color: const Color(0xFF22C55E),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerUnderWarrantyJobs),
                ),
                _ShortcutTile(
                  label: 'Records',
                  icon: Icons.assignment_rounded,
                  color: const Color(0xFF38BDF8),
                  enabled: true,
                  onTap: () =>
                      context.push(RouteNames.dealerServiceCompletionRecords),
                ),
                _ShortcutTile(
                  label: 'Documents',
                  icon: Icons.folder_rounded,
                  color: const Color(0xFF93C5FD),
                  enabled: true,
                  onTap: () => context.push(RouteNames.dealerDocuments),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Recent jobs',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _dealerV2Text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.jobs()
                  .where('dealerId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(60)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: _dealerAccentOrange.withValues(alpha: 0.9),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No jobs yet',
                      style: GoogleFonts.inter(
                        color: _dealerV2TextSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final jobId = doc.id;
                    final title = (d['title'] as String?)?.trim();
                    final status = (d['status'] ?? 'pending').toString();
                    final amount =
                        (d['agreedAmount'] ?? d['dealerRate'] ?? 0) as num;
                    return _JobRowCard(
                      title: (title == null || title.isEmpty)
                          ? 'Job #${jobId.substring(0, 8)}'
                          : title,
                      subtitle: '$status • ₹${amount.toStringAsFixed(0)}',
                      onTap: () => context.push('/dealer/jobs/$jobId'),
                    );
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

class _JobRowCard extends StatelessWidget {
  const _JobRowCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 20,
      opacity: 0.52,
      blurSigma: 25,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  AppColors.brandWarmLight.withValues(alpha: 0.2),
                  AppColors.brandWarmLight.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: AppColors.brandWarmLight.withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              CupertinoIcons.briefcase,
              color: AppColors.brandWarmLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _dealerV2Text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: _dealerV2TextSoft,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_forward, color: _dealerV2TextSoft),
        ],
      ),
    );
  }
}

class _DealerWalletTabV2 extends StatelessWidget {
  const _DealerWalletTabV2({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kShortcutsScreenPadding,
        14,
        _kShortcutsScreenPadding,
        110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _dealerV2Text,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.wallets().doc(uid).snapshots(),
            builder: (context, snapshot) {
              final balance =
                  (snapshot.data?.data()?['balance'] as num?)?.toDouble() ??
                  0.0;
              return GlassBox(
                radius: 26,
                opacity: 0.48,
                blurSigma: 25,
                padding: const EdgeInsets.all(18),
                tintStops: const [0.0, 0.5, 1.0],
                tintColors: [
                  const Color(0xFF5AC8FA).withValues(alpha: 0.035),
                  Colors.white.withValues(alpha: 0.03),
                  Colors.white.withValues(alpha: 0.025),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available',
                      style: GoogleFonts.inter(
                        color: _dealerV2TextSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${balance.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: _dealerV2Text,
                        fontWeight: FontWeight.w600,
                        fontSize: 28,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: 'Open wallet & transactions',
                      icon: CupertinoIcons.arrow_up_right_square,
                      variant: GlassButtonVariant.secondary,
                      onTap: () => context.push(RouteNames.dealerWallet),
                      fontSize: 11.5,
                      height: 50,
                    ),
                    const SizedBox(height: 10),
                    GlassButton(
                      label: 'Manage payout / refund accounts',
                      icon: CupertinoIcons.creditcard,
                      variant: GlassButtonVariant.secondary,
                      onTap: () =>
                          context.push(RouteNames.dealerSettlementAccount),
                      fontSize: 11.5,
                      height: 50,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DealerProfileTabV2 extends StatelessWidget {
  const _DealerProfileTabV2({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final profile = data?['profile'] as Map<String, dynamic>? ?? {};
        final name = (profile['name'] as String?)?.trim();
        final photoUrl = profile['photoUrl'] as String?;
        final kycStatus = (data?['kycStatus'] as String?)?.trim().toLowerCase() ?? 'pending';
        final isKycVerified = kycStatus == 'verified';

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            _kShortcutsScreenPadding,
            14,
            _kShortcutsScreenPadding,
            120,
          ),
          children: [
            GlassBox(
              radius: 22,
              opacity: 0.52,
              blurSigma: 25,
              padding: const EdgeInsets.all(16),
              tintColors: [
                AppColors.brandWarmSoft.withValues(alpha: 0.12),
                AppColors.brandWarm.withValues(alpha: 0.05),
              ],
              child: Row(
                children: [
                  _DealerAvatar(photoUrl: photoUrl, fallback: name ?? 'Dealer'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name?.isNotEmpty == true ? name! : 'Dealer',
                          style: GoogleFonts.inter(
                            color: _dealerV2Text,
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isKycVerified ? AppColors.success : AppColors.brandWarm)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: (isKycVerified ? AppColors.success : AppColors.brandWarm)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            isKycVerified ? 'KYC Verified' : 'KYC Pending',
                            style: GoogleFonts.inter(
                              color: isKycVerified ? AppColors.success : const Color(0xFFB45309),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    icon: CupertinoIcons.pencil,
                    iconColor: AppColors.brandWarm,
                    onTap: () => context.push(RouteNames.dealerEditProfile),
                  ),
                ],
              ),
            ),
            if (!isKycVerified) ...[
              const SizedBox(height: 12),
              GlassBox(
                radius: 18,
                opacity: 0.5,
                blurSigma: 24,
                padding: const EdgeInsets.all(14),
                tintColors: [
                  AppColors.brandWarm.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.06),
                ],
                onTap: () => _openDealerKycWithProfileGate(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.brandWarm, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Complete your KYC to receive payments',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_forward, color: Color(0xFFB45309), size: 18),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _ProfileSectionTitle(title: 'Account'),
            _ProfileSectionCard(
              children: [
                _ProfileActionTile(
                  label: 'My profile',
                  icon: Icons.person_rounded,
                  iconColor: AppColors.brandWarm,
                  onTap: () => context.push(RouteNames.dealerProfile),
                ),
                _ProfileActionTile(
                  label: 'Edit profile',
                  icon: Icons.edit_rounded,
                  iconColor: AppColors.brandWarm,
                  onTap: () => context.push(RouteNames.dealerEditProfile),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _ProfileSectionTitle(title: 'Work Setup'),
            _ProfileSectionCard(
              children: [
                _ProfileActionTile(
                  label: 'KYC',
                  icon: Icons.verified_user_rounded,
                  iconColor: isKycVerified ? AppColors.success : AppColors.brandWarm,
                  trailingBadge: isKycVerified ? 'Verified' : 'Pending',
                  badgeColor: isKycVerified ? AppColors.success : AppColors.brandWarm,
                  onTap: () => _openDealerKycWithProfileGate(context),
                ),
                _ProfileActionTile(
                  label: 'Skills',
                  icon: Icons.workspace_premium_rounded,
                  iconColor: AppColors.brandWarmLight,
                  onTap: () => context.push(RouteNames.dealerEditProfile),
                ),
                _ProfileActionTile(
                  label: 'Service area',
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.brandWarmLight,
                  onTap: () => context.push(RouteNames.dealerEditProfile),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _ProfileSectionTitle(title: 'App'),
            _ProfileSectionCard(
              children: [
                _ProfileActionTile(
                  label: 'Settings',
                  icon: Icons.settings_rounded,
                  iconColor: const Color(0xFFCA8A04),
                  onTap: () => context.push(RouteNames.settings),
                ),
                _ProfileActionTile(
                  label: 'Notifications',
                  icon: Icons.notifications_rounded,
                  iconColor: const Color(0xFFCA8A04),
                  onTap: () => context.push(RouteNames.dealerNotifications),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _ProfileSectionTitle(title: 'Support'),
            _ProfileSectionCard(
              children: [
                _ProfileActionTile(
                  label: 'Help & support',
                  icon: Icons.support_agent_rounded,
                  iconColor: const Color(0xFFD97706),
                  onTap: () => context.push(RouteNames.supportHomeForRole('dealer')),
                ),
                _ProfileActionTile(
                  label: 'Legal',
                  icon: Icons.gavel_rounded,
                  iconColor: const Color(0xFFD97706),
                  onTap: () => context.push(RouteNames.legalMenu),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassBox(
              radius: 18,
              opacity: 0.5,
              blurSigma: 24,
              padding: const EdgeInsets.all(14),
              tintColors: [
                const Color(0xFFEF4444).withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.04),
              ],
              onTap: () async {
                await AuthService().signOut();
                if (!context.mounted) return;
                context.go(AuthPostLogin.postLogoutRoute());
              },
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFFEE2E2),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_forward, color: Color(0xFFDC2626)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: _dealerV2TextSoft,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 20,
      opacity: 0.52,
      blurSigma: 25,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.32),
                indent: 64,
                endIndent: 12,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.trailingBadge,
    this.badgeColor,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? trailingBadge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 14,
      opacity: 0.0,
      blurSigma: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: (iconColor ?? AppColors.brandWarm).withValues(alpha: 0.12),
              border: Border.all(
                color: (iconColor ?? AppColors.brandWarm).withValues(alpha: 0.24),
              ),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.brandWarm, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: _dealerV2Text,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
          Icon(
            CupertinoIcons.chevron_forward,
            color: _dealerV2TextSoft.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class _ShopHeroCard extends StatelessWidget {
  const _ShopHeroCard({
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
    return GlassBox(
      radius: 26,
      opacity: 0.48,
      blurSigma: 25,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      tintStops: const [0.0, 1.0],
      tintColors: [
        accent.withValues(alpha: 0.035),
        Colors.white.withValues(alpha: 0.03),
      ],
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.16),
                  accent.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _dealerV2Text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _dealerV2TextSoft,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_forward, color: _dealerV2TextSoft),
        ],
      ),
    );
  }
}

class _ShopCompactCard extends StatelessWidget {
  const _ShopCompactCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 20,
      opacity: 0.52,
      blurSigma: 25,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0A84FF), size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _dealerV2Text,
            ),
          ),
        ],
      ),
    );
  }
}

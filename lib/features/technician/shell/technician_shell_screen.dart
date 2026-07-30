import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/technician_ui_tokens.dart';
import '../../../shared/services/fcm_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/walkthrough_service.dart';
import '../../../shared/widgets/guide_highlight_overlay.dart';
import '../../../shared/widgets/organic_pattern_background.dart';
import 'technician_availability_sheet.dart';
import 'technician_bottom_chrome.dart';
import 'technician_dashboard_tab.dart';
import 'technician_earnings_tab.dart';
import 'technician_jobs_tab.dart';
import 'technician_profile_tab.dart';
import 'technician_shell_actions.dart';

const String _keyTechFullScreenPromptShown = 'tech_full_screen_notification_prompt_shown';

/// Technician main shell — light glass system, tabbed home.
class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({super.key});

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  static const Color _kTechnicianBgFallback = Color(0xFFEAF4FF);
  final ValueNotifier<double> _homeTabProgress = ValueNotifier<double>(0.0);

  int _index = 0;
  bool _profileReviewDialogShown = false;
  final Map<String, GlobalKey> _guideKeys = {
    'incoming': GlobalKey(),
    'my_jobs': GlobalKey(),
    'wallet': GlobalKey(),
    'payouts': GlobalKey(),
    'receipts': GlobalKey(),
    'warranty': GlobalKey(),
    'uw_jobs': GlobalKey(),
    'disputes': GlobalKey(),
    'profile': GlobalKey(),
    'kyc': GlobalKey(),
    'skills': GlobalKey(),
    'area': GlobalKey(),
    'support': GlobalKey(),
  };
  final Map<String, GlobalKey> _navGuideKeys = {
    'nav_home': GlobalKey(),
    'nav_jobs': GlobalKey(),
    'nav_earnings': GlobalKey(),
    'nav_profile': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _writeLastLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runEntryFlow();
    });
  }

  @override
  void dispose() {
    _homeTabProgress.dispose();
    super.dispose();
  }

  Future<void> _runEntryFlow() async {
    await _maybeShowFullScreenPrompt();
    await _maybeShowProfileUnderReviewDialog();
    await _refreshFcmToken();
    await _maybeShowTechnicianHomeGuide();
  }

  Future<void> _maybeShowTechnicianHomeGuide() async {
    final seen = await WalkthroughService.isRoleHomeGuideSeen('technician');
    if (seen || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    final doc = await FirestoreService.users().doc(uid).get();
    final approved = doc.data()?['approved'] as bool? ?? false;
    if (!approved) return; // show automatically later once approved
    final steps = <_GuideStepSpec>[
      _GuideStepSpec(key: _guideKeys['incoming'], title: 'Incoming Jobs', message: 'Open new job requests and respond promptly from this section.', onMove: () => setState(() => _index = 0)),
      _GuideStepSpec(key: _guideKeys['my_jobs'], title: 'My Jobs', message: 'Track assigned, running, and completed jobs in one place.', onMove: () => setState(() => _index = 0)),
      _GuideStepSpec(key: _guideKeys['wallet'], title: 'Wallet', message: 'Review earnings summary and available wallet balance here.', onMove: () => setState(() => _index = 0)),
      _GuideStepSpec(key: _guideKeys['payouts'], title: 'Payout History', message: 'Check payout records and transfer status updates.', onMove: () => setState(() => _index = 0)),
      _GuideStepSpec(key: _guideKeys['support'], title: 'Support', message: 'Reach support, raise tickets, and get assistance quickly.', onMove: () => setState(() => _index = 0)),
      _GuideStepSpec(key: _navGuideKeys['nav_jobs'], title: 'Jobs Tab', message: 'Switch to the Jobs tab to work on active job pipelines.', onMove: () => setState(() => _index = 1)),
      _GuideStepSpec(key: _navGuideKeys['nav_earnings'], title: 'Earnings Tab', message: 'Open earnings analytics and financial summaries here.', onMove: () => setState(() => _index = 2)),
      _GuideStepSpec(key: _navGuideKeys['nav_profile'], title: 'Profile Tab', message: 'Use this tab for profile updates and account controls.', onMove: () => setState(() => _index = 3)),
      _GuideStepSpec(key: _navGuideKeys['nav_home'], title: 'Home Tab', message: 'Return to Home anytime to access all quick shortcuts.', onMove: () => setState(() => _index = 0)),
    ];
    await _runGuideSteps(steps);
    if (!mounted) return;
    await WalkthroughService.markRoleHomeGuideSeen('technician');
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
    final approved = doc.data()?['approved'] as bool? ?? false;
    if (!approved) {
      _profileReviewDialogShown = true;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Profile Under Review'),
          content: const Text(
            'Your profile is currently under review. You will receive a notification once verification is completed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _maybeShowFullScreenPrompt() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyTechFullScreenPromptShown) == true) return;
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
        icon: Icon(
          Icons.notifications_active,
          size: 48,
          color: TechnicianUiTokens.accent,
        ),
        title: const Text('Enable full-screen job notifications'),
        content: const Text(
          'Allow full-screen alerts with ring and vibration when a new job arrives. '
          'This helps you never miss a job request.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await prefs.setBool(_keyTechFullScreenPromptShown, true);
            },
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await prefs.setBool(_keyTechFullScreenPromptShown, true);
              FcmService.openFullScreenIntentSettings();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _writeLastLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await FirestoreService.users().doc(uid).update({
        'lastLocation': GeoPoint(pos.latitude, pos.longitude),
        'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: _kTechnicianBgFallback,
        body: Center(
          child: Text(
            'Sign in required.',
            style: TechnicianUiTokens.textSubhead(),
          ),
        ),
      );
    }

    final tabs = <Widget>[
      TechnicianDashboardTab(
        uid: uid,
        guideKeys: _guideKeys,
        onTopTabChanged: (i) => _homeTabProgress.value = i.toDouble(),
      ),
      TechnicianJobsTab(uid: uid),
      const TechnicianEarningsTab(),
      const TechnicianProfileTab(),
    ];

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snap) {
        final approved = snap.data?.data()?['approved'] as bool? ?? false;
        final availabilityStatus =
            (snap.data?.data()?['availabilityStatus'] as String?) ?? 'offline';
        final isOnline = approved ? (snap.data?.data()?['online'] as bool? ?? false) : false;

        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            splashColor: TechnicianUiTokens.accent.withValues(alpha: 0.08),
            highlightColor: TechnicianUiTokens.accent.withValues(alpha: 0.05),
          ),
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _homeTabProgress,
                  builder: (context, p, _) {
                    return OrganicPatternBackground(tabProgress: _index == 0 ? p : null);
                  },
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _homeTabProgress,
                      builder: (context, p, _) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: _technicianTabTint(_index == 0 ? p : 0),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: IndexedStack(index: _index, children: tabs),
                ),
                if (!approved && _index != 3)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => showTechnicianUnderReviewDialog(context),
                      onTapDown: (_) => showTechnicianUnderReviewDialog(context),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            floatingActionButton: (_index == 2 || _index == 3)
                ? null
                : TechnicianAvailabilityFab(
                    availabilityStatus: availabilityStatus,
                    isOnline: isOnline,
                    onPressed: () {
                      if (!approved) return showTechnicianUnderReviewDialog(context);
                      showTechnicianAvailabilitySheet(
                        context,
                        uid,
                        current: availabilityStatus,
                        isOnline: isOnline,
                      );
                    },
                  ),
            bottomNavigationBar: TechnicianShellBottomNav(
              index: _index,
              navKeys: _navGuideKeys,
              onChanged: (i) {
                if (!approved && i != 3) {
                  showTechnicianUnderReviewDialog(context);
                  return;
                }
                if (i == 1) {
                  context.push(RouteNames.technicianMyJobs);
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

Color _technicianTabTint(double progress) {
  final x = progress.clamp(0.0, 2.0);
  final c = x < 1.0
      ? Color.lerp(DealerTabSurfaceTints.connect, DealerTabSurfaceTints.calculate, x)!
      : Color.lerp(DealerTabSurfaceTints.calculate, DealerTabSurfaceTints.shop, x - 1.0)!;
  return c.withValues(alpha: 0.1);
}

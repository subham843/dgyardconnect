import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/dealer_ui_tokens.dart';
import '../../../shared/widgets/glass_ui_kit.dart';
import '../../../shared/widgets/organic_pattern_background.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/maps_eta_service.dart';
import 'dealer_swiggy_connected_tab_shell.dart';

/// Travel line + ETA display for descendants under [DealerConnectShopHomeShell] (e.g. hero card).
class DealerTravelContextLine extends InheritedWidget {
  const DealerTravelContextLine({
    super.key,
    required this.line,
    required this.etaText,
    required super.child,
  });

  final String line;
  final String etaText;

  static String of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DealerTravelContextLine>();
    return scope?.line ?? '';
  }

  static String etaOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DealerTravelContextLine>();
    return scope?.etaText ?? '—';
  }

  @override
  bool updateShouldNotify(DealerTravelContextLine oldWidget) {
    return oldWidget.line != line || oldWidget.etaText != etaText;
  }
}

/// Lets dashboard descendants (e.g. Command Center) open the Find Technician sub-tab.
class DealerConnectHomeActions extends InheritedWidget {
  const DealerConnectHomeActions({
    super.key,
    required this.onOpenFindTechnician,
    required super.child,
  });

  final VoidCallback onOpenFindTechnician;

  static DealerConnectHomeActions? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DealerConnectHomeActions>();
  }

  @override
  bool updateShouldNotify(DealerConnectHomeActions oldWidget) {
    return onOpenFindTechnician != oldWidget.onOpenFindTechnician;
  }
}

/// Swiggy Instamart–style top block: ETA (Google Directions), partner line, Connect | Calculate | Shop.
class DealerConnectShopHomeShell extends StatefulWidget {
  const DealerConnectShopHomeShell({
    super.key,
    required this.uid,
    required this.photoUrl,
    required this.userFirstName,
    required this.approved,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.connectSlivers,
    required this.calculateSlivers,
    required this.shopSlivers,
    this.connectShopTabNotifier,
  });

  final String uid;
  final String? photoUrl;
  final String userFirstName;
  final bool approved;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;

  /// Inner slivers per tab. **Header:** pinned search → dealer dashboard + greeting → tabs.
  final List<Widget> connectSlivers;
  final List<Widget> calculateSlivers;
  final List<Widget> shopSlivers;

  /// Drives home chrome (page bg + bottom nav); page position **0–2** (Connect | Calculate | Shop).
  final ValueNotifier<double>? connectShopTabNotifier;

  @override
  State<DealerConnectShopHomeShell> createState() =>
      _DealerConnectShopHomeShellState();
}

class _DealerConnectShopHomeShellState
    extends State<DealerConnectShopHomeShell> {
  late final PageController _pageController;
  late final TextEditingController _homeSearchCtrl;
  int _pageIndex = 0;
  int? _etaMinutes;
  String? _addressLine;
  String? _partnerLabel;
  bool _etaLoading = false;
  Timer? _etaTimer;
  String _lastEtaContextKey = '';
  double? _pendingDestLat;
  double? _pendingDestLng;
  String? _pendingAddressHint;
  String? _pendingPartnerHint;

  OverlayEntry? _tabFlashEntry;

  static const _ink = Color(0xFF1C1C1E);
  static const _inkMuted = Color(0xFF636366);
  static const _accent = Color(0xFF0A84FF);
  static const _tabAnimDuration = Duration(milliseconds: 460);
  static const Curve _tabAnimCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _homeSearchCtrl = TextEditingController();
    _pageController = PageController();
    _pageController.addListener(_onPageTick);
    _etaTimer = Timer.periodic(const Duration(seconds: 55), (_) {
      final la = _pendingDestLat;
      final lo = _pendingDestLng;
      if (la != null && lo != null) {
        _refreshEta(
          destLat: la,
          destLng: lo,
          addressHint: _pendingAddressHint,
          partnerHint: _pendingPartnerHint,
        );
      }
    });
  }

  void _onPageTick() {
    widget.connectShopTabNotifier?.value = _tabProgress;
    if (mounted) setState(() {});
  }

  double get _tabProgress {
    if (!_pageController.hasClients) return _pageIndex.toDouble();
    final p = _pageController.page;
    if (p != null) return p.clamp(0.0, 2.0);
    return _pageIndex.toDouble();
  }

  Future<void> _animateToTab(int index) {
    return _pageController.animateToPage(
      index,
      duration: _tabAnimDuration,
      curve: _tabAnimCurve,
    );
  }

  static String _tabTitleForIndex(int i) {
    switch (i) {
      case 0:
        return 'Find Technician';
      case 1:
        return 'Estimate Cost';
      case 2:
        return 'Buy Equipment';
      default:
        return '';
    }
  }

  void _dismissTabFlash() {
    _tabFlashEntry?.remove();
    _tabFlashEntry = null;
  }

  void _showTabFlash(int index, BuildContext overlayContext) {
    if (!overlayContext.mounted) return;
    final title = _tabTitleForIndex(index);
    if (title.isEmpty) return;

    _dismissTabFlash();
    final overlay = Overlay.maybeOf(overlayContext);
    if (overlay == null) return;

    _tabFlashEntry = OverlayEntry(
      builder: (ctx) => _TabFlashBanner(
        title: title,
        onFinished: () {
          _tabFlashEntry?.remove();
          _tabFlashEntry = null;
        },
      ),
    );
    overlay.insert(_tabFlashEntry!);
  }

  @override
  void dispose() {
    _dismissTabFlash();
    _homeSearchCtrl.dispose();
    _pageController.removeListener(_onPageTick);
    _pageController.dispose();
    _etaTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshEta({
    double? destLat,
    double? destLng,
    String? addressHint,
    String? partnerHint,
  }) async {
    if (destLat == null || destLng == null) {
      _pendingDestLat = null;
      _pendingDestLng = null;
      _pendingAddressHint = null;
      _pendingPartnerHint = null;
      if (mounted) {
        setState(() {
          _etaMinutes = null;
          _etaLoading = false;
        });
      }
      return;
    }

    _pendingDestLat = destLat;
    _pendingDestLng = destLng;
    _pendingAddressHint = addressHint;
    _pendingPartnerHint = partnerHint;

    if (mounted) setState(() => _etaLoading = true);

    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _etaMinutes = null;
            _etaLoading = false;
            _addressLine = addressHint ?? _addressLine;
            _partnerLabel = partnerHint ?? _partnerLabel;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      final minutes = await MapsEtaService.drivingMinutes(
        originLat: pos.latitude,
        originLng: pos.longitude,
        destLat: destLat,
        destLng: destLng,
      );

      String? line = addressHint;
      if (line == null || line.isEmpty) {
        line = await MapsEtaService.formattedAddress(destLat, destLng);
      }

      if (!mounted) return;
      setState(() {
        _etaMinutes = minutes;
        _etaLoading = false;
        if (line != null && line.isNotEmpty) _addressLine = line;
        if (partnerHint != null) _partnerLabel = partnerHint;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _etaLoading = false;
          _addressLine = addressHint ?? _addressLine;
          _partnerLabel = partnerHint ?? _partnerLabel;
        });
      }
    }
  }

  void _applyJobContext(
    String contextKey,
    Map<String, dynamic>? job, {
    String? jobId,
    String? techId,
  }) {
    if (contextKey == _lastEtaContextKey) return;
    _lastEtaContextKey = contextKey;

    if (job == null) {
      _refreshEta(destLat: null, destLng: null);
      if (mounted) {
        setState(() {
          _partnerLabel = null;
          _addressLine =
              'No active job — travel time shows when a technician is assigned';
        });
      }
      return;
    }

    final live = job['technicianLiveLocation'] as Map<String, dynamic>?;
    double? dLat = (live?['latitude'] as num?)?.toDouble();
    double? dLng = (live?['longitude'] as num?)?.toDouble();

    if (dLat == null || dLng == null) {
      final gp = job['location'] as GeoPoint?;
      if (gp != null) {
        dLat = gp.latitude;
        dLng = gp.longitude;
      }
    }

    final title = (job['title'] as String?)?.trim();
    final addr = (job['address'] as String?)?.trim();
    var partner = 'Active job';
    if (techId != null && techId.isNotEmpty) partner = 'Technician';
    if (title != null && title.isNotEmpty) partner = title;

    final hint = (addr != null && addr.isNotEmpty) ? addr : null;

    if (dLat != null && dLng != null) {
      _refreshEta(
        destLat: dLat,
        destLng: dLng,
        addressHint: hint,
        partnerHint: partner,
      );
      return;
    }

    if (techId != null && techId.isNotEmpty) {
      FirestoreService.users().doc(techId).get().then((doc) {
        if (!mounted) return;
        final gp = doc.data()?['lastLocation'] as GeoPoint?;
        if (gp != null) {
          final subKey = '${contextKey}_tl_${gp.latitude}_${gp.longitude}';
          if (subKey == _lastEtaContextKey) return;
          _lastEtaContextKey = subKey;
          _refreshEta(
            destLat: gp.latitude,
            destLng: gp.longitude,
            addressHint: hint,
            partnerHint: partner,
          );
        } else if (hint != null) {
          setState(() {
            _etaMinutes = null;
            _etaLoading = false;
            _addressLine = hint;
            _partnerLabel = partner;
          });
        } else {
          setState(() {
            _etaMinutes = null;
            _etaLoading = false;
            _partnerLabel = partner;
            _addressLine = 'Technician location updates when they go online';
          });
        }
      });
      return;
    }

    if (hint != null) {
      setState(() {
        _etaMinutes = null;
        _etaLoading = false;
        _addressLine = hint;
        _partnerLabel = partner;
      });
    } else {
      setState(() {
        _etaMinutes = null;
        _etaLoading = false;
        _partnerLabel = partner;
        _addressLine = 'Add a site location to see travel time';
      });
    }
  }

  static String _contextKeyForJob(Map<String, dynamic>? job, String? jobDocId) {
    if (job == null) return 'none';
    final live = job['technicianLiveLocation'] as Map<String, dynamic>?;
    final la = live?['latitude'];
    final lo = live?['longitude'];
    final gp = job['location'] as GeoPoint?;
    return '${jobDocId ?? ''}|$la|$lo|${gp?.latitude}|${gp?.longitude}|${job['technicianId']}';
  }

  void _openJobsSearch(String query) {
    final t = query.trim();
    if (t.isEmpty) {
      context.push(RouteNames.dealerMyJobs);
      return;
    }
    context.push(
      Uri(path: RouteNames.dealerMyJobs, queryParameters: {'q': t}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.jobs()
          .where('dealerId', isEqualTo: widget.uid)
          .orderBy('createdAt', descending: true)
          .limit(24)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        QueryDocumentSnapshot<Map<String, dynamic>>? pickDoc;
        for (final d in docs) {
          final m = d.data();
          final st = (m['status'] ?? '').toString();
          if (!_activeStatuses.contains(st)) continue;
          final tid = m['technicianId'] as String?;
          if (tid != null && tid.isNotEmpty) {
            pickDoc = d;
            break;
          }
        }
        if (pickDoc == null) {
          for (final d in docs) {
            final st = (d.data()['status'] ?? '').toString();
            if (_activeStatuses.contains(st)) {
              pickDoc = d;
              break;
            }
          }
        }

        final pick = pickDoc?.data();
        final jobId = pickDoc?.id;
        final techId = pick?['technicianId'] as String?;
        final ck = _contextKeyForJob(pick, jobId);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyJobContext(ck, pick, jobId: jobId, techId: techId);
        });

        final hasActiveContext = pick != null;

        var runningJobsCount = 0;
        String? runningJobTitlePreview;
        for (final d in docs) {
          final st = (d.data()['status'] ?? '').toString();
          if (!_dealerOpenRunningStatuses.contains(st)) continue;
          runningJobsCount++;
          if (runningJobTitlePreview == null) {
            final t = (d.data()['title'] as String?)?.trim();
            if (t != null && t.isNotEmpty) runningJobTitlePreview = t;
          }
        }

        final etaText = _etaLoading
            ? '…'
            : (_etaMinutes != null ? '${_etaMinutes!} mins' : '—');

        return DealerTravelContextLine(
          line: _travelContextLine(hasActiveContext),
          etaText: etaText,
          child: DealerConnectHomeActions(
            onOpenFindTechnician: () => unawaited(_animateToTab(0)),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: OrganicPatternPainter.kBase,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
              child: NestedScrollView(
                floatHeaderSlivers: false,
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                      return [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _DealerPinnedSearchBarDelegate(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: _buildSearchAndActionsRow(context),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildDashboardOverviewHeader(context),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                            child: DealerGlassTabStrip(
                              tabProgress: _tabProgress,
                              onTabSelected: (i) =>
                                  unawaited(_animateToTab(i)),
                              runningJobsCount: runningJobsCount,
                              runningJobTitlePreview: runningJobTitlePreview,
                              onOpenRunningJobs: () =>
                                  context.push(RouteNames.dealerMyJobs),
                            ),
                          ),
                        ),
                      ];
                    },
                body: DealerSwiggyConnectedTabShell(
                  pageController: _pageController,
                  connectSlivers: widget.connectSlivers,
                  calculateSlivers: widget.calculateSlivers,
                  shopSlivers: widget.shopSlivers,
                  onPageChanged: (i) {
                    setState(() => _pageIndex = i);
                    _showTabFlash(i, context);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Job / site line shown under Dealer Command Center (same logic as former status card row).
  String _travelContextLine(bool hasActiveContext) {
    final line =
        _addressLine ??
        (hasActiveContext
            ? 'Waiting for live location…'
            : 'Post a job to see travel time to your technician or site');
    if (!hasActiveContext) {
      return line;
    }
    if (_partnerLabel != null && _partnerLabel == 'Technician') {
      return 'Technician • $line';
    }
    if (_partnerLabel != null) {
      return '${_partnerLabel!} • $line';
    }
    return 'Site • $line';
  }

  /// Reference layout: "DEALER DASHBOARD" + time-based greeting above the hero card.
  Widget _buildDashboardOverviewHeader(BuildContext context) {
    final greetingLine = _dealerGreetingLine(widget.userFirstName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Text(
        greetingLine,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black.withValues(alpha: 0.42),
          letterSpacing: -0.15,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildSearchAndActionsRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildPremiumSearchBar()),
        const SizedBox(width: 12),
        _floatingGlassActionIcon(
          icon: CupertinoIcons.bell,
          iconColor: AppColors.brandWarmLight,
          accentGlow: AppColors.brandWarmLight.withValues(alpha: 0.22),
          onTap: widget.onNotificationsTap,
        ),
        const SizedBox(width: 10),
        _floatingGlassActionIcon(
          icon: CupertinoIcons.gear,
          iconColor: const Color(0xFF8E8E93),
          accentGlow: const Color(0xFF8E8E93).withValues(alpha: 0.18),
          onTap: widget.onSettingsTap,
        ),
        const SizedBox(width: 10),
        _floatingAvatarChip(
          child: _HeaderProfileAvatar(
            photoUrl: widget.photoUrl,
            userFirstName: widget.userFirstName,
            accent: _accent,
            ink: _ink,
          ),
        ),
      ],
    );
  }

  /// Lift shadow outside; glass + bezel + text in one layer (no full-field overlays on text).
  Widget _buildPremiumSearchBar() {
    const searchRadius = 22.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(searchRadius),
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
        radius: searchRadius,
        opacity: 0.52,
        blurSigma: 28,
        showBorder: true,
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 12,
              ),
            ),
          ),
          child: TextField(
            controller: _homeSearchCtrl,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.15,
              height: 1.25,
              color: _ink,
            ),
            cursorColor: _accent,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search jobs, sites…',
              hintStyle: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
                color: _inkMuted.withValues(alpha: 0.68),
              ),
              prefixIcon: Icon(
                CupertinoIcons.search,
                color: _ink.withValues(alpha: 0.4),
                size: 20,
              ),
              suffixIcon: _homeSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: _ink.withValues(alpha: 0.36),
                        size: 20,
                      ),
                      onPressed: () {
                        _homeSearchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 12,
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: _openJobsSearch,
          ),
        ),
      ),
    );
  }

  /// Separate floating glass modules with lift shadow + optional accent halo.
  Widget _floatingGlassActionIcon({
    required IconData icon,
    required Color iconColor,
    required Color accentGlow,
    required VoidCallback onTap,
  }) {
    const r = 16.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accentGlow,
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.48),
            blurRadius: 1.5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: GlassIconButton(
        icon: icon,
        iconColor: iconColor,
        onTap: onTap,
        borderRadius: r,
        size: 42,
        iconSize: 21,
        blurSigma: 28,
      ),
    );
  }

  Widget _floatingAvatarChip({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 1,
            offset: const Offset(0, -0.5),
          ),
        ],
      ),
      child: child,
    );
  }

}

/// Centered glassmorphism label when the home sub-tab changes.
class _TabFlashBanner extends StatefulWidget {
  const _TabFlashBanner({
    required this.title,
    required this.onFinished,
  });

  final String title;
  final VoidCallback onFinished;

  @override
  State<_TabFlashBanner> createState() => _TabFlashBannerState();
}

class _TabFlashBannerState extends State<_TabFlashBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _inDuration = Duration(milliseconds: 140);
  static const _outDuration = Duration(milliseconds: 160);
  static const _holdDuration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _runSequence();
  }

  Future<void> _runSequence() async {
    _ctrl.duration = _inDuration;
    await _ctrl.forward();
    if (!mounted) return;
    await Future<void>.delayed(_holdDuration);
    if (!mounted) return;
    _ctrl.duration = _outDuration;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_ctrl.value);
            final opacity = t.clamp(0.0, 1.0);
            final scale = 0.92 + 0.08 * t;

            final maxW = MediaQuery.sizeOf(context).width - 48;
            return Center(
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxW),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          blurRadius: 1,
                          offset: const Offset(0, -0.5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: Colors.white.withValues(alpha: 0.44),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.58),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 16,
                            ),
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.45,
                                height: 1.2,
                                color: const Color(0xFF0F172A),
                                decoration: TextDecoration.none,
                                decorationThickness: 0,
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
          },
        ),
      ),
    );
  }
}

/// Pinned header: search + notification, settings, profile only (below scrolls).
const double _kPinnedSearchHeaderExtent = 86.0;

class _DealerPinnedSearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _DealerPinnedSearchBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => _kPinnedSearchHeaderExtent;

  @override
  double get maxExtent => _kPinnedSearchHeaderExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.transparent,
      elevation: overlapsContent ? 0.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: SizedBox(
        height: _kPinnedSearchHeaderExtent,
        width: double.infinity,
        child: ClipRect(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            primary: false,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DealerPinnedSearchBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _HeaderProfileAvatar extends StatelessWidget {
  const _HeaderProfileAvatar({
    required this.photoUrl,
    required this.userFirstName,
    required this.accent,
    required this.ink,
  });

  final String? photoUrl;
  final String userFirstName;
  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: DealerUiTokens.glassRimShadows,
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DealerUiTokens.glassCardBlurSigma,
            sigmaY: DealerUiTokens.glassCardBlurSigma,
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(RouteNames.dealerProfile),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFF4F6F9),
                  backgroundImage:
                      (photoUrl != null && photoUrl!.trim().isNotEmpty)
                      ? NetworkImage(photoUrl!.trim())
                      : null,
                  child: (photoUrl == null || photoUrl!.trim().isEmpty)
                      ? Text(
                          userFirstName.isNotEmpty
                              ? userFirstName[0].toUpperCase()
                              : 'D',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _dealerGreetingLine(String firstName) {
  final hour = DateTime.now().hour;
  final base = (hour >= 4 && hour < 12)
      ? 'Good morning'
      : (hour >= 12 && hour < 17)
      ? 'Good afternoon'
      : (hour >= 17 && hour < 21)
      ? 'Good evening'
      : 'Good night';
  final name = firstName.trim().isEmpty ? 'there' : firstName.trim();
  return '$base, $name';
}

const _activeStatuses = {
  'in_progress',
  'paid',
  'agreed',
  'payment_pending',
  'pending_dealer_confirm',
};

/// Matches job `status` strings in Firestore (camelCase) for open / in-flight work.
const _dealerOpenRunningStatuses = {
  'bidding',
  'agreed',
  'paymentPending',
  'paid',
  'inProgress',
  'pendingDealerConfirm',
};

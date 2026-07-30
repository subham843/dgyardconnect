import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/firestore_dynamic.dart';

/// Android Banner Ad Unit IDs
/// - Debug: Google test unit
/// - Release: provide with --dart-define=ADMOB_ANDROID_BANNER_UNIT_ID=ca-app-pub-xxx/yyy
const String _kAdUnitIdBannerTest = 'ca-app-pub-3940256099942544/6300978111';
const String _kAdUnitIdBannerProd = String.fromEnvironment(
  'ADMOB_ANDROID_BANNER_UNIT_ID',
  defaultValue: '',
);

/// Premium carousel section for Admin Ads (Firestore) and Google Ad slots.
/// Supports image/video ads with date filtering, auto-slide, and elegant UI.
/// When [heroMode] is true, uses larger height and rounded cards for the
/// collapsible dashboard hero banner.
class SliderAdsSection extends StatefulWidget {
  const SliderAdsSection({
    super.key,
    this.heroMode = false,
    this.shellBorderRadius,
  });

  final bool heroMode;

  /// When set (e.g. 24), wraps the carousel in a dashboard-style rounded shell.
  final double? shellBorderRadius;

  @override
  State<SliderAdsSection> createState() => _SliderAdsSectionState();
}

class _SliderAdsSectionState extends State<SliderAdsSection> {
  final PageController _pageController = PageController(
    viewportFraction: 0.92,
  );
  Timer? _autoSlideTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
  }

  void _startAutoSlide(int itemCount) {
    _autoSlideTimer?.cancel();
    if (itemCount <= 1 || _isPaused) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isPaused) return;
      final current = _pageController.page?.round() ?? 0;
      final next = (current + 1) % itemCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseAutoSlide() {
    setState(() => _isPaused = true);
    _autoSlideTimer?.cancel();
  }

  void _resumeAutoSlide(int itemCount) {
    setState(() => _isPaused = false);
    _startAutoSlide(itemCount);
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _wrapShell(Widget child) {
    final r = widget.shellBorderRadius;
    if (r == null || r <= 0) return child;
    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: Colors.white.withValues(alpha: 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.78),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        child: child,
      ),
    );
  }

  Widget _buildGoogleAdOnly() {
    final padding = widget.heroMode
        ? const EdgeInsets.fromLTRB(16, 8, 16, 12)
        : const EdgeInsets.only(top: 16);
    final inner = _GoogleAdPlaceholder(
      heroMode: widget.heroMode,
      radiusOverride: widget.shellBorderRadius != null ? 18.0 : null,
    );
    return Padding(
      padding: padding,
      child: _wrapShell(inner),
    ).animate().fadeIn(duration: 300.ms);
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.ads().snapshots(),
      builder: (context, snapshot) {
        // Show Google ad when loading or on Firestore error
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            debugPrint('Ads Firestore error: ${snapshot.error}');
          }
          return _buildGoogleAdOnly();
        }

        final now = DateTime.now();
        final filtered = snapshot.data!.docs
            .where((doc) {
              final d = doc.data();
              if (!boolFromFirestore(d['active'], fallback: false)) return false;
              final inStatus =
                  boolFromFirestore(d['showInStatus'], fallback: false);
              final inHomeBanner =
                  boolFromFirestore(d['showInHomeBanner'], fallback: false);
              // Status/Banner media must never leak into sponsored carousel.
              if (inStatus || inHomeBanner) return false;
              // Dedicated sponsored placement toggle; keep legacy docs visible.
              final explicitSponsored = d.containsKey('showInSponsored');
              if (explicitSponsored &&
                  !boolFromFirestore(d['showInSponsored'], fallback: false)) {
                return false;
              }
              final start = _parseDate(d['startDate']);
              final end = _parseDate(d['endDate']);
              if (start != null && now.isBefore(start)) return false;
              if (end != null && now.isAfter(end)) return false;
              return (d['url'] as String? ?? '').isNotEmpty;
            })
            .toList()
          ..sort((a, b) {
            final oa = a.data()['order'] as num? ?? 0;
            final ob = b.data()['order'] as num? ?? 0;
            return oa.compareTo(ob);
          });

        // Include Google ad slot as optional last slide
        const hasGoogleAdSlot = true;
        final itemCount = filtered.isEmpty ? 1 : filtered.length + 1;

        if (itemCount == 0) return const SizedBox.shrink();

        if (filtered.isEmpty && hasGoogleAdSlot) {
          final padding = widget.heroMode
              ? const EdgeInsets.fromLTRB(16, 8, 16, 12)
              : const EdgeInsets.only(top: 16);
          final inner = _GoogleAdPlaceholder(
            heroMode: widget.heroMode,
            radiusOverride: widget.shellBorderRadius != null ? 18.0 : null,
          );
          return Padding(
            padding: padding,
            child: _wrapShell(inner),
          ).animate().fadeIn(duration: 300.ms);
        }

        return _PremiumAdsCarousel(
          ads: filtered,
          includeGoogleAdSlot: hasGoogleAdSlot,
          heroMode: widget.heroMode,
          shellBorderRadius: widget.shellBorderRadius,
          pageController: _pageController,
          onPause: _pauseAutoSlide,
          onResume: () => _resumeAutoSlide(itemCount),
          onInit: () => _startAutoSlide(itemCount),
        );
      },
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

class _PremiumAdsCarousel extends StatefulWidget {
  const _PremiumAdsCarousel({
    required this.ads,
    required this.pageController,
    required this.onPause,
    required this.onResume,
    required this.onInit,
    this.includeGoogleAdSlot = true,
    this.heroMode = false,
    this.shellBorderRadius,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> ads;
  final PageController pageController;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onInit;
  final bool includeGoogleAdSlot;
  final bool heroMode;
  final double? shellBorderRadius;

  @override
  State<_PremiumAdsCarousel> createState() => _PremiumAdsCarouselState();
}

class _PremiumAdsCarouselState extends State<_PremiumAdsCarousel> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    final isHero = widget.heroMode;
    final padding = isHero
        ? const EdgeInsets.fromLTRB(16, 8, 16, 12)
        : const EdgeInsets.only(top: 16);
    final carouselHeight = isHero ? 220.0 : 180.0;
    final shellR = widget.shellBorderRadius;
    final useShell = shellR != null && shellR > 0;
    final innerCardRadius = useShell ? 18.0 : null;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => widget.onPause(),
          onTapUp: (_) => widget.onResume(),
          onTapCancel: () => widget.onResume(),
          child: SizedBox(
            height: carouselHeight,
            child: PageView.builder(
              controller: widget.pageController,
              itemCount: widget.ads.length + (widget.includeGoogleAdSlot ? 1 : 0),
              onPageChanged: (i) => setState(() => _currentPage = i),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final itemPadding = isHero ? 4.0 : 0.0;
                if (widget.includeGoogleAdSlot && index == widget.ads.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: itemPadding),
                    child: _GoogleAdPlaceholder(
                      heroMode: isHero,
                      radiusOverride: innerCardRadius,
                    ),
                  );
                }
                final ad = widget.ads[index].data();
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: itemPadding),
                  child: _PremiumAdCard(
                    type: ad['type'] as String? ?? 'image',
                    url: ad['url'] as String? ?? '',
                    title: ad['title'] as String?,
                    description: ad['description'] as String?,
                    link: ad['link'] as String?,
                    ctaText: ad['ctaText'] as String?,
                    heroMode: isHero,
                    radiusOverride: innerCardRadius,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PageIndicatorDots(
          count: widget.ads.length + (widget.includeGoogleAdSlot ? 1 : 0),
          current: _currentPage,
          heroMode: isHero,
        ),
      ],
    );

    Widget body = column;
    if (useShell) {
      body = Material(
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        color: Colors.white.withValues(alpha: 0.48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shellR),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.78),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          child: column,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: body,
    )
        .animate()
        .fadeIn(delay: 60.ms, duration: 400.ms)
        .slideY(begin: 0.04, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
  }
}

class _PremiumAdCard extends StatefulWidget {
  const _PremiumAdCard({
    required this.type,
    required this.url,
    this.title,
    this.description,
    this.link,
    this.ctaText,
    this.heroMode = false,
    this.radiusOverride,
  });

  final String type;
  final String url;
  final String? title;
  final String? description;
  final String? link;
  final String? ctaText;
  final bool heroMode;
  final double? radiusOverride;

  @override
  State<_PremiumAdCard> createState() => _PremiumAdCardState();
}

class _PremiumAdCardState extends State<_PremiumAdCard> {
  @override
  Widget build(BuildContext context) {
    final radius =
        widget.radiusOverride ?? (widget.heroMode ? 20.0 : 12.0);
    final ctaLabel = widget.ctaText ?? 'Explore';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.link != null && widget.link!.isNotEmpty) {
            launchUrl(Uri.parse(widget.link!));
          }
        },
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.heroMode ? 0.12 : 0.06),
                blurRadius: widget.heroMode ? 24 : 20,
                offset: Offset(0, widget.heroMode ? 8 : 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.all(widget.heroMode ? 12 : 10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.type == 'video')
                    _AdVideoPlayer(url: widget.url)
                  else
                    CachedNetworkImage(
                    imageUrl: widget.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surfaceVariant,
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  ),
                // CTA area: headline, optional description, CTA button
                if (widget.title != null && widget.title!.isNotEmpty) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        widget.heroMode ? 20 : 16,
                        16,
                        widget.heroMode ? 20 : 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            // Light overlay for technician panel (no dark "dirty" feel).
                            Colors.white.withValues(alpha: 0.78),
                          ],
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: widget.heroMode ? 17 : 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.description != null &&
                                    widget.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.description!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.link != null && widget.link!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.heroMode ? 18 : 14,
                                vertical: widget.heroMode ? 10 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(
                                    widget.heroMode ? 14 : 12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ctaLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: widget.heroMode ? 14 : 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: widget.heroMode ? 18 : 16,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdVideoPlayer extends StatefulWidget {
  const _AdVideoPlayer({required this.url});

  final String url;

  @override
  State<_AdVideoPlayer> createState() => _AdVideoPlayerState();
}

class _AdVideoPlayerState extends State<_AdVideoPlayer> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

class _PageIndicatorDots extends StatelessWidget {
  const _PageIndicatorDots({
    required this.count,
    required this.current,
    this.heroMode = false,
  });

  final int count;
  final int current;
  final bool heroMode;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    final activeWidth = heroMode ? 18.0 : 14.0;
    final dotSize = heroMode ? 6.0 : 5.0;
    final activeColor = heroMode ? Colors.white : AppColors.primary;
    final inactiveColor = heroMode
        ? Colors.white.withValues(alpha: 0.5)
        : AppColors.textSecondary.withValues(alpha: 0.35);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? activeWidth : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(dotSize / 2),
            boxShadow: heroMode && isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

/// Google BannerAd slot - loads real ad on mobile, placeholder on web.
class _GoogleAdPlaceholder extends StatefulWidget {
  const _GoogleAdPlaceholder({
    this.heroMode = false,
    this.radiusOverride,
  });

  final bool heroMode;
  final double? radiusOverride;

  @override
  State<_GoogleAdPlaceholder> createState() => _GoogleAdPlaceholderState();
}

class _GoogleAdPlaceholderState extends State<_GoogleAdPlaceholder> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }
  }

  Future<void> _loadAd() async {
    if (!mounted) return;
    final adUnitId = kDebugMode ? _kAdUnitIdBannerTest : _kAdUnitIdBannerProd;
    if (adUnitId.isEmpty) {
      setState(() {
        _isLoaded = false;
        _loadError = 'Ad unit is not configured for this build.';
      });
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _loadError = null;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
              _loadError = '${err.code}: ${err.message}';
            });
          }
          debugPrint('AdMob load failed: ${err.code} ${err.message}');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _openAdInspector() {
    if (kIsWeb) return;
    try {
      MobileAds.instance.openAdInspector((error) {
        if (error != null) {
          debugPrint('Ad Inspector: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ad Inspector: ${error.toString()}')),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Ad Inspector open failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ad Inspector: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    final height = widget.heroMode ? 220.0 : 180.0;
    final radius =
        widget.radiusOverride ?? (widget.heroMode ? 20.0 : 20.0);

    Widget content;
    if (_isLoaded && _bannerAd != null) {
      content = Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.heroMode ? 0.12 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Center(
            child: SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ),
      );
    } else {
      content = Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.12),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_outlined, size: 32, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(
                _loadError != null ? 'Ad failed to load' : 'Loading ad...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Long-press for Ad Inspector',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: kDebugMode ? _openAdInspector : null,
      child: content,
    );
  }
}

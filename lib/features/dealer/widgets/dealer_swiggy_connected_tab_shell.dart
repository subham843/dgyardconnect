import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/glass_ui_kit.dart';
import '../../../shared/widgets/organic_pattern_background.dart';

/// Glass tab block: optional **open jobs** strip + **Find Technician** (sky / Connect tint) + Estimate / Buy.
class DealerGlassTabStrip extends StatelessWidget {
  const DealerGlassTabStrip({
    super.key,
    required this.tabProgress,
    required this.onTabSelected,
    required this.runningJobsCount,
    this.runningJobTitlePreview,
    required this.onOpenRunningJobs,
  });

  final double tabProgress;
  final ValueChanged<int> onTabSelected;

  /// Open / in-progress jobs (same notion as dealer “running” insights).
  final int runningJobsCount;
  final String? runningJobTitlePreview;
  final VoidCallback onOpenRunningJobs;

  static const double _gap = 10;
  static const double _radiusLarge = 28;
  static const double _radiusTop = 22;
  static const double _radiusSmall = 22;

  static const Color _ink = Color(0xFF1C1C1E);
  static const Color _inkSoft = Color(0xFF64748B);
  static const Color _accent = Color(0xFF2563EB);

  static double _cellEmphasis(int index, double page) {
    final d = (page - index).abs();
    return (1.0 - d).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = tabProgress.clamp(0.0, 2.0);
    final e0 = _cellEmphasis(0, p);
    final e1 = _cellEmphasis(1, p);
    final e2 = _cellEmphasis(2, p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (runningJobsCount > 0) ...[
          _CompactRunningJobsHeader(
            count: runningJobsCount,
            titlePreview: runningJobTitlePreview,
            onTap: () {
              HapticFeedback.lightImpact();
              onOpenRunningJobs();
            },
          ),
          const SizedBox(height: _gap),
        ],
        _PrimaryFindTechnicianCard(
          emphasis: e0,
          onTap: () {
            HapticFeedback.lightImpact();
            onTabSelected(0);
          },
        ),
        const SizedBox(height: _gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FrostedSecondaryTab(
                title: 'Estimate Cost',
                subtitle: 'Cost estimate for your jobs',
                icon: Icons.calculate_rounded,
                emphasis: e1,
                borderRadius: _radiusSmall,
                palette: _SecondaryTabPalette.estimate,
                onTap: () => onTabSelected(1),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _FrostedSecondaryTab(
                title: 'Buy Equipment',
                subtitle: 'Buy & sell tools and parts',
                icon: Icons.shopping_cart_rounded,
                emphasis: e2,
                borderRadius: _radiusSmall,
                palette: _SecondaryTabPalette.shop,
                onTap: () => onTabSelected(2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactRunningJobsHeader extends StatelessWidget {
  const _CompactRunningJobsHeader({
    required this.count,
    this.titlePreview,
    required this.onTap,
  });

  final int count;
  final String? titlePreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = count == 1 ? '1 open job' : '$count open jobs';
    return GlassBox(
      radius: DealerGlassTabStrip._radiusTop,
      opacity: 0.48,
      blurSigma: 22,
      tintColors: [
        Colors.white.withValues(alpha: 0.42),
        Colors.white.withValues(alpha: 0.06),
      ],
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.work_history_rounded,
            color: DealerGlassTabStrip._accent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: DealerGlassTabStrip._ink,
                    letterSpacing: -0.35,
                    height: 1.2,
                  ),
                ),
                if (titlePreview != null && titlePreview!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    titlePreview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: DealerGlassTabStrip._inkSoft,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: DealerGlassTabStrip._inkSoft,
            size: 24,
          ),
        ],
      ),
    );
  }
}

/// Frosted glass + sky tint — elevated to match Post Job prominence; press scale + ripple.
class _PrimaryFindTechnicianCard extends StatefulWidget {
  const _PrimaryFindTechnicianCard({
    required this.emphasis,
    required this.onTap,
  });

  final double emphasis;
  final VoidCallback onTap;

  static final Color _glassMid = Color.lerp(
    Colors.white,
    DealerTabSurfaceTints.connect,
    0.28,
  )!;

  static const Color _titleInk = Color(0xFF0F172A);
  static const Color _subInk = Color(0xFF64748B);
  static const Color _skyBorderStrong = Color(0xFF3B82F6);
  static const Color _skyBorderSoft = Color(0xFF93C5FD);
  static const Color _iconBlue = Color(0xFF2563EB);

  @override
  State<_PrimaryFindTechnicianCard> createState() =>
      _PrimaryFindTechnicianCardState();
}

class _PrimaryFindTechnicianCardState extends State<_PrimaryFindTechnicianCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutCubic.transform(widget.emphasis.clamp(0.0, 1.0));
    final scale = lerpDouble(0.985, 1.0, e)!;

    final r = BorderRadius.circular(DealerGlassTabStrip._radiusLarge);

    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
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
              borderRadius: r,
              boxShadow: [
                BoxShadow(
                  color: DealerTabSurfaceTints.connect.withValues(alpha: 0.2),
                  blurRadius: 26,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: _PrimaryFindTechnicianCard._iconBlue.withValues(
                    alpha: 0.11,
                  ),
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
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: r,
                    splashColor:
                        _PrimaryFindTechnicianCard._iconBlue.withValues(
                      alpha: 0.12,
                    ),
                    highlightColor: Colors.black.withValues(alpha: 0.04),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: r,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.68),
                            _PrimaryFindTechnicianCard._glassMid
                                .withValues(alpha: 0.56),
                            DealerTabSurfaceTints.connect
                                .withValues(alpha: 0.15),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        border: Border.all(
                          color: e > 0.55
                              ? _PrimaryFindTechnicianCard._skyBorderStrong
                                  .withValues(alpha: 0.3 + 0.18 * e)
                              : Color.lerp(
                                  Colors.white.withValues(alpha: 0.78),
                                  _PrimaryFindTechnicianCard._skyBorderSoft
                                      .withValues(alpha: 0.32),
                                  0.4,
                                )!,
                          width: e > 0.55 ? 1.9 : 1.25,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.55),
                            blurRadius: 2,
                            spreadRadius: -1,
                            offset: const Offset(-0.5, -1.5),
                          ),
                          BoxShadow(
                            color: DealerTabSurfaceTints.connect.withValues(
                              alpha: 0.12,
                            ),
                            blurRadius: 14,
                            spreadRadius: -3,
                            offset: Offset(0, 4 + e * 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                        child: Row(
                          children: [
                            _GlassWrenchBubble(
                              iconColor: _PrimaryFindTechnicianCard._iconBlue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Find Technician',
                                    style: GoogleFonts.inter(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: _PrimaryFindTechnicianCard._titleInk,
                                      letterSpacing: -0.4,
                                      height: 1.12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Search and connect with field technicians',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _PrimaryFindTechnicianCard._subInk,
                                      height: 1.28,
                                      letterSpacing: -0.08,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _PrimaryFindTechnicianCard._subInk,
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
        ),
      ),
    );
  }
}

class _GlassWrenchBubble extends StatelessWidget {
  const _GlassWrenchBubble({this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ink = iconColor ?? Colors.white;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.5),
            DealerTabSurfaceTints.connect.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(-1, -1),
          ),
          BoxShadow(
            color: _PrimaryFindTechnicianCard._iconBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.handyman_rounded, color: ink, size: 23),
    );
  }
}

/// Glass tints aligned with [DealerTabSurfaceTints] (same hues as full-page tab BG).
class _SecondaryTabPalette {
  const _SecondaryTabPalette({
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

  /// Calculate / Estimate Cost tab — mint (matches organic pattern segment).
  static final _SecondaryTabPalette estimate = _SecondaryTabPalette(
    patternTint: DealerTabSurfaceTints.calculate,
    glassMid: Color.lerp(
      Colors.white,
      DealerTabSurfaceTints.calculate,
      0.22,
    )!,
    icon: const Color(0xFF0F766E),
    borderActive: const Color(0xFF14B8A6),
    borderIdleBlend: const Color(0xFF5EEAD4),
    shadowTint: const Color(0xFF0D9488),
  );

  /// Shop / Buy Equipment tab — peach (matches organic pattern segment).
  static final _SecondaryTabPalette shop = _SecondaryTabPalette(
    patternTint: DealerTabSurfaceTints.shop,
    glassMid: Color.lerp(
      Colors.white,
      DealerTabSurfaceTints.shop,
      0.26,
    )!,
    icon: const Color(0xFFC2410C),
    borderActive: const Color(0xFFF59E0B),
    borderIdleBlend: const Color(0xFFFCD34D),
    shadowTint: const Color(0xFFD97706),
  );
}

/// Frosted glass tile — tab-specific tint (mint / peach), not generic blue.
class _FrostedSecondaryTab extends StatelessWidget {
  const _FrostedSecondaryTab({
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
  final _SecondaryTabPalette palette;
  final VoidCallback onTap;

  static const Color _titleInk = Color(0xFF0F172A);
  static const Color _subInk = Color(0xFF64748B);

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
                          color: _titleInk,
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
                          color: _subInk,
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

/// Tab page bodies — [NestedScrollView] header includes [DealerGlassTabStrip].
class DealerSwiggyConnectedTabShell extends StatelessWidget {
  const DealerSwiggyConnectedTabShell({
    super.key,
    required this.pageController,
    required this.connectSlivers,
    required this.calculateSlivers,
    required this.shopSlivers,
    this.onPageChanged,
  });

  final PageController pageController;
  final List<Widget> connectSlivers;
  final List<Widget> calculateSlivers;
  final List<Widget> shopSlivers;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: onPageChanged,
      children: [
        CustomScrollView(
          key: const PageStorageKey<String>('dealer_home_connect'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: connectSlivers,
        ),
        CustomScrollView(
          key: const PageStorageKey<String>('dealer_home_calculate'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: calculateSlivers,
        ),
        CustomScrollView(
          key: const PageStorageKey<String>('dealer_home_shop'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: shopSlivers,
        ),
      ],
    );
  }
}

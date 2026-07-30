import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glassmorphism_app_bar.dart';
import 'marketplace_bottom_nav_bar.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared premium visual wrapper for marketplace screens.
///
/// Purpose: apply premium gradient + subtle glow background consistently
/// without changing business logic inside each screen.
class MarketplacePremiumShell extends StatelessWidget {
  const MarketplacePremiumShell({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final glassAppBar = appBar is AppBar
        ? _toGlassAppBar(context, appBar as AppBar)
        : appBar;

    final extraBottom = bottomNavigationBar;

    return Scaffold(
      // Fallback background so no black shows outside painted body.
      backgroundColor: AppColors.background,
      extendBody: true,
      // AppBar ke neeche content ko push karna hai (overlay nahi).
      extendBodyBehindAppBar: false,
      appBar: glassAppBar,
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (extraBottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: extraBottom,
              ),
            const MarketplaceBottomNavBar(),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surfaceVariant,
                    const Color(0xFFEFF6FF),
                    const Color(0xFFF8FAFC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Subtle premium glow accents (no interaction).
          Positioned(
            top: -220,
            left: -180,
            child: _GlowDot(
              color: AppColors.primaryLight.withValues(alpha: 0.20),
              size: 420,
            ),
          ),
          Positioned(
            top: 120,
            right: -220,
            child: _GlowDot(
              color: AppColors.accent.withValues(alpha: 0.16),
              size: 420,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Soft vignette to make content look more "carded".
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Keep the passed content layout-under-AppBar (no full-screen overlay).
          body,
        ],
      ),
    );
  }

  PreferredSizeWidget? _toGlassAppBar(BuildContext context, AppBar a) {
    final canPop = GoRouter.of(context).canPop();
    final implyLeading = a.automaticallyImplyLeading;

    final Widget titleWidget = a.title ?? const SizedBox.shrink();
    final Widget effectiveTitle = titleWidget is Text
        ? Text(
            titleWidget.data ?? '',
            maxLines: titleWidget.maxLines ?? 1,
            overflow: titleWidget.overflow ?? TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          )
        : DefaultTextStyle.merge(
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
            child: titleWidget,
          );

    final leadingWidget = a.leading ??
        ((implyLeading && canPop)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);
    final hasLeading = leadingWidget != null;

    final combinedLeading = hasLeading
        ? Row(
            children: [
              leadingWidget,
              const SizedBox(width: 10),
              Expanded(child: effectiveTitle),
            ],
          )
        : effectiveTitle;

    final actions = a.actions ?? const <Widget>[];

    return PreferredSize(
      preferredSize: const Size.fromHeight(82),
      child: SafeArea(
        top: true,
        bottom: false,
        child: GlassmorphismAppBar(
          height: 66,
          horizontalPadding: 22,
          verticalPadding: 12,
          leading: combinedLeading,
          actions: actions,
        ),
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  const _GlowDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}


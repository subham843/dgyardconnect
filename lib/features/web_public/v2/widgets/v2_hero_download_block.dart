import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../shared/models/hero_cta_app_link.dart';
import '../../core/brand/public_brand_navigation.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import 'v2_brand_icons.dart';
import 'v2_hero_pressable.dart';

/// Centered Android / iOS store badge row for hero CTA cluster.
class V2HeroDownloadBlock extends StatelessWidget {
  const V2HeroDownloadBlock({
    super.key,
    required this.links,
    this.trailing,
    this.animateDelay = Duration.zero,
    this.alignStart = false,
    this.flat = false,
    this.compact = false,
    this.fullWidthSingle = false,
  });

  final List<HeroCtaAppLink> links;
  final Widget? trailing;
  final Duration animateDelay;

  /// When true, badges align to the start (left) instead of center.
  final bool alignStart;

  /// When true, no shadows or glow hover effects (hero section).
  final bool flat;

  /// Tighter store badges when hero height is reduced.
  final bool compact;

  /// When true and only one badge, stretch to full container width.
  final bool fullWidthSingle;

  @override
  Widget build(BuildContext context) {
    final block = LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final count = links.length.clamp(1, 2);
        final badgeWidth = constraints.maxWidth.isFinite
            ? (fullWidthSingle && count == 1
                ? constraints.maxWidth
                : ((constraints.maxWidth - gap * (count - 1)) / count).clamp(120.0, 148.0))
            : 148.0;

        final wrapAlign = alignStart ? WrapAlignment.start : WrapAlignment.center;

        return SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: wrapAlign,
            runAlignment: wrapAlign,
            spacing: gap,
            runSpacing: gap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final link in links)
                _StoreBadgeTile(link: link, width: badgeWidth, flat: flat, compact: compact),
              ?trailing,
            ],
          ),
        );
      },
    );

    if (animateDelay == Duration.zero) return block;

    return block
        .animate(delay: animateDelay)
        .fadeIn(duration: 450.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }
}

class _StoreBadgeTile extends StatelessWidget {
  const _StoreBadgeTile({
    required this.link,
    required this.width,
    this.flat = false,
    this.compact = false,
  });

  final HeroCtaAppLink link;
  final double width;
  final bool flat;
  final bool compact;

  double get _height => compact ? 44 : 52;

  @override
  Widget build(BuildContext context) {
    final canOpen = link.hasUrl;

    if (flat) {
      return MouseRegion(
        cursor: canOpen ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: canOpen ? () => navigateBrandUrl(context, link.url!) : null,
          child: Container(
            width: width,
            height: _height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(color: V2Colors.borderSubtle),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: _StoreBadgeImage(link: link),
            ),
          ),
        ),
      );
    }

    return V2HeroPressable(
      enabled: canOpen,
      glowColor: V2Colors.premiumOrange,
      borderRadius: BorderRadius.circular(14),
      hoverScale: 1.04,
      pressScale: 0.94,
      onTap: canOpen ? () => navigateBrandUrl(context, link.url!) : null,
      builder: (context, state) {
        final lift = state.pressed ? 3.0 : (state.hover && canOpen ? -3.0 : 0.0);

        return AnimatedContainer(
          duration: V2.dFast,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, lift, 0),
          width: width,
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.92),
            border: Border.all(
              color: state.hover && canOpen
                  ? V2Colors.premiumOrange.withValues(alpha: 0.75)
                  : V2Colors.borderSubtle,
              width: state.hover && canOpen ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: state.pressed && canOpen
                    ? V2Colors.premiumOrange.withValues(alpha: 0.1)
                    : (state.hover && canOpen
                        ? V2Colors.premiumOrange.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.06)),
                blurRadius: state.pressed ? 6 : (state.hover && canOpen ? 14 : 10),
                offset: Offset(0, state.pressed ? 2 : (state.hover && canOpen ? 7 : 4)),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: _StoreBadgeImage(link: link),
          ),
        );
      },
    );
  }
}

class _StoreBadgeImage extends StatelessWidget {
  const _StoreBadgeImage({required this.link});

  final HeroCtaAppLink link;

  @override
  Widget build(BuildContext context) {
    final iconUrl = link.iconUrl?.trim();
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return kIsWeb
          ? Image.network(
              iconUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : CachedNetworkImage(
              imageUrl: iconUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorWidget: (_, _, _) => _fallback(),
            );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            V2BrandIcons.storePlatformIcon(
              android: link.platform == HeroCtaAppPlatform.android,
            ),
            size: 20,
            color: V2Colors.premiumOrangeDeep,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              link.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: V2Colors.inkSaaS,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

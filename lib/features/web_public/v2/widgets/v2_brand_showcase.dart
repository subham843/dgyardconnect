import 'package:flutter/material.dart';

import '../../../shop/domain/brand_logo_layout.dart';
import '../../../../shared/widgets/brand_logo_canvas.dart';
import '../../data/models/public_brand.dart';
import '../v2_colors.dart';
import '../v2_text.dart';
import '../v2_tokens.dart';

/// Brand logo grid or horizontal scroll strip for store landing.
class V2BrandShowcase extends StatelessWidget {
  const V2BrandShowcase({
    super.key,
    required this.brands,
    this.title = 'Trusted Brands',
    this.subtitle = 'We partner with industry-leading brands',
    this.canvasPreset = BrandLogoCanvasPreset.homepageDesktop,
    this.mobileCanvasPreset = BrandLogoCanvasPreset.homepageMobile,
    this.lightTheme = true,
    this.horizontalScroll = false,
  });

  final List<PublicBrand> brands;
  final String title;
  final String subtitle;
  final Size canvasPreset;
  final Size mobileCanvasPreset;
  final bool lightTheme;
  /// When true, brands scroll horizontally instead of wrapping (better on mobile).
  final bool horizontalScroll;

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();

    final v = V2Responsive(context);
    final isMobile = v.isMobile;
    final canvas = isMobile ? mobileCanvasPreset : canvasPreset;
    final titleColor = lightTheme ? V2Colors.ink : V2Colors.fgInverse;
    final subtitleColor =
        lightTheme ? V2Colors.fgMuted : V2Colors.fgInverse.withValues(alpha: 0.8);
    final titleStyle = isMobile
        ? V2Text.h3(context).copyWith(color: titleColor, fontWeight: FontWeight.w800)
        : V2Text.h2(context).copyWith(color: titleColor);
    final subtitleStyle = isMobile
        ? V2Text.body().copyWith(color: subtitleColor)
        : V2Text.bodyLg(context).copyWith(color: subtitleColor);

    return Column(
      crossAxisAlignment:
          horizontalScroll ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalScroll ? 0 : V2.s4),
          child: Column(
            crossAxisAlignment:
                horizontalScroll ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: horizontalScroll ? TextAlign.start : TextAlign.center,
                style: titleStyle,
              ),
              const SizedBox(height: V2.s2),
              Text(
                subtitle,
                textAlign: horizontalScroll ? TextAlign.start : TextAlign.center,
                style: subtitleStyle,
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? V2.s6 : V2.s12),
        if (horizontalScroll)
          _BrandScrollRow(brands: brands, canvas: canvas, isMobile: isMobile)
        else
          Wrap(
            spacing: V2.s6,
            runSpacing: V2.s6,
            alignment: WrapAlignment.center,
            children:
                brands.map((b) => _BrandCard(brand: b, canvas: canvas)).toList(),
          ),
      ],
    );
  }
}

class _BrandScrollRow extends StatelessWidget {
  const _BrandScrollRow({
    required this.brands,
    required this.canvas,
    required this.isMobile,
  });

  final List<PublicBrand> brands;
  final Size canvas;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final cardWidth = v.r(xs: 96.0, sm: 108.0, md: 128.0);
    final rowHeight = v.r(xs: 108.0, sm: 116.0, md: 132.0);

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: v.r(xs: 2.0, md: 0.0)),
        itemCount: brands.length,
        separatorBuilder: (_, _) => SizedBox(width: v.r(xs: 8.0, md: 12.0)),
        itemBuilder: (context, i) => SizedBox(
          width: cardWidth,
          child: _BrandCard(
            brand: brands[i],
            canvas: canvas,
            compact: true,
          ),
        ),
      ),
    );
  }
}

class _BrandCard extends StatefulWidget {
  const _BrandCard({
    required this.brand,
    required this.canvas,
    this.compact = false,
  });

  final PublicBrand brand;
  final Size canvas;
  final bool compact;

  @override
  State<_BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<_BrandCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final cardWidth = widget.compact
        ? null
        : v.r<double>(xs: 140, md: 160, lg: 180);
    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
        : const EdgeInsets.all(V2.s4);
    final radius = widget.compact ? V2.rLg : V2.rXl;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: cardWidth,
        padding: padding,
        decoration: BoxDecoration(
          color: V2Colors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: _hovered ? V2Colors.ember : V2Colors.border,
            width: _hovered ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.1 : 0.04),
              blurRadius: _hovered ? 16 : 8,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoCanvas(
              width: widget.canvas.width,
              height: widget.canvas.height,
              logoUrl: widget.brand.logoUrl,
              mimeType: widget.brand.logoMimeType,
              layout: widget.brand.logoLayout,
              fallbackLabel: widget.brand.name,
            ),
            SizedBox(height: widget.compact ? 6 : V2.s2),
            Text(
              widget.brand.name,
              textAlign: TextAlign.center,
              style: widget.compact
                  ? V2Text.micro().copyWith(
                      color: V2Colors.fgMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    )
                  : V2Text.smallStrong(color: V2Colors.fgMuted),
              maxLines: widget.compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!widget.compact &&
                widget.brand.shortDescription != null &&
                widget.brand.shortDescription!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.brand.shortDescription!,
                textAlign: TextAlign.center,
                style: V2Text.small(color: V2Colors.fgSubtle),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/shop/domain/brand_logo_layout.dart';

/// Displays a brand logo inside a fixed canvas using [BoxFit.contain] — never crops.
class BrandLogoCanvas extends StatelessWidget {
  const BrandLogoCanvas({
    super.key,
    required this.width,
    required this.height,
    this.logoUrl,
    this.mimeType,
    this.layout = const BrandLogoLayout(),
    this.altText,
    this.fallbackLabel,
    this.borderRadius = 8,
    this.border,
  });

  final double width;
  final double height;
  final String? logoUrl;
  final String? mimeType;
  final BrandLogoLayout layout;
  final String? altText;
  final String? fallbackLabel;
  final double borderRadius;
  final BoxBorder? border;

  bool get _isSvg =>
      (mimeType?.toLowerCase().contains('svg') ?? false) ||
      (logoUrl?.toLowerCase().endsWith('.svg') ?? false);

  @override
  Widget build(BuildContext context) {
    final bg = layout.backgroundColor;
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Transform.translate(
              offset: Offset(layout.offsetX, layout.offsetY),
              child: Transform.scale(
                scale: layout.scale,
                child: _isSvg
                    ? SvgPicture.network(
                        logoUrl!,
                        fit: BoxFit.contain,
                        width: width,
                        height: height,
                        placeholderBuilder: (_) => _fallback(context),
                      )
                    : CachedNetworkImage(
                        imageUrl: logoUrl!,
                        fit: BoxFit.contain,
                        width: width,
                        height: height,
                        errorWidget: (_, _, _) => _fallback(context),
                        placeholder: (_, _) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
              ),
            )
          : _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final label = fallbackLabel?.trim();
    if (label == null || label.isEmpty) {
      return Icon(Icons.branding_watermark_outlined, color: Theme.of(context).colorScheme.outline);
    }
    final initial = label.substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

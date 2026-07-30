import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/public_image_placements.dart';
import 'public_image_frame.dart';
import 'public_image_slots.dart';
import 'store_atoms.dart';

/// Renders an image with per-surface framing (homepage vs category banner, etc.).
class PlacedStoreImage extends StatelessWidget {
  const PlacedStoreImage({
    super.key,
    required this.slotId,
    required this.preset,
    this.fallbackUrl,
    this.sourceUrl,
    this.placements,
    this.sourceW,
    this.sourceH,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.backgroundColor,
    this.width,
    this.height,
  });

  final String slotId;
  final PublicStoreImagePreset preset;
  final String? fallbackUrl;
  final String? sourceUrl;
  final PublicImagePlacements? placements;
  final int? sourceW;
  final int? sourceH;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final double? width;
  final double? height;

  bool get _canCompose {
    final url = sourceUrl?.trim();
    final sw = sourceW;
    final sh = sourceH;
    return url != null &&
        url.isNotEmpty &&
        sw != null &&
        sh != null &&
        sw > 0 &&
        sh > 0 &&
        placements != null &&
        !placements!.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCompose) {
      return SizedBox(
        width: width,
        height: height,
        child: StoreImage(
          url: fallbackUrl,
          fit: fit,
          fallbackIcon: fallbackIcon,
          backgroundColor: backgroundColor,
        ),
      );
    }

    final slot = PublicImageDisplaySlots.find(preset, slotId);
    final layout = placements!.layoutFor(slotId);
    final outputW = preset.width;
    final outputH = preset.height;

    final previewLayout = PublicImageFrameMath.layoutForPreview(
      layout: layout,
      previewW: outputW.toDouble(),
      previewH: outputH.toDouble(),
      outputW: outputW,
      outputH: outputH,
    );
    final frame = PublicImageFrameMath.frame(
      sourceW: sourceW!,
      sourceH: sourceH!,
      canvasW: outputW.toDouble(),
      canvasH: outputH.toDouble(),
      layout: previewLayout,
    );

    Widget composed = DecoratedBox(
      decoration: BoxDecoration(
        color: layout.backgroundColor ?? const Color(0xFF0F172A),
      ),
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
          Positioned(
            left: frame.left,
            top: frame.top,
            width: frame.imageWidth,
            height: frame.imageHeight,
            child: CachedNetworkImage(
              imageUrl: sourceUrl!,
              fit: BoxFit.fill,
              fadeInDuration: const Duration(milliseconds: 300),
              memCacheWidth: frame.imageWidth.round().clamp(120, 1200),
            ),
          ),
          ],
        ),
      ),
    );

    final frameW = slot?.width ?? width ?? outputW.toDouble();
    final frameH = slot?.height ?? height ?? outputH.toDouble();

    return SizedBox(
      width: width ?? frameW,
      height: height ?? frameH,
      child: ClipRRect(
        child: FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: outputW.toDouble(),
            height: outputH.toDouble(),
            child: composed,
          ),
        ),
      ),
    );
  }
}
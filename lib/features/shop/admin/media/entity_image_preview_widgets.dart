import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

import '../../../../shared/widgets/brand_logo_canvas.dart';
import '../../data/shop_media_processor.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/entity_image_placements.dart';
import '../../domain/shop_image_display_slots.dart';
import '../../domain/shop_media_models.dart';

/// Live cover-fit preview — matches [ShopMediaProcessor] / [EntityImageFrameMath] output.
class EntityImageCoverPreview extends StatelessWidget {
  const EntityImageCoverPreview({
    super.key,
    required this.bytes,
    required this.sourceW,
    required this.sourceH,
    required this.width,
    required this.height,
    required this.outputW,
    required this.outputH,
    required this.layout,
  });

  final Uint8List bytes;
  final int sourceW;
  final int sourceH;
  final double width;
  final double height;
  final int outputW;
  final int outputH;
  final BrandLogoLayout layout;

  @override
  Widget build(BuildContext context) {
    final previewLayout = EntityImageFrameMath.layoutForPreview(
      layout: layout,
      previewW: width,
      previewH: height,
      outputW: outputW,
      outputH: outputH,
    );
    final frame = EntityImageFrameMath.frame(
      sourceW: sourceW,
      sourceH: sourceH,
      canvasW: width,
      canvasH: height,
      layout: previewLayout,
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: layout.backgroundColor ?? const Color(0xFF0F172A),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: frame.left,
            top: frame.top,
            width: frame.imageWidth,
            height: frame.imageHeight,
            child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
          ),
        ],
      ),
    );
  }
}

/// Shows how the composed image appears inside a real UI frame (may crop if aspect differs).
class EntityImageDisplaySlotPreview extends StatelessWidget {
  const EntityImageDisplaySlotPreview({
    super.key,
    required this.slot,
    required this.preset,
    this.sourceBytes,
    this.sourceW,
    this.sourceH,
    this.layout = const BrandLogoLayout(),
    this.composedBytes,
    this.imageUrl,
    this.highlighted = false,
  });

  final ShopImageDisplaySlot slot;
  final ShopImagePreset preset;
  final Uint8List? sourceBytes;
  final int? sourceW;
  final int? sourceH;
  final BrandLogoLayout layout;
  final Uint8List? composedBytes;
  final String? imageUrl;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outputW = preset.width;
    final outputH = preset.height;

    Widget inner;
    if (sourceBytes != null && sourceW != null && sourceH != null) {
      inner = EntityImageCoverPreview(
        bytes: sourceBytes!,
        sourceW: sourceW!,
        sourceH: sourceH!,
        width: outputW.toDouble(),
        height: outputH.toDouble(),
        outputW: outputW,
        outputH: outputH,
        layout: layout,
      );
    } else if (composedBytes != null && composedBytes!.isNotEmpty) {
      inner = Image.memory(composedBytes!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      inner = CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover);
    } else {
      inner = ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, color: theme.colorScheme.outline, size: 20),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(slot.label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: highlighted ? theme.colorScheme.primary : theme.dividerColor,
              width: highlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: slot.width,
              height: slot.height,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: outputW.toDouble(),
                  height: outputH.toDouble(),
                  child: inner,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal strip of contextual previews for admin fields.
class EntityImagePreviewStrip extends StatelessWidget {
  const EntityImagePreviewStrip({
    super.key,
    required this.preset,
    this.sourceBytes,
    this.sourceW,
    this.sourceH,
    this.layout = const BrandLogoLayout(),
    this.placements,
    this.composedBytes,
    this.imageUrl,
    this.highlightSlotId,
    this.title = 'Where this image appears',
  });

  final ShopImagePreset preset;
  final Uint8List? sourceBytes;
  final int? sourceW;
  final int? sourceH;
  final BrandLogoLayout layout;
  final EntityImagePlacements? placements;
  final Uint8List? composedBytes;
  final String? imageUrl;
  final String? highlightSlotId;
  final String title;

  bool get _hasContent =>
      (sourceBytes != null && sourceBytes!.isNotEmpty) ||
      (composedBytes != null && composedBytes!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    var sw = sourceW;
    var sh = sourceH;
    if (sourceBytes != null && (sw == null || sh == null)) {
      final decoded = img.decodeImage(sourceBytes!);
      sw = decoded?.width;
      sh = decoded?.height;
    }

    final slots = ShopImageDisplaySlots.forPreset(preset);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final slot in slots) ...[
                EntityImageDisplaySlotPreview(
                  slot: slot,
                  preset: preset,
                  sourceBytes: sourceBytes,
                  sourceW: sw,
                  sourceH: sh,
                  layout: placements?.layoutFor(slot.id, fallback: layout) ?? layout,
                  composedBytes: composedBytes,
                  imageUrl: imageUrl,
                  highlighted: highlightSlotId == slot.id,
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Brand logo previews — homepage, store featured, carousel, etc.
class BrandLogoPreviewStrip extends StatelessWidget {
  const BrandLogoPreviewStrip({
    super.key,
    required this.brandName,
    required this.layout,
    this.bytes,
    this.mimeType,
    this.logoUrl,
    this.title = 'Where this logo appears',
  });

  final String brandName;
  final BrandLogoLayout layout;
  final Uint8List? bytes;
  final String? mimeType;
  final String? logoUrl;
  final String title;

  bool get _hasLogo =>
      (bytes != null && bytes!.isNotEmpty) || (logoUrl != null && logoUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasLogo) return const SizedBox.shrink();

    final slots = ShopImageDisplaySlots.forPreset(ShopImagePreset.brandLogo);
    final isSvg = mimeType?.contains('svg') ?? logoUrl?.toLowerCase().endsWith('.svg') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final slot in slots) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(slot.label, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: bytes != null
                            ? _BrandLogoMemoryCanvas(
                                bytes: bytes!,
                                isSvg: isSvg,
                                width: slot.width,
                                height: slot.height,
                                layout: layout,
                                fallbackLabel: brandName,
                              )
                            : BrandLogoCanvas(
                                width: slot.width,
                                height: slot.height,
                                logoUrl: logoUrl,
                                mimeType: mimeType,
                                layout: layout,
                                fallbackLabel: brandName,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandLogoMemoryCanvas extends StatelessWidget {
  const _BrandLogoMemoryCanvas({
    required this.bytes,
    required this.isSvg,
    required this.width,
    required this.height,
    required this.layout,
    this.fallbackLabel,
  });

  final Uint8List bytes;
  final bool isSvg;
  final double width;
  final double height;
  final BrandLogoLayout layout;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: layout.backgroundColor),
      clipBehavior: Clip.antiAlias,
      child: Transform.translate(
        offset: Offset(layout.offsetX, layout.offsetY),
        child: Transform.scale(
          scale: layout.scale,
          child: isSvg
              ? SvgPicture.memory(bytes, fit: BoxFit.contain, width: width, height: height)
              : Image.memory(bytes, fit: BoxFit.contain, width: width, height: height),
        ),
      ),
    );
  }
}

// Product image with admin per-surface framing (matches entity image editor).

import 'package:flutter/material.dart';

import '../../../data/models/public_store_models.dart';
import 'placed_store_image.dart';
import 'public_image_slots.dart';

class StoreProductImage extends StatelessWidget {
  const StoreProductImage({
    super.key,
    required this.product,
    required this.slotId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.backgroundColor,
  });

  final PublicProduct product;
  final String slotId;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return PlacedStoreImage(
      slotId: slotId,
      preset: PublicStoreImagePreset.productMain,
      fallbackUrl: product.imageUrl ?? product.thumbnailUrl,
      sourceUrl: product.imageEditorSourceUrl,
      placements: product.imagePlacements,
      sourceW: product.imageSourceW,
      sourceH: product.imageSourceH,
      fit: fit,
      width: width,
      height: height,
      fallbackIcon: fallbackIcon,
      backgroundColor: backgroundColor,
    );
  }
}
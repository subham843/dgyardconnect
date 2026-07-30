// Premium product card — Apple/Samsung-grade hover interactions.

import 'package:flutter/material.dart';

import '../../../v2/v2_colors.dart';
import '../../../v2/v2_tokens.dart';
import '../../../v2/v2_text.dart';
import '../../../data/models/public_store_models.dart';
import 'store_atoms.dart';
import 'store_product_image.dart';

class StoreProductCard extends StatefulWidget {
  const StoreProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onQuickView,
    this.onWishlist,
    this.onCompare,
    this.isNew = false,
  });

  final PublicProduct product;
  final VoidCallback onTap;
  final VoidCallback? onQuickView;
  final VoidCallback? onWishlist;
  final VoidCallback? onCompare;
  final bool isNew;

  @override
  State<StoreProductCard> createState() => _StoreProductCardState();
}

class _StoreProductCardState extends State<StoreProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
          decoration: BoxDecoration(
            color: V2Colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hover
                  ? V2Colors.plasma.withValues(alpha: 0.2)
                  : V2Colors.surface,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.10 : 0.045),
                blurRadius: _hover ? 24 : 12,
                offset: Offset(0, _hover ? 12 : 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imageBlock(p),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((p.brandName ?? '').isNotEmpty)
                      Text(
                        p.brandName!.toUpperCase(),
                        style: V2Text.micro().copyWith(
                          color: V2Colors.fgSubtle,
                          letterSpacing: 0.8,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.bodyEmph().copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _priceRow(p),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: V2Colors.aurora,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'In stock',
                          style: V2Text.small().copyWith(
                            color: V2Colors.aurora,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageBlock(PublicProduct p) {
    return AspectRatio(
      aspectRatio: 1.12,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Zoom on hover.
            AnimatedScale(
              scale: _hover ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              child: StoreProductImage(
                product: p,
                slotId: 'store_grid',
                fit: BoxFit.cover,
                backgroundColor: const Color(0xFFF5F5F7),
              ),
            ),
            // Top badges.
            Positioned(
              top: V2.s2,
              left: V2.s2,
              child: Row(
                children: [
                  if (p.hasDiscount)
                    StorePill(
                      label: '-${p.discountPercent}%',
                      color: const Color(0xFFEF4444),
                    ),
                  if (widget.isNew) ...[
                    if (p.hasDiscount) const SizedBox(width: 6),
                    const StorePill(label: 'NEW', color: V2Colors.plasma),
                  ],
                ],
              ),
            ),
            // Hover action rail.
            Positioned(
              top: V2.s2,
              right: V2.s2,
              child: AnimatedOpacity(
                opacity: _hover ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    _circleAction(
                      Icons.favorite_border_rounded,
                      'Wishlist',
                      widget.onWishlist,
                    ),
                    const SizedBox(height: 8),
                    _circleAction(
                      Icons.compare_arrows_rounded,
                      'Compare',
                      widget.onCompare,
                    ),
                  ],
                ),
              ),
            ),
            // Quick view bar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _hover ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onTap: widget.onQuickView,
                  child: Container(
                    color: V2Colors.ink.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: V2Colors.surface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick view',
                          style: V2Text.smallStrong().copyWith(
                            color: V2Colors.surface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleAction(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: V2Colors.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: V2Colors.plasma),
          ),
        ),
      ),
    );
  }

  Widget _priceRow(PublicProduct p) {
    if (p.price == null) {
      return Text(
        'Request quote',
        style: V2Text.bodyEmph().copyWith(
          color: V2Colors.plasma,
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatINR(p.price),
          style: V2Text.bodyEmph().copyWith(
            color: V2Colors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (p.hasDiscount) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              formatINR(p.mrp),
              style: V2Text.small().copyWith(
                color: V2Colors.fgSubtle,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
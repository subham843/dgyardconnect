// Glass-morphism category cards with 3D hover depth.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';

import '../../../data/models/public_store_models.dart';
import '../../../v2/v2_colors.dart';
import '../../../v2/v2_text.dart';
import '../../../v2/v2_tokens.dart';
import 'store_atoms.dart';

class StoreCategoryStrip extends StatelessWidget {
  const StoreCategoryStrip({
    super.key,
    required this.categories,
    required this.onCategoryTap,
  });

  final List<PublicCategory> categories;
  final void Function(PublicCategory category) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final v = V2Responsive(context);
    final cardWidth = v.r(xs: 108.0, sm: 118.0, md: 132.0, lg: 148.0);
    final cardHeight = v.r(xs: 132.0, sm: 142.0, md: 156.0, lg: 168.0);

    return SizedBox(
      height: cardHeight + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          v.r(xs: 4.0, md: 0.0),
          6,
          v.r(xs: 4.0, md: 0.0),
          2,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: v.r(xs: 12.0, md: 16.0)),
        itemBuilder: (context, i) => _GlassCategoryCard(
          category: categories[i],
          width: cardWidth,
          height: cardHeight,
          isMobile: v.isMobile,
          onTap: () => onCategoryTap(categories[i]),
          index: i,
        ),
      ),
    );
  }
}

class _GlassCategoryCard extends StatefulWidget {
  const _GlassCategoryCard({
    required this.category,
    required this.width,
    required this.height,
    required this.isMobile,
    required this.onTap,
    required this.index,
  });

  final PublicCategory category;
  final double width;
  final double height;
  final bool isMobile;
  final VoidCallback onTap;
  final int index;

  @override
  State<_GlassCategoryCard> createState() => _GlassCategoryCardState();
}

class _GlassCategoryCardState extends State<_GlassCategoryCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final lifted = _hover || _pressed;
    final liftY = _pressed ? 2.0 : (_hover ? -10.0 : 0.0);
    final scale = _pressed ? 0.96 : (_hover ? 1.04 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..translateByDouble(0, liftY, 0, 1)
            ..rotateX(_hover ? -0.06 : 0.0)
            ..rotateY(_hover ? 0.05 : 0.0)
            ..scaleByDouble(scale, scale, scale, 1),
          transformAlignment: Alignment.center,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: V2Colors.plasma.withValues(alpha: lifted ? 0.22 : 0.08),
                  blurRadius: lifted ? 28 : 14,
                  offset: Offset(0, lifted ? 16 : 8),
                  spreadRadius: lifted ? -2 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: lifted ? 0.14 : 0.07),
                  blurRadius: lifted ? 20 : 10,
                  offset: Offset(0, lifted ? 12 : 5),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image (soft, fills card).
                  StoreImage(
                    url: c.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.category_outlined,
                    backgroundColor: const Color(0xFFE8ECF4),
                    memCacheWidth: 320,
                  ),
                  // Soft vignette for depth.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                  // Bottom scrim — keeps name readable on any image.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: widget.height * 0.55,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.82),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Category name — centered, bottom anchored.
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: widget.isMobile ? 10 : 12,
                    child: Text(
                      c.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.smallStrong(color: Colors.white).copyWith(
                        fontSize: widget.isMobile ? 11.5 : 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.28,
                        letterSpacing: 0.1,
                        shadows: const [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Product count — top-right glass pill.
                  if (c.productCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${c.productCount}',
                          style: V2Text.micro().copyWith(
                            color: V2Colors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  // Top glass shine.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: _hover ? 0.35 : 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Frosted edge ring.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: _hover ? 0.85 : 0.55),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (widget.index * 45).ms)
        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic);
  }
}
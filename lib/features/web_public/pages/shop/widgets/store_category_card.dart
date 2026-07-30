// Apple-style image category card with hover reveal + explore CTA.

import 'package:flutter/material.dart';

import '../../../v2/v2_colors.dart';
import '../../../v2/v2_tokens.dart';
import '../../../v2/v2_text.dart';
import '../../../data/models/public_store_models.dart';
import 'store_atoms.dart';

class StoreCategoryCard extends StatefulWidget {
  const StoreCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  final PublicCategory category;
  final VoidCallback onTap;

  @override
  State<StoreCategoryCard> createState() => _StoreCategoryCardState();
}

class _StoreCategoryCardState extends State<StoreCategoryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -8 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V2.r2xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.22 : 0.10),
                blurRadius: _hover ? 30 : 16,
                offset: Offset(0, _hover ? 16 : 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(V2.r2xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedScale(
                  scale: _hover ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: StoreImage(
                    url: c.imageUrl,
                    fallbackIcon: Icons.category_outlined,
                    backgroundColor: V2Colors.ink,
                  ),
                ),
                // Legibility gradient.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x110A0E27),
                        Color(0x660A0E27),
                        Color(0xE60A0E27),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(V2.s6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (c.productCount > 0)
                        StorePill(
                          label: '${c.productCount} products',
                          color: V2Colors.surface.withValues(alpha: 0.18),
                        ),
                      const SizedBox(height: V2.s2),
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.h3(context).copyWith(
                          color: V2Colors.surface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.safeDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.small().copyWith(
                          color: V2Colors.surface.withValues(alpha: 0.8),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: SizedBox(height: _hover ? V2.s4 : 0),
                      ),
                      AnimatedOpacity(
                        opacity: _hover ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Row(
                          children: [
                            Text(
                              'Explore',
                              style: V2Text.smallStrong().copyWith(
                                color: V2Colors.ember,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 16, color: V2Colors.ember),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
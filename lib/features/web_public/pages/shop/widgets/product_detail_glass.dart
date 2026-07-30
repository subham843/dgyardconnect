// Apple Store–inspired glass UI atoms for the product detail page.

import 'package:flutter/material.dart';

import '../../../v2/v2_colors.dart';
import '../../../v2/v2_glass.dart';
import '../../../v2/v2_text.dart';
import '../../../v2/v2_tokens.dart';

/// Soft ambient mesh behind the product hero (Apple-style depth).
class ProductDetailAmbientBg extends StatelessWidget {
  const ProductDetailAmbientBg({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _orb(320, V2Colors.plasma.withValues(alpha: 0.14)),
          ),
          Positioned(
            top: 180,
            left: -100,
            child: _orb(280, V2Colors.ember.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: 120,
            right: 40,
            child: _orb(220, V2Colors.aurora.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Frosted glass panel — web-safe semi-transparent fallback.
class ProductGlassPanel extends StatelessWidget {
  const ProductGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 24,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: v2BackdropGlass(
        blurSigma: 22,
        backgroundColor: Colors.white.withValues(alpha: highlight ? 0.82 : 0.68),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: V2Colors.plasma.withValues(alpha: 0.04),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
        ],
        child: Padding(
          padding: padding ?? const EdgeInsets.all(V2.s8),
          child: child,
        ),
      ),
    );
  }
}

/// Pill chip for stock, warranty, brand tags.
class ProductMetaChip extends StatelessWidget {
  const ProductMetaChip({
    super.key,
    required this.label,
    this.icon,
    this.color = V2Colors.aurora,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: V2Text.micro().copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Apple-style primary / secondary action buttons.
class ProductActionButtons extends StatelessWidget {
  const ProductActionButtons({
    super.key,
    required this.onBuyNow,
    required this.onAddToCart,
    this.compact = false,
  });

  final VoidCallback onBuyNow;
  final VoidCallback onAddToCart;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vPad = compact ? 14.0 : 18.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryBuyButton(onPressed: onBuyNow, verticalPadding: vPad),
        SizedBox(height: compact ? 10 : 12),
        _GlassSecondaryButton(
          onPressed: onAddToCart,
          label: 'Add to Bag',
          icon: Icons.shopping_bag_outlined,
          verticalPadding: vPad,
        ),
      ],
    );
  }
}

class _PrimaryBuyButton extends StatefulWidget {
  const _PrimaryBuyButton({
    required this.onPressed,
    required this.verticalPadding,
  });

  final VoidCallback onPressed;
  final double verticalPadding;

  @override
  State<_PrimaryBuyButton> createState() => _PrimaryBuyButtonState();
}

class _PrimaryBuyButtonState extends State<_PrimaryBuyButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _hover
                    ? [const Color(0xFF1A1A22), V2Colors.ink]
                    : [V2Colors.ink, const Color(0xFF1A1A22)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: V2Colors.ink.withValues(alpha: _hover ? 0.35 : 0.22),
                  blurRadius: _hover ? 24 : 16,
                  offset: Offset(0, _hover ? 10 : 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Buy Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
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

class _GlassSecondaryButton extends StatefulWidget {
  const _GlassSecondaryButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.verticalPadding,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final double verticalPadding;

  @override
  State<_GlassSecondaryButton> createState() => _GlassSecondaryButtonState();
}

class _GlassSecondaryButtonState extends State<_GlassSecondaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? V2Colors.ink.withValues(alpha: 0.25) : V2Colors.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: V2Colors.ink, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: V2Text.bodyEmph().copyWith(
                  color: V2Colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky glass buy bar for mobile.
class ProductStickyBuyBar extends StatelessWidget {
  const ProductStickyBuyBar({
    super.key,
    required this.productName,
    required this.priceLabel,
    required this.onBuyNow,
    required this.onAddToCart,
  });

  final String productName;
  final String priceLabel;
  final VoidCallback onBuyNow;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: const Color(0xF2FFFFFF),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2Text.smallStrong().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      priceLabel,
                      style: V2Text.bodyEmph().copyWith(
                        color: V2Colors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onAddToCart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: V2Colors.ink,
                  side: BorderSide(color: V2Colors.ink.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cart'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onBuyNow,
                style: FilledButton.styleFrom(
                  backgroundColor: V2Colors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Buy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

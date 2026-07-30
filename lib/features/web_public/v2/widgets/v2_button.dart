// V2 Button — Stripe-style premium button with magnetic hover.
//
// Variants:
//   - primary  : solid brand, white text — primary conversion CTA
//   - secondary: solid near-black, white text — sober alt CTA
//   - outline  : transparent w/ border — tertiary action
//   - ghost    : transparent, no border — link-like
//   - onDark   : white surface on dark backgrounds

import 'package:flutter/material.dart';

import '../v2_colors.dart';
import '../v2_text.dart';
import '../v2_tokens.dart';

enum V2BtnVariant { primary, secondary, outline, ghost, onDark }

enum V2BtnSize { sm, md, lg }

class V2Button extends StatefulWidget {
  const V2Button({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = V2BtnVariant.primary,
    this.size = V2BtnSize.md,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final V2BtnVariant variant;
  final V2BtnSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final bool loading;

  @override
  State<V2Button> createState() => _V2ButtonState();
}

class _V2ButtonState extends State<V2Button> {
  bool _hover = false;
  bool _pressed = false;

  EdgeInsets get _padding {
    switch (widget.size) {
      case V2BtnSize.sm:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 9);
      case V2BtnSize.md:
        return const EdgeInsets.symmetric(horizontal: 18, vertical: 12);
      case V2BtnSize.lg:
        return const EdgeInsets.symmetric(horizontal: 22, vertical: 15);
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case V2BtnSize.sm:
        return 13;
      case V2BtnSize.md:
        return 14.5;
      case V2BtnSize.lg:
        return 16;
    }
  }

  double get _radius {
    switch (widget.size) {
      case V2BtnSize.sm:
        return V2.rMd;
      case V2BtnSize.md:
        return V2.rMd;
      case V2BtnSize.lg:
        return V2.rLg;
    }
  }

  Color _bg() {
    switch (widget.variant) {
      case V2BtnVariant.primary:
        if (_pressed) return V2Colors.brandPressed;
        if (_hover) return V2Colors.brandHover;
        return V2Colors.brand;
      case V2BtnVariant.secondary:
        if (_pressed) return const Color(0xFF000000);
        if (_hover) return const Color(0xFF1F1F1F);
        return V2Colors.fg;
      case V2BtnVariant.outline:
        if (_hover) return V2Colors.bgAlt;
        return Colors.transparent;
      case V2BtnVariant.ghost:
        if (_hover) return V2Colors.bgAlt;
        return Colors.transparent;
      case V2BtnVariant.onDark:
        if (_hover) return const Color(0xFFEAEAEA);
        return V2Colors.fgInverse;
    }
  }

  Color _fg() {
    switch (widget.variant) {
      case V2BtnVariant.primary:
      case V2BtnVariant.secondary:
        return V2Colors.fgInverse;
      case V2BtnVariant.outline:
      case V2BtnVariant.ghost:
        return V2Colors.fg;
      case V2BtnVariant.onDark:
        return V2Colors.fg;
    }
  }

  Border? _border() {
    switch (widget.variant) {
      case V2BtnVariant.outline:
        return Border.all(
          color: _hover ? V2Colors.borderStrong : V2Colors.border,
          width: 1,
        );
      default:
        return null;
    }
  }

  List<BoxShadow> _shadow() {
    if (widget.onPressed == null) return const [];
    switch (widget.variant) {
      case V2BtnVariant.primary:
        return _hover ? V2Colors.shadowBrand(alpha: 0.28) : V2Colors.shadowBrand(alpha: 0.16);
      case V2BtnVariant.secondary:
        return _hover ? V2Colors.shadowMd : V2Colors.shadowSm;
      case V2BtnVariant.onDark:
        return _hover ? V2Colors.shadowMd : V2Colors.shadowSm;
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.loading;
    final fg = isDisabled ? V2Colors.fgFaint : _fg();

    Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: _fontSize,
            height: _fontSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: _fontSize + 2, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: V2Text.btn(size: _fontSize, color: fg),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (widget.trailingIcon != null && !widget.loading) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: _fontSize + 2, color: fg),
        ],
      ],
    );

    return MouseRegion(
      cursor: isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          onTap: isDisabled ? null : widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1,
            duration: V2.dFast,
            child: AnimatedContainer(
              duration: V2.d,
              curve: V2.eOut,
              padding: _padding,
              constraints: const BoxConstraints(minHeight: 38),
              decoration: BoxDecoration(
                color: isDisabled
                    ? V2Colors.bgSubtle
                    : widget.variant == V2BtnVariant.primary
                        ? null
                        : _bg(),
                gradient: !isDisabled && widget.variant == V2BtnVariant.primary
                    ? V2Colors.emberGradient
                    : null,
                borderRadius: BorderRadius.circular(_radius),
                border: _border(),
                boxShadow: _shadow(),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

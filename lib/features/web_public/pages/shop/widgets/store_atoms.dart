// Shared premium atoms for the Store experience.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../v2/v2_colors.dart';
import '../../../v2/v2_tokens.dart';
import '../../../v2/v2_text.dart';

/// Indian-rupee formatting with thousands separators (₹1,23,456).
String formatINR(double? amount) {
  if (amount == null) return '';
  final whole = amount.round();
  final s = whole.abs().toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final buf = StringBuffer();
  while (rest.length > 2) {
    buf.write(',${rest.substring(rest.length - 2)}');
    rest = rest.substring(0, rest.length - 2);
  }
  final grouped = '$rest$buf';
  return '₹$grouped,$last3';
}

/// Network image with graceful, on-brand fallback (no broken-image glyphs).
class StoreImage extends StatelessWidget {
  const StoreImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.backgroundColor,
    this.memCacheWidth = 480,
  });

  final String? url;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? V2Colors.bgSubtle;
    if (url == null || url!.trim().isEmpty) {
      return _fallback(bg);
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 350),
      placeholder: (_, _) => Container(
        color: bg,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, _, _) => _fallback(bg),
    );
  }

  Widget _fallback(Color bg) {
    return Container(
      color: bg,
      child: Center(
        child: Icon(fallbackIcon, size: 44, color: V2Colors.fgFaint),
      ),
    );
  }
}

/// Section heading with an optional "view all" affordance.
class StoreSectionHeader extends StatelessWidget {
  const StoreSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.light = false,
    this.center = false,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool light;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final titleColor = light ? V2Colors.surface : V2Colors.ink;
    final subColor =
        light ? V2Colors.surface.withValues(alpha: 0.75) : V2Colors.fgMuted;

    final texts = Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: V2Text.h3(context).copyWith(color: titleColor),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: V2.s1),
          Text(
            subtitle!,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: V2Text.body().copyWith(color: subColor),
          ),
        ],
      ],
    );

    if (center || actionLabel == null) return texts;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: texts),
        const SizedBox(width: V2.s4),
        _ViewAll(label: actionLabel!, onTap: onAction),
      ],
    );
  }
}

class _ViewAll extends StatefulWidget {
  const _ViewAll({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<_ViewAll> createState() => _ViewAllState();
}

class _ViewAllState extends State<_ViewAll> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: V2Text.smallStrong().copyWith(
                color: V2Colors.ember,
                fontWeight: FontWeight.w600,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: _hover ? 8 : 4),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 16, color: V2Colors.ember),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill badge (discount, NEW, offer type, stock).
class StorePill extends StatelessWidget {
  const StorePill({
    super.key,
    required this.label,
    this.color = V2Colors.ember,
    this.textColor = V2Colors.surface,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        border: outlined ? Border.all(color: color, width: 1.2) : null,
        borderRadius: BorderRadius.circular(V2.rFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: outlined ? color : textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: V2Text.micro().copyWith(
              color: outlined ? color : textColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
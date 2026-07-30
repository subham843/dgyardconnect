import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Profile avatar in squircle (superellipse) shape with white glow border.
/// Use for profile pics on home screen, profile, edit profile, etc.
class SquircleAvatar extends StatelessWidget {
  const SquircleAvatar({
    super.key,
    this.photoUrl,
    required this.size,
    this.backgroundColor,
    this.fallback,
    this.fallbackText,
    this.fallbackTextColor,
    this.glowColor = Colors.white,
    this.glowBlur = 12,
    this.glowSpread = 2,
  });

  final String? photoUrl;
  final double size;
  final Color? backgroundColor;
  final Widget? fallback;
  /// First letter or initial when no photo (e.g. 'T', 'D')
  final String? fallbackText;
  /// Color for fallback text when using fallbackText
  final Color? fallbackTextColor;
  final Color glowColor;
  final double glowBlur;
  final double glowSpread;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final cornerRadius = radius * 0.42;

    final bg = backgroundColor ?? Colors.grey.shade300;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    final content = ClipPath(
      clipper: ShapeBorderClipper(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: bg, child: _buildFallback(size)),
                errorWidget: (context, url, stackTrace) => Container(color: bg, child: _buildFallback(size)),
              )
            : Container(
                color: bg,
                child: fallback ?? _buildFallback(size),
              ),
      ),
    );

    final hasGlow = glowBlur > 0 || glowSpread > 0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.9),
                  blurRadius: glowBlur,
                  spreadRadius: glowSpread,
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.5),
                  blurRadius: glowBlur * 2,
                  spreadRadius: glowSpread * 0.5,
                ),
              ]
            : null,
      ),
      child: content,
    );
  }

  Widget _buildFallback(double s) {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Center(
        child: Text(
          fallbackText![0].toUpperCase(),
          style: TextStyle(
            fontSize: s * 0.5,
            fontWeight: FontWeight.w700,
            color: fallbackTextColor ?? Colors.grey.shade600,
          ),
        ),
      );
    }
    return Center(
      child: Icon(Icons.person_rounded, size: s * 0.5, color: Colors.grey),
    );
  }
}

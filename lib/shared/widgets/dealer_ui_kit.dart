import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dealer_ui_tokens.dart';
import 'glass_ui_kit.dart';

/// Premium floating card with squircle corners, soft shadow, tap elevation.
class DealerFloatingCard extends StatefulWidget {
  const DealerFloatingCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.gradientBorder,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double borderRadius;
  final List<Color>? gradientBorder;

  @override
  State<DealerFloatingCard> createState() => _DealerFloatingCardState();
}

class _DealerFloatingCardState extends State<DealerFloatingCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.borderRadius;
    final card = AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: GlassCard(
          borderRadius: r,
          blurSigma: DealerUiTokens.glassCardBlurSigma,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: card,
    );
  }
}

/// Morphing button with ripple, loading state, gradient.
class DealerMorphingButton extends StatefulWidget {
  const DealerMorphingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final List<Color>? gradient;
  final double? width;

  @override
  State<DealerMorphingButton> createState() => _DealerMorphingButtonState();
}

class _DealerMorphingButtonState extends State<DealerMorphingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.gradient ?? [AppColors.primary, AppColors.primaryDark];
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed != null && !widget.isLoading
              ? widget.onPressed
              : null,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.3),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width ?? double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon!, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

/// Minimal app bar with back, center title, smooth slide.
class DealerMinimalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DealerMinimalAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.backgroundColor,
    this.gradient,
    this.foregroundColor,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? foregroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? const Color(0xFF1E293B);
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.transparent,
      foregroundColor: fg,
      elevation: 0,
      flexibleSpace: gradient != null
          ? Container(decoration: BoxDecoration(gradient: gradient))
          : null,
      leading: onBack != null
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: fg),
              onPressed: onBack,
            )
          : null,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
      centerTitle: true,
      actions: actions,
    );
  }
}

/// Squircle avatar with gradient border for dealer panel.
class DealerSquircleAvatar extends StatelessWidget {
  const DealerSquircleAvatar({
    super.key,
    this.photoUrl,
    required this.size,
    this.fallbackText,
    this.fallbackTextColor,
  });

  final String? photoUrl;
  final double size;
  final String? fallbackText;
  final Color? fallbackTextColor;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final cornerRadius = radius * 0.42;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.6),
            AppColors.secondary.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius - 2),
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Center(
                    child: Text(
                      (fallbackText ?? 'D').substring(0, 1).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: size * 0.45,
                        fontWeight: FontWeight.w700,
                        color: fallbackTextColor ?? AppColors.primary,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Center(
                    child: Text(
                      (fallbackText ?? 'D').substring(0, 1).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: size * 0.45,
                        fontWeight: FontWeight.w700,
                        color: fallbackTextColor ?? AppColors.primary,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                color: AppColors.primary.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Text(
                  (fallbackText ?? 'D').substring(0, 1).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: size * 0.45,
                    fontWeight: FontWeight.w700,
                    color: fallbackTextColor ?? AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Dashboard card item for dealer home.
/// [compact] true = grid cell layout (icon top, title below).
class DealerDashboardCard extends StatelessWidget {
  const DealerDashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.enabled = true,
    this.index = 0,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = DealerFloatingCard(
      onTap: enabled ? onTap : null,
      padding: compact ? const EdgeInsets.all(14) : const EdgeInsets.all(20),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: color),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 26, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: color.withValues(alpha: 0.6),
                    size: 24,
                  ),
                ],
              ),
      ),
    );
    return card
        .animate()
        .fadeIn(delay: Duration(milliseconds: 40 * index))
        .slideY(
          begin: 0.04,
          end: 0,
          delay: Duration(milliseconds: 40 * index),
          curve: Curves.easeOutCubic,
        );
  }
}

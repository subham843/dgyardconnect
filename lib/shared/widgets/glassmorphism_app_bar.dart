import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Glassmorphism blur AppBar – frosted glass effect, floating style.
/// Custom height, typography, and colors.
class GlassmorphismAppBar extends StatelessWidget {
  const GlassmorphismAppBar({
    super.key,
    required this.leading,
    required this.actions,
    this.height = 60,
    this.horizontalPadding = 20,
    this.verticalPadding = 12,
    this.borderRadius = 28,
    this.blurSigma = 24,
  });

  final Widget leading;
  final List<Widget> actions;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: double.infinity,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: leading),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Leading content for glass app bar: avatar + greeting.
class GlassAppBarLeading extends StatelessWidget {
  const GlassAppBarLeading({
    super.key,
    this.photoUrl,
    required this.fullName,
    required this.greeting,
  });

  final String? photoUrl;
  final String fullName;
  final String greeting;

  static const _textColor = Color(0xFF1E293B);
  static const _textColorMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? Image.network(photoUrl!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Text(
                      fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : 'T',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                greeting,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                fullName.trim().isEmpty ? 'Technician' : fullName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _textColorMuted,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Online/Offline/Busy chip for glass app bar. When [isBusy] is true, tapping shows a message and does not call [onTap].
class GlassAppBarOnlineChip extends StatelessWidget {
  const GlassAppBarOnlineChip({
    super.key,
    required this.isOnline,
    required this.approved,
    required this.onTap,
    this.isBusy = false,
  });

  final bool isOnline;
  final bool approved;
  final VoidCallback onTap;
  final bool isBusy;

  static const _busyMessage =
      'You are currently assigned to an active job. Complete the job to become available.';

  void _handleTap(BuildContext context) {
    if (!approved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile is under review. You will receive a notification when approved, then you can go online.',
          ),
        ),
      );
      return;
    }
    if (isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_busyMessage)),
      );
      return;
    }
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final busyState = isBusy;
    final label = busyState ? 'Busy' : (isOnline ? 'Online' : 'Offline');
    final color = busyState
        ? Colors.amber
        : (isOnline ? AppColors.success : const Color(0xFF64748B));

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: busyState
              ? Colors.amber.withValues(alpha: 0.2)
              : (isOnline ? AppColors.success.withValues(alpha: 0.2) : const Color(0xFF64748B).withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: busyState
                ? Colors.amber.withValues(alpha: 0.5)
                : (isOnline ? AppColors.success.withValues(alpha: 0.5) : const Color(0xFF64748B).withValues(alpha: 0.3)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

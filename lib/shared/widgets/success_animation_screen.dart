import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// Type of success to display.
enum SuccessType {
  detailsSaved,
  loginSuccess,
  registerSuccess,
}

/// Full-screen success animation with animated checkmark and auto-navigation.
class SuccessAnimationScreen extends StatefulWidget {
  const SuccessAnimationScreen({
    super.key,
    required this.successType,
    required this.nextRoute,
    this.extra,
  });

  final SuccessType successType;
  final String nextRoute;
  final Object? extra;

  @override
  State<SuccessAnimationScreen> createState() => _SuccessAnimationScreenState();
}

class _SuccessAnimationScreenState extends State<SuccessAnimationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (widget.extra != null) {
        context.go(widget.nextRoute, extra: widget.extra);
      } else {
        context.go(widget.nextRoute);
      }
    });
  }

  String get _title {
    switch (widget.successType) {
      case SuccessType.detailsSaved:
        return 'Details Saved!';
      case SuccessType.loginSuccess:
        return 'Login Success!';
      case SuccessType.registerSuccess:
        return 'Registration Success!';
    }
  }

  String get _subtitle {
    switch (widget.successType) {
      case SuccessType.detailsSaved:
        return 'Your service area has been set.';
      case SuccessType.loginSuccess:
        return 'Welcome back!';
      case SuccessType.registerSuccess:
        return 'Your account has been created.';
    }
  }

  static const _bgLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgLight,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAnimation(),
                const SizedBox(height: 32),
                Text(
                  _title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_circle_rounded,
          size: 120,
          color: AppColors.primary,
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(1, 1),
            duration: 600.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 400.ms),
    );
  }
}

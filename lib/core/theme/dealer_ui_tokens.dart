import 'package:flutter/material.dart';

class DealerUiTokens {
  DealerUiTokens._();

  // Surfaces
  static const Color pageBg = Color(0xFFF5F5F7);
  static const Color cardBg = Colors.white;
  static const Color softTint = Color(0xFFF8FAFF);

  // Borders
  static const Color border = Color(0xFFE5E7EB);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // Radius scale
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 20;
  static const double rXl = 22;

  // Typography scale for dealer flow
  static const double titleNav = 17;
  static const double titleSection = 19;
  static const double label = 12.5;

  /// Frosted cards / panels (Control Center–style blur). Range 15–25.
  static const double glassCardBlurSigma = 20.0;

  /// Floating bottom bar — slightly stronger blur. Range 20–30.
  static const double glassNavBlurSigma = 26.0;

  /// Alias for legacy call sites — matches [glassCardBlurSigma].
  static const double glassBackdropBlurSigma = glassCardBlurSigma;

  /// Soft depth under glass + faint top rim so panels read lifted.
  static final List<BoxShadow> glassDepthShadows = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.052),
      blurRadius: 22,
      spreadRadius: 0,
      offset: const Offset(0, 11),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.32),
      blurRadius: 1,
      spreadRadius: 0,
      offset: const Offset(0, -0.5),
    ),
  ];

  /// Legacy rim glow — prefer [glassDepthShadows] for new glass UI.
  static final List<BoxShadow> glassRimShadows = glassDepthShadows;
}

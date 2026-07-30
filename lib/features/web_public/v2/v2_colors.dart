// V2 Aurora — premium tech-firm color system.
//
// Philosophy:
//   - Cream "paper" background (warmer than pure white — magazine feel)
//   - Rich graphite "ink" for text (not pure black — softer Apple feel)
//   - Brand "ember" (saffron, slightly more electric) for primary actions
//   - "Plasma" violet for tech accents (Stripe-style highlights)
//   - "Aurora" mint for fresh status / success
//   - All borders are warm-toned to match the cream background.

import 'package:flutter/material.dart';

class V2Colors {
  V2Colors._();

  // --- Foreground (text + iconography) ---
  static const Color ink = Color(0xFF0A0A0F); // rich graphite (not pure black)
  static const Color inkSoft = Color(0xFF1A1A22);
  static const Color fg = ink; // alias for back-compat
  static const Color fgMuted = Color(0xFF555560);
  static const Color fgSubtle = Color(0xFF8B8B95);
  static const Color fgFaint = Color(0xFFB6B6BD);
  static const Color fgInverse = Color(0xFFFAFAF6);

  // --- Paper / Backgrounds (warm, magazine-style) ---
  static const Color paper = Color(0xFFFAFAF6); // cream paper
  static const Color paperWarm = Color(0xFFF5F4EE); // slightly warmer surface
  static const Color paperMist = Color(0xFFEFEEE7); // soft tinted surface
  static const Color bg = paper;
  static const Color bgAlt = paperWarm;
  static const Color bgSubtle = paperMist;
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color bgDarkAlt = Color(0xFF12121A);

  // --- Surfaces (cards) ---
  static const Color surface = Color(0xFFFFFFFF); // pure white card for crispness
  static const Color surfaceWarm = Color(0xFFFCFCF8);
  static const Color surfaceHover = Color(0xFFF8F7F1);
  static const Color surfaceMuted = paperMist;

  // --- Borders / Hairlines (warm-toned) ---
  static const Color hairline = Color(0xFFE6E4DC);
  static const Color border = hairline;
  static const Color borderStrong = Color(0xFFD0CEC4);
  static const Color borderSubtle = Color(0xFFEEEAE0);

  // --- Brand: Ember (refined saffron) ---
  static const Color ember = Color(0xFFFF5E1B); // signature ember
  static const Color emberSoft = Color(0xFFFF7A3D);
  static const Color emberDeep = Color(0xFFD94100);
  static const Color emberHover = emberDeep;
  static const Color emberPressed = Color(0xFFB23500);
  static const Color emberSubtle = Color(0xFFFFEDE2);
  static const Color emberSubtleStrong = Color(0xFFFFD5BD);

  // Brand back-compat aliases (referenced by older callers within v2)
  static const Color brand = ember;
  static const Color brandHover = emberHover;
  static const Color brandPressed = emberPressed;
  static const Color brandSubtle = emberSubtle;
  static const Color brandSubtleStrong = emberSubtleStrong;

  // --- Plasma: violet tech accent (Stripe-style highlights) ---
  static const Color plasma = Color(0xFF635BFF);
  static const Color plasmaSoft = Color(0xFF8A82FF);
  static const Color plasmaSubtle = Color(0xFFECECFF);

  // --- Aurora: mint tech accent (status, "live" badges) ---
  static const Color aurora = Color(0xFF00C896);
  static const Color auroraSoft = Color(0xFF34D9AD);
  static const Color auroraSubtle = Color(0xFFE3F8F1);

  // --- Corporate web (minimalist nav + hero) ---
  static const Color navy = Color(0xFF0B192C);
  static const Color orangeVibrant = Color(0xFFFF6B00);
  static const Color orangeOutline = Color(0xFFC45A00);
  static const Color pageGray = Color(0xFFF4F5F7);

  // --- Premium SaaS (Apple / Stripe / Linear) ---
  static const Color premiumOrange = Color(0xFFF59E0B);
  static const Color premiumOrangeDeep = Color(0xFFD97706);
  static const Color saasBg = Color(0xFFF7F8FA);
  static const Color paperWhite = Color(0xFFFFFFFF);
  static const Color paperMuted = Color(0xFFF1F3F6);
  static const Color inkSaaS = Color(0xFF0F172A);
  static const Color inkMutedSaaS = Color(0xFF64748B);

  /// Layered paper elevation — soft 3D extrusion.
  static List<BoxShadow> get paperLow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get paperFoldShadows => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(-6, 10),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(6, 10),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get paperFloatBottom => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.10),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: premiumOrange.withValues(alpha: 0.05),
          blurRadius: 48,
          offset: const Offset(0, 24),
          spreadRadius: -8,
        ),
      ];

  static List<BoxShadow> get paperMid => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: premiumOrange.withValues(alpha: 0.04),
          blurRadius: 40,
          offset: const Offset(0, 20),
          spreadRadius: -12,
        ),
      ];

  static List<BoxShadow> get paperHigh => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.10),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: premiumOrange.withValues(alpha: 0.06),
          blurRadius: 56,
          offset: const Offset(0, 28),
          spreadRadius: -16,
        ),
      ];

  static List<BoxShadow> paperLift({double dy = 6}) => [
        ...paperMid,
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.12),
          blurRadius: 32,
          offset: Offset(0, dy),
        ),
      ];

  // --- Legacy blue back-compat (kept for callers, but de-emphasised) ---
  static const Color blue = plasma;
  static const Color blueHover = plasmaSoft;
  static const Color blueSubtle = plasmaSubtle;

  // --- Semantic ---
  static const Color success = aurora;
  static const Color successSubtle = auroraSubtle;
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = plasma;

  // --- Shadows (warmer, softer than pure black) ---
  static const Color shadowColor = Color(0x14000000);

  static List<BoxShadow> get shadowXs => const [
        BoxShadow(color: Color(0x0A0A0A0F), blurRadius: 1, offset: Offset(0, 1)),
      ];

  static List<BoxShadow> get shadowSm => const [
        BoxShadow(color: Color(0x0F0A0A0F), blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x0A0A0A0F), blurRadius: 4, offset: Offset(0, 2)),
      ];

  static List<BoxShadow> get shadowMd => const [
        BoxShadow(color: Color(0x0F0A0A0F), blurRadius: 6, offset: Offset(0, 2)),
        BoxShadow(color: Color(0x0F0A0A0F), blurRadius: 16, offset: Offset(0, 10)),
      ];

  static List<BoxShadow> get shadowLg => const [
        BoxShadow(color: Color(0x140A0A0F), blurRadius: 20, offset: Offset(0, 10)),
        BoxShadow(color: Color(0x0F0A0A0F), blurRadius: 40, offset: Offset(0, 20)),
      ];

  static List<BoxShadow> shadowBrand({double alpha = 0.18}) => [
        BoxShadow(
          color: ember.withValues(alpha: alpha),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -6,
        ),
      ];

  // --- Signature gradients ---
  static const LinearGradient emberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emberSoft, ember, emberDeep],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8A82FF), Color(0xFF635BFF), Color(0xFFFF5E1B)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient inkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12121A), Color(0xFF0A0A0F)],
  );

  /// Store hero / fallback banner — deep navy band.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0A0E27), Color(0xFF1A1F3A), Color(0xFF0A0E27)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

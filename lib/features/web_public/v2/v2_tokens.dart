// V2 Design Tokens — DG Yard Connect Public Web
//
// Mobile-first, Stripe / Vercel / Linear inspired token system.
// Single source of truth for spacing, breakpoints, radii, motion durations.
//
// Breakpoints (mobile-first):
//   xs  : 0–639   (320 / 375 / 414)
//   sm  : 640–767 (large mobile)
//   md  : 768–1023 (tablet)
//   lg  : 1024–1279 (laptop)
//   xl  : 1280–1439 (desktop)
//   2xl : 1440+   (1440 / 1920+ wide desktop)

import 'package:flutter/widgets.dart';

class V2Breakpoints {
  V2Breakpoints._();

  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
  static const double xxl = 1440;
}

enum V2Bp { xs, sm, md, lg, xl, xxl }

extension V2BpExt on V2Bp {
  bool get isMobile => this == V2Bp.xs || this == V2Bp.sm;
  bool get isTablet => this == V2Bp.md;
  bool get isDesktop => index >= V2Bp.lg.index;
  bool get isWide => index >= V2Bp.xl.index;
}

class V2 {
  V2._();

  // --- Container ---
  /// Max width of any centered content container.
  static const double maxContentWidth = 1280;
  static const double maxNarrow = 720;
  static const double maxMedium = 960;

  // --- Spacing (4px grid) ---
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 28;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s14 = 56;
  static const double s16 = 64;
  static const double s20 = 80;
  static const double s24 = 96;
  static const double s28 = 112;
  static const double s32 = 128;

  // --- Radii ---
  static const double rSm = 6;
  static const double rMd = 10;
  static const double rLg = 14;
  static const double rXl = 20;
  static const double r2xl = 28;
  static const double rFull = 999;

  // --- Motion ---
  static const Duration dFast = Duration(milliseconds: 150);
  static const Duration d = Duration(milliseconds: 220);
  static const Duration dMed = Duration(milliseconds: 360);
  static const Duration dSlow = Duration(milliseconds: 520);

  static const Curve eOut = Curves.easeOutCubic;
  static const Curve eInOut = Curves.easeInOutCubic;

  // --- Z indexes (visual layering) ---
  static const double zNav = 100;
  static const double zModal = 200;
}

/// Responsive helpers — mobile-first, semantic, no hardcoded breakpoint logic
/// scattered across widgets.
class V2Responsive {
  V2Responsive(this.context)
      : width = MediaQuery.of(context).size.width,
        height = MediaQuery.of(context).size.height;

  final BuildContext context;
  final double width;
  final double height;

  V2Bp get bp {
    if (width >= V2Breakpoints.xxl) return V2Bp.xxl;
    if (width >= V2Breakpoints.xl) return V2Bp.xl;
    if (width >= V2Breakpoints.lg) return V2Bp.lg;
    if (width >= V2Breakpoints.md) return V2Bp.md;
    if (width >= V2Breakpoints.sm) return V2Bp.sm;
    return V2Bp.xs;
  }

  bool get isMobile => bp.isMobile;
  bool get isTablet => bp.isTablet;
  bool get isDesktop => bp.isDesktop;
  bool get isWide => bp.isWide;

  /// Pick a value by breakpoint. Mobile-first: any larger breakpoint
  /// inherits the closest smaller one defined.
  T r<T>({
    required T xs,
    T? sm,
    T? md,
    T? lg,
    T? xl,
    T? xxl,
  }) {
    switch (bp) {
      case V2Bp.xxl:
        return xxl ?? xl ?? lg ?? md ?? sm ?? xs;
      case V2Bp.xl:
        return xl ?? lg ?? md ?? sm ?? xs;
      case V2Bp.lg:
        return lg ?? md ?? sm ?? xs;
      case V2Bp.md:
        return md ?? sm ?? xs;
      case V2Bp.sm:
        return sm ?? xs;
      case V2Bp.xs:
        return xs;
    }
  }

  /// Horizontal gutter for any full-width container.
  double get gutter => r<double>(
        xs: 16.0,
        sm: 20.0,
        md: 32.0,
        lg: 40.0,
        xl: 48.0,
        xxl: 56.0,
      );

  /// Vertical padding for any premium section.
  double get sectionPadY => r<double>(
        xs: 56.0,
        sm: 64.0,
        md: 80.0,
        lg: 96.0,
        xl: 112.0,
        xxl: 120.0,
      );

  /// Number of columns for product / category grids.
  int gridCols({int xsCols = 2, int? smCols, int? mdCols, int? lgCols, int? xlCols, int? xxlCols}) {
    return r(
      xs: xsCols,
      sm: smCols,
      md: mdCols ?? smCols,
      lg: lgCols ?? mdCols ?? smCols,
      xl: xlCols ?? lgCols ?? mdCols ?? smCols,
      xxl: xxlCols ?? xlCols ?? lgCols ?? mdCols ?? smCols,
    );
  }
}

extension V2ResponsiveX on BuildContext {
  V2Responsive get v2 => V2Responsive(this);
}

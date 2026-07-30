import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Drop-in BackdropFilter replacement — no blur on web (CanvasKit TBT).
Widget v2BlurLayer({required double sigma, required Widget child}) {
  if (kIsWeb) return child;
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    ),
  );
}

/// Web-safe glass — BackdropFilter is extremely expensive on CanvasKit mobile.
Widget v2BackdropGlass({
  required Widget child,
  required Color backgroundColor,
  double blurSigma = 18,
  Border? border,
  List<BoxShadow>? boxShadow,
}) {
  if (kIsWeb) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: border,
          boxShadow: boxShadow,
        ),
        child: child,
      ),
    ),
  );
}

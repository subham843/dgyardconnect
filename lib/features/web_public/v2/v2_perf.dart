import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';


/// Web perf helpers — skip expensive motion on CanvasKit mobile browsers.
bool get v2SkipMotion => kIsWeb;

extension V2AnimateGate on Widget {
  /// Returns [this] on web; otherwise applies flutter_animate chain.
  Widget v2Animate(Widget Function(Widget) build) {
    if (v2SkipMotion) return this;
    return build(this);
  }
}

Widget v2GradientText({
  required String text,
  required TextStyle style,
  required List<Color> colors,
}) {
  if (v2SkipMotion) {
    return Text(text, style: style.copyWith(color: colors.first));
  }
  return ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}

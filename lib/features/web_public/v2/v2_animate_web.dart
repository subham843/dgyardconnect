import 'package:flutter/material.dart';

/// No-op flutter_animate on web — avoids AnimationController TBT.
extension NumDuration on num {
  Duration get ms => Duration(milliseconds: round());
}

/// Passthrough widget; chain methods return [this] unchanged.
class V2AnimatePassthrough extends StatelessWidget {
  const V2AnimatePassthrough(this.child, {super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

extension V2AnimateWidget on Widget {
  V2AnimatePassthrough animate({
    Duration? delay,
    Duration? duration,
    Curve? curve,
    void Function(AnimationController)? onPlay,
  }) =>
      V2AnimatePassthrough(this);
}

extension V2AnimateEffects on V2AnimatePassthrough {
  V2AnimatePassthrough fadeIn({
    Duration? duration,
    Duration? delay,
    Curve? curve = Curves.linear,
  }) =>
      this;

  V2AnimatePassthrough slideX({
    double? begin,
    double? end,
    Curve? curve,
    Duration? duration,
    Duration? delay,
  }) =>
      this;

  V2AnimatePassthrough slideY({
    double? begin,
    double? end,
    Curve? curve,
    Duration? duration,
    Duration? delay,
  }) =>
      this;

  V2AnimatePassthrough scale({
    Offset? begin,
    Offset? end,
    Curve? curve,
    Duration? duration,
    Duration? delay,
  }) =>
      this;

  V2AnimatePassthrough shimmer({
    Duration? duration,
    Duration? delay,
    Color? color,
    double? angle,
    Duration? period,
  }) =>
      this;
}

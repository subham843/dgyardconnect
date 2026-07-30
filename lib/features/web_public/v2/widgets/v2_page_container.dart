import 'package:flutter/material.dart';

import '../v2_tokens.dart';

/// Centered max-width page container (replaces legacy ResponsiveContainer).
class V2PageContainer extends StatelessWidget {
  const V2PageContainer({
    super.key,
    required this.child,
    this.maxWidth = V2.maxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: v.gutter,
        );

    return Center(
      child: Padding(
        padding: effectivePadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

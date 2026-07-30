import 'package:flutter/material.dart';

/// Invisible shell under the HTML homepage — no loading copy.
class HomeColdStartPlaceholder extends StatelessWidget {
  const HomeColdStartPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF070A12),
      body: SizedBox.expand(),
    );
  }
}

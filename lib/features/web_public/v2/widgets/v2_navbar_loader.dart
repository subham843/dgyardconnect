import 'package:flutter/material.dart';

import '../../../../core/bootstrap/web_post_paint.dart';
import '../v2_colors.dart';
import '../v2_navbar_layout.dart';
import 'navbar_shell_bundle.dart' deferred as navbar_shell;

/// Loads [V2Navbar] after idle/interaction — keeps navbar UI out of main.dart.js.
class V2NavbarLoader extends StatefulWidget {
  const V2NavbarLoader({
    super.key,
    this.scrollController,
    this.embedded = false,
    this.floating = false,
    this.overMedia = false,
  });

  final ScrollController? scrollController;
  final bool embedded;
  final bool floating;
  final bool overMedia;

  static double barHeight({required bool isDesktop}) =>
      V2NavbarLayout.barHeight(isDesktop: isDesktop);

  static double totalHeight(
    BuildContext context, {
    required bool isDesktop,
    bool floating = false,
  }) =>
      V2NavbarLayout.totalHeight(
        context,
        isDesktop: isDesktop,
        floating: floating,
      );

  @override
  State<V2NavbarLoader> createState() => _V2NavbarLoaderState();
}

class _V2NavbarLoaderState extends State<V2NavbarLoader> {
  static Future<void>? _libraryFuture;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    scheduleAfterFirstFrame(_scheduleLoad);
  }

  Future<void> _scheduleLoad() async {
    _libraryFuture ??= navbar_shell.loadLibrary();
    try {
      await _libraryFuture;
      if (mounted) setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('V2NavbarLoader: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return _NavbarPlaceholder(
        floating: widget.floating,
        embedded: widget.embedded,
      );
    }
    return navbar_shell.buildV2Navbar(
      scrollController: widget.scrollController,
      embedded: widget.embedded,
      floating: widget.floating,
      overMedia: widget.overMedia,
    );
  }
}

class _NavbarPlaceholder extends StatelessWidget {
  const _NavbarPlaceholder({
    required this.floating,
    required this.embedded,
  });

  final bool floating;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (embedded) return const SizedBox.shrink();

    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final height = V2NavbarLayout.totalHeight(
      context,
      isDesktop: isDesktop,
      floating: floating,
    );

    return SizedBox(
      height: height,
      child: ColoredBox(
        color: floating
            ? Colors.transparent
            : V2Colors.saasBg.withValues(alpha: 0.92),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: V2Colors.premiumOrange.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

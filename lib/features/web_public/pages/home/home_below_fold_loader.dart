import 'package:flutter/material.dart';

import '../../../../core/bootstrap/web_idle_export.dart';
import '../../../../core/bootstrap/web_post_paint.dart';
import 'home_hero_loader.dart';
import 'home_below_fold_bundle.dart' deferred as home_below;

/// Loads below-fold after hero + long idle (avoids PSI pulling all chunks at once).
class HomeBelowFoldLoader extends StatefulWidget {
  const HomeBelowFoldLoader({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<HomeBelowFoldLoader> createState() => _HomeBelowFoldLoaderState();
}

class _HomeBelowFoldLoaderState extends State<HomeBelowFoldLoader> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    scheduleAfterFirstFrame(_scheduleLoad);
  }

  Future<void> _scheduleLoad() async {
    await HomeHeroLoader.whenReady;
    if (!mounted) return;
    await whenSafeToLoadBelowFold(maxWait: const Duration(seconds: 6));
    if (!mounted) return;
    try {
      await home_below.loadLibrary();
      if (mounted) setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('HomeBelowFoldLoader: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load page sections.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    if (!_ready) {
      return const _BelowFoldPlaceholder();
    }
    return home_below.HomeBelowFoldSections();
  }
}

/// Lightweight skeleton while the deferred home chunk downloads.
class _BelowFoldPlaceholder extends StatelessWidget {
  const _BelowFoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F5F7),
      child: Column(
        children: [
          Container(height: 120, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 420, color: Colors.white),
        ],
      ),
    );
  }
}
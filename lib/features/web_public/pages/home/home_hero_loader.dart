import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/bootstrap/web_post_paint.dart';
import 'home_hero_bundle.dart' deferred as home_hero;

/// Loads hero chunk after idle/interaction (does not compete with engine startup).
class HomeHeroLoader extends StatefulWidget {
  const HomeHeroLoader({super.key, required this.scrollController});

  final ScrollController scrollController;

  /// Completes when the hero deferred library has loaded (used by below-fold).
  static Future<void> get whenReady => _readyCompleter.future;
  static final Completer<void> _readyCompleter = Completer<void>();
  static Future<void>? _libraryFuture;

  @override
  State<HomeHeroLoader> createState() => _HomeHeroLoaderState();
}

class _HomeHeroLoaderState extends State<HomeHeroLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    scheduleAfterFirstFrame(_scheduleLoad);
  }

  void _scheduleLoad() {
    _loadHero();
  }

  void _loadHero() {
    HomeHeroLoader._libraryFuture ??= home_hero.loadLibrary();
    HomeHeroLoader._libraryFuture!.then((_) {
      if (!HomeHeroLoader._readyCompleter.isCompleted) {
        HomeHeroLoader._readyCompleter.complete();
      }
      if (mounted) setState(() => _ready = true);
    }).catchError((Object e, StackTrace st) {
      debugPrint('HomeHeroLoader: $e\n$st');
      if (!HomeHeroLoader._readyCompleter.isCompleted) {
        HomeHeroLoader._readyCompleter.completeError(e, st);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox(height: 620, child: ColoredBox(color: Color(0xFF070A12)));
    }
    return home_hero.buildHomeHero(scrollController: widget.scrollController);
  }
}
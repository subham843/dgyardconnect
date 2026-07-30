// Public Home — floating bottom menu + deferred hero / below-fold chunks.

import 'package:flutter/material.dart';

import '../../v2/v2_colors.dart';
import '../../widgets/public_floating_menu.dart';
import 'home_below_fold_loader.dart';
import 'home_hero_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V2Colors.saasBg,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeroLoader(scrollController: _scroll),
              ),
              SliverToBoxAdapter(
                child: HomeBelowFoldLoader(scrollController: _scroll),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: PublicFloatingMenu.contentBottomInset(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../v2/sections/v2_hero.dart';

/// Deferred hero chunk — no top navbar; floating menu lives on [HomePage].
Widget buildHomeHero({required ScrollController scrollController}) {
  return V2Hero(
    scrollController: scrollController,
    extendsUnderNav: true,
  );
}
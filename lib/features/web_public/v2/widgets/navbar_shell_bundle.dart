import 'package:flutter/material.dart';

import 'v2_navbar.dart';

/// Full navbar UI — deferred chunk (mega menu, glass, search bar).
Widget buildV2Navbar({
  ScrollController? scrollController,
  bool embedded = false,
  bool floating = false,
  bool overMedia = false,
}) {
  return V2Navbar(
    scrollController: scrollController,
    embedded: embedded,
    floating: floating,
    overMedia: overMedia,
  );
}

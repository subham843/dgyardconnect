import 'package:flutter/material.dart';

import 'v2_products_mega_menu.dart';

/// Deferred navbar mega menu — keeps Supabase catalog out of main.dart.js.
Widget buildNavbarMegaMenu({
  required bool visible,
  required VoidCallback onClose,
  required double anchorWidth,
}) {
  return V2ProductsMegaMenu(
    visible: visible,
    onClose: onClose,
    anchorWidth: anchorWidth,
  );
}

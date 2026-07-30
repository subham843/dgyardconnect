import '../models/brand_kit_model.dart';

import 'brand_kit_web_stub.dart'
    if (dart.library.html) 'brand_kit_web_impl.dart' as impl;

/// Updates favicon and apple-touch-icon from brand kit (web only; no-op on mobile).
void updateFaviconAndIcons(BrandKitModel kit) {
  impl.updateFaviconAndIcons(kit);
}

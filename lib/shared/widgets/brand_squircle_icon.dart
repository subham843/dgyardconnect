import 'package:flutter/material.dart';

import '../models/brand_kit_model.dart';
import 'brand_kit_provider.dart';
import 'squircle_avatar.dart';

/// Brand kit app icon in squircle shape with white glow.
/// Use on hero, sticky bar, etc.
class BrandSquircleIcon extends StatelessWidget {
  const BrandSquircleIcon({
    super.key,
    this.size = 64,
    this.glowColor = Colors.white,
    this.glowBlur = 12,
    this.glowSpread = 2,
  });

  final double size;
  final Color glowColor;
  final double glowBlur;
  final double glowSpread;

  @override
  Widget build(BuildContext context) {
    final kit = _getKit(context);
    final url = kit.appIcon512Url ?? kit.appIcon192Url ?? kit.appIconUrl ??
        kit.logoIconUrl ?? kit.logoColorUrl ?? kit.logoWhiteUrl ?? kit.splashLogoUrl;

    return SquircleAvatar(
      photoUrl: url,
      size: size,
      glowColor: glowColor,
      glowBlur: glowBlur,
      glowSpread: glowSpread,
      backgroundColor: Colors.grey.shade800,
      fallback: Icon(Icons.build_circle, size: size * 0.5, color: Colors.white70),
    );
  }

  BrandKitModel _getKit(BuildContext context) {
    try {
      return BrandKitProvider.of(context);
    } catch (_) {
      return const BrandKitModel();
    }
  }
}

import 'package:flutter/material.dart';

import '../models/brand_kit_model.dart';
import '../../core/theme/app_colors.dart';
import 'brand_kit_provider.dart';
import 'brand_kit_logo_image.dart';
import '../utils/brand_logo_tint.dart';

/// Displays brand logo/icon - from brand kit or fallback icon.
class BrandLogo extends StatefulWidget {
  const BrandLogo({
    super.key,
    this.size = 64,
    this.color,
    this.fit = BoxFit.contain,

    /// When true, prefers squircle app icon (for hero/top bar).
    this.preferAppIcon = false,

    /// When true, prefers full-width logoColorUrl / logoWhiteUrl (navbar, headers).
    this.preferLandscapeLogo = false,

    /// Landscape height — used with [maxWidth]. Falls back to [size] when null.
    this.height,
    this.maxWidth,
  });

  final double size;
  final Color? color;
  final BoxFit fit;
  final bool preferAppIcon;
  final bool preferLandscapeLogo;
  final double? height;
  final double? maxWidth;

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> {
  int _urlIndex = 0;
  String? _lastKitSignature;

  @override
  void didUpdateWidget(covariant BrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferLandscapeLogo != widget.preferLandscapeLogo ||
        oldWidget.color != widget.color) {
      _urlIndex = 0;
    }
  }

  void _syncKitSignature(BrandKitModel kit) {
    final sig =
        '${kit.logoColorUrl}|${kit.logoWhiteUrl}|${kit.publicWeb.webLogoTintMode}|${kit.publicWeb.webLogoCustomTintHex}';
    if (_lastKitSignature != sig) {
      _lastKitSignature = sig;
      _urlIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = _getKit(context);
    _syncKitSignature(kit);

    if (widget.preferLandscapeLogo) {
      return _buildLandscape(context, kit);
    }

    final needWhite = widget.color == Colors.white;
    final urls = _pickUrls(kit, needWhite);
    final fallbackColor = widget.color ?? AppColors.googleBlue;

    if (urls.isEmpty) {
      return _fallbackWidget(fallbackColor);
    }

    final activeIndex = _urlIndex < urls.length ? _urlIndex : 0;
    final url = urls[activeIndex];
    final h = widget.height ?? widget.size;
    final w = widget.maxWidth ?? widget.size;
    final tint = BrandLogoTint.resolveTint(kit, preferWhiteAsset: needWhite);

    return SizedBox(
      width: w,
      height: h,
      child: BrandKitLogoImage(
        url: url,
        width: w,
        height: h,
        fit: widget.fit,
        alignment: Alignment.centerLeft,
        tintColor: needWhite ? null : tint,
        errorWidget: _errorOrNext(urls, activeIndex, h, w, fallbackColor),
      ),
    );
  }

  /// Navbar / header — landscape logos from Brand Kit (`logoColorUrl` / `logoWhiteUrl`).
  Widget _buildLandscape(BuildContext context, BrandKitModel kit) {
    final needWhite = widget.color == Colors.white;
    final urls = _pickLandscapeUrls(kit, needWhite);
    final h = widget.height ?? widget.size;
    final w = widget.maxWidth ?? 180;
    final fallbackColor = widget.color ?? AppColors.googleBlue;

    if (urls.isEmpty) {
      return SizedBox(
        width: w,
        height: h,
        child: _fallbackWidget(fallbackColor),
      );
    }

    final activeIndex = _urlIndex < urls.length ? _urlIndex : 0;
    final url = urls[activeIndex];
    final tint = BrandLogoTint.resolveTint(kit, preferWhiteAsset: needWhite);

    return SizedBox(
      width: w,
      height: h,
      child: BrandKitLogoImage(
        url: url,
        width: w,
        height: h,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        tintColor: needWhite ? null : tint,
        placeholder: SizedBox(
          width: w,
          height: h,
          child: _fallbackWidget(fallbackColor),
        ),
        errorWidget: _landscapeError(urls, activeIndex, h, w, fallbackColor),
      ),
    );
  }

  Widget _landscapeError(
    List<String> urls,
    int activeIndex,
    double h,
    double w,
    Color fallbackColor,
  ) {
    if (activeIndex < urls.length - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _urlIndex = activeIndex + 1);
      });
      return SizedBox(
        width: w,
        height: h,
        child: _fallbackWidget(fallbackColor),
      );
    }
    return SizedBox(width: w, height: h, child: _fallbackWidget(fallbackColor));
  }

  Widget _errorOrNext(
    List<String> urls,
    int activeIndex,
    double h,
    double w,
    Color fallbackColor,
  ) {
    if (activeIndex < urls.length - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _urlIndex = activeIndex + 1);
      });
    }
    return _fallbackWidget(fallbackColor);
  }

  Widget _fallbackWidget(Color fallbackColor) {
    final h = widget.height ?? widget.size;
    final w = widget.maxWidth ?? widget.size;
    return Image.asset(
      'assets/icons/app_icon.png',
      width: w,
      height: h,
      fit: widget.fit,
      errorBuilder: (_, _, _) {
        return Icon(Icons.build_circle, size: h, color: fallbackColor);
      },
    );
  }

  List<String> _pickLandscapeUrls(BrandKitModel kit, bool needWhite) {
    final items = needWhite
        ? <String?>[kit.logoWhiteUrl, kit.logoColorUrl]
        : <String?>[kit.logoColorUrl, kit.logoWhiteUrl];
    return _dedupeUrls(items);
  }

  List<String> _pickUrls(BrandKitModel kit, bool needWhite) {
    final items = <String?>[];
    if (needWhite) {
      items.addAll([
        kit.logoWhiteUrl,
        kit.splashLogoUrl,
        kit.appIcon512Url,
        kit.appIcon192Url,
        kit.appIconUrl,
        kit.logoIconUrl,
        kit.logoColorUrl,
      ]);
    } else if (widget.preferAppIcon) {
      items.addAll([
        kit.appIcon512Url,
        kit.appIcon192Url,
        kit.appIconUrl,
        kit.logoIconUrl,
        kit.logoColorUrl,
        kit.logoWhiteUrl,
      ]);
    } else {
      items.addAll([
        kit.logoColorUrl,
        kit.logoIconUrl,
        kit.appIcon512Url,
        kit.appIcon192Url,
        kit.appIconUrl,
        kit.logoWhiteUrl,
        kit.splashLogoUrl,
      ]);
    }
    return _dedupeUrls(items);
  }

  List<String> _dedupeUrls(List<String?> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in items) {
      final url = raw?.trim() ?? '';
      if (url.isEmpty) continue;
      if (seen.add(url)) result.add(url);
    }
    return result;
  }

  BrandKitModel _getKit(BuildContext context) {
    return BrandKitProvider.of(context);
  }
}

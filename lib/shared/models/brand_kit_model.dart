import 'package:flutter/material.dart';
import 'brand_kit_public_web.dart';
import '../utils/firestore_map_utils.dart';

/// Brand kit model - all brand assets and colors for world-class app branding.
class BrandKitModel {
  const BrandKitModel({
    this.appName,
    this.tagline,
    this.primaryColorHex,
    this.secondaryColorHex,
    this.accentColorHex,
    this.publicWeb = const BrandKitPublicWeb(),
    this.appIconUrl,
    this.appIcon192Url,
    this.appIcon512Url,
    this.faviconUrl,
    this.logoWhiteUrl,
    this.logoColorUrl,
    this.logoIconUrl,
    this.animatedLogoUrl,
    this.animatedAppIconUrl,
    this.splashBackgroundUrl,
    this.splashLogoUrl,
    this.ogImageUrl,
    this.appleTouchIconUrl,
  });

  final String? appName;
  final String? tagline;
  final String? primaryColorHex;
  final String? secondaryColorHex;
  final String? accentColorHex;
  final BrandKitPublicWeb publicWeb;
  final String? appIconUrl;
  final String? appIcon192Url;
  final String? appIcon512Url;
  final String? faviconUrl;
  final String? logoWhiteUrl;
  final String? logoColorUrl;
  final String? logoIconUrl;
  final String? animatedLogoUrl;
  final String? animatedAppIconUrl;
  final String? splashBackgroundUrl;
  final String? splashLogoUrl;
  final String? ogImageUrl;
  final String? appleTouchIconUrl;

  Color? get primaryColor => _parseColor(primaryColorHex);
  Color? get secondaryColor => _parseColor(secondaryColorHex);
  Color? get accentColor => _parseColor(accentColorHex);

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final h = hex.replaceFirst('#', '');
    if (h.length != 6 && h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v | 0xFF000000);
  }

  factory BrandKitModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const BrandKitModel();
    return BrandKitModel(
      appName: data['appName'] as String?,
      tagline: data['tagline'] as String?,
      primaryColorHex: data['primaryColorHex'] as String?,
      secondaryColorHex: data['secondaryColorHex'] as String?,
      accentColorHex: data['accentColorHex'] as String?,
      publicWeb: BrandKitPublicWeb.fromMap(firestoreStringMap(data['publicWeb'])),
      appIconUrl: data['appIconUrl'] as String?,
      appIcon192Url: data['appIcon192Url'] as String?,
      appIcon512Url: data['appIcon512Url'] as String?,
      faviconUrl: data['faviconUrl'] as String?,
      logoWhiteUrl: data['logoWhiteUrl'] as String?,
      logoColorUrl: data['logoColorUrl'] as String?,
      logoIconUrl: data['logoIconUrl'] as String?,
      animatedLogoUrl: data['animatedLogoUrl'] as String?,
      animatedAppIconUrl: data['animatedAppIconUrl'] as String?,
      splashBackgroundUrl: data['splashBackgroundUrl'] as String?,
      splashLogoUrl: data['splashLogoUrl'] as String?,
      ogImageUrl: data['ogImageUrl'] as String?,
      appleTouchIconUrl: data['appleTouchIconUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      if (appName != null) 'appName': appName,
      if (tagline != null) 'tagline': tagline,
      if (primaryColorHex != null) 'primaryColorHex': primaryColorHex,
      if (secondaryColorHex != null) 'secondaryColorHex': secondaryColorHex,
      if (accentColorHex != null) 'accentColorHex': accentColorHex,
      if (appIconUrl != null) 'appIconUrl': appIconUrl,
      if (appIcon192Url != null) 'appIcon192Url': appIcon192Url,
      if (appIcon512Url != null) 'appIcon512Url': appIcon512Url,
      if (faviconUrl != null) 'faviconUrl': faviconUrl,
      if (logoWhiteUrl != null) 'logoWhiteUrl': logoWhiteUrl,
      if (logoColorUrl != null) 'logoColorUrl': logoColorUrl,
      if (logoIconUrl != null) 'logoIconUrl': logoIconUrl,
      if (animatedLogoUrl != null) 'animatedLogoUrl': animatedLogoUrl,
      if (animatedAppIconUrl != null) 'animatedAppIconUrl': animatedAppIconUrl,
      if (splashBackgroundUrl != null) 'splashBackgroundUrl': splashBackgroundUrl,
      if (splashLogoUrl != null) 'splashLogoUrl': splashLogoUrl,
      if (ogImageUrl != null) 'ogImageUrl': ogImageUrl,
      if (appleTouchIconUrl != null) 'appleTouchIconUrl': appleTouchIconUrl,
    };
    final web = publicWeb.toMap();
    if (web.isNotEmpty) map['publicWeb'] = web;
    return map;
  }

  BrandKitModel copyWith({
    String? appName,
    String? tagline,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? accentColorHex,
    BrandKitPublicWeb? publicWeb,
    String? appIconUrl,
    String? appIcon192Url,
    String? appIcon512Url,
    String? faviconUrl,
    String? logoWhiteUrl,
    String? logoColorUrl,
    String? logoIconUrl,
    String? animatedLogoUrl,
    String? animatedAppIconUrl,
    String? splashBackgroundUrl,
    String? splashLogoUrl,
    String? ogImageUrl,
    String? appleTouchIconUrl,
  }) {
    return BrandKitModel(
      appName: appName ?? this.appName,
      tagline: tagline ?? this.tagline,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      publicWeb: publicWeb ?? this.publicWeb,
      appIconUrl: appIconUrl ?? this.appIconUrl,
      appIcon192Url: appIcon192Url ?? this.appIcon192Url,
      appIcon512Url: appIcon512Url ?? this.appIcon512Url,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      logoWhiteUrl: logoWhiteUrl ?? this.logoWhiteUrl,
      logoColorUrl: logoColorUrl ?? this.logoColorUrl,
      logoIconUrl: logoIconUrl ?? this.logoIconUrl,
      animatedLogoUrl: animatedLogoUrl ?? this.animatedLogoUrl,
      animatedAppIconUrl: animatedAppIconUrl ?? this.animatedAppIconUrl,
      splashBackgroundUrl: splashBackgroundUrl ?? this.splashBackgroundUrl,
      splashLogoUrl: splashLogoUrl ?? this.splashLogoUrl,
      ogImageUrl: ogImageUrl ?? this.ogImageUrl,
      appleTouchIconUrl: appleTouchIconUrl ?? this.appleTouchIconUrl,
    );
  }
}

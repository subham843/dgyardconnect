import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/models/brand_kit_model.dart';
import '../../../../shared/models/hero_accent_config.dart';
import '../../../../shared/models/hero_cta_app_link.dart';
import '../../../../shared/models/public_web_offer_bar_item.dart';

/// Dynamic public website copy resolved from Admin Brand Kit.
class PublicBrandContent {
  const PublicBrandContent(this.kit);

  final BrandKitModel kit;

  factory PublicBrandContent.fromKit(BrandKitModel kit) => PublicBrandContent(kit);

  String get companyName => _text(kit.appName, AppConstants.appName);
  String get companyShortName => _text(kit.publicWeb.companyShortName, companyName);
  String get tagline => _text(kit.tagline, AppConstants.appTagline);

  String get heroBadgeText =>
      _text(kit.publicWeb.heroBadgeText, "India's Premier Technology Platform");
  String get heroHeadline =>
      _text(kit.publicWeb.heroHeadline, 'Digital | Secure | Smart Living');

  String get heroAccentWord {
    final configured = kit.publicWeb.heroAccentWord?.trim() ?? '';
    if (configured.isNotEmpty) return configured;
    final parts = heroHeadline.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.last : '';
  }

  String get heroHeadlinePrefix {
    final (prefix, _) = splitHeroHeadline(
      headline: heroHeadline,
      accentWord: kit.publicWeb.heroAccentWord,
    );
    return prefix;
  }

  Color get heroAccentColor =>
      parseAccentColorHex(kit.publicWeb.heroAccentColorHex, fallback: null) ??
      const Color(0xFFFF7A00);

  HeroAccentFontWeight get heroAccentFontWeight =>
      HeroAccentFontWeight.fromId(kit.publicWeb.heroAccentFontWeight);

  FontStyle get heroAccentFontStyle =>
      kit.publicWeb.heroAccentFontStyle == 'italic' ? FontStyle.italic : FontStyle.normal;

  HeroAccentFontFamily get heroAccentFontFamily =>
      HeroAccentFontFamily.fromId(kit.publicWeb.heroAccentFontFamily);

  HeroAccentAnimation get heroAccentAnimation =>
      HeroAccentAnimation.fromId(kit.publicWeb.heroAccentAnimation);

  bool get hasHeroAccent => heroAccentWord.isNotEmpty;
  String get heroSubheadline => _text(
        kit.publicWeb.heroSubheadline,
        kit.publicWeb.heroDescription ?? AppConstants.appTagline,
      );
  String get heroDescription => _text(
        kit.publicWeb.heroDescription,
        'Security, IT infrastructure, software solutions and professional services in one unified platform.',
      );

  List<String> get heroSlideUrls =>
      kit.publicWeb.heroSlideUrls ?? const <String>[];

  /// First admin hero slide — used as hero background.
  String? get heroSlide1Url {
    if (heroSlideUrls.isEmpty) return null;
    final url = heroSlideUrls.first.trim();
    return url.isNotEmpty ? url : null;
  }

  List<PublicWebOfferBarItem> get topOfferBarItems =>
      kit.publicWeb.topOfferBarItems ?? const <PublicWebOfferBarItem>[];

  String get heroCta1Label => _text(kit.publicWeb.heroCta1Label, 'Download App');

  /// Only when explicitly set in admin — no fallback route.
  String? get heroCta1UrlOptional => _optionalUrl(kit.publicWeb.heroCta1Url);

  bool get heroCta1UsesStoreIcons => true;

  /// Always show Android + iOS store badges (admin icons/URLs when set).
  List<HeroCtaAppLink> get heroCta1StoreButtons {
    HeroCtaAppLink build(HeroCtaAppPlatform platform, String? iconUrl, String? storeUrl, String label) {
      return HeroCtaAppLink(
        platform: platform,
        label: label,
        url: _optionalUrl(storeUrl),
        iconUrl: iconUrl != null && iconUrl.trim().isNotEmpty ? iconUrl.trim() : null,
      );
    }

    return [
      build(
        HeroCtaAppPlatform.android,
        kit.publicWeb.heroCta1AndroidIconUrl,
        kit.publicWeb.heroCta1AndroidUrl,
        _text(kit.publicWeb.heroCta1AndroidLabel, 'Google Play'),
      ),
      build(
        HeroCtaAppPlatform.ios,
        kit.publicWeb.heroCta1IosIconUrl,
        kit.publicWeb.heroCta1IosUrl,
        _text(kit.publicWeb.heroCta1IosLabel, appStoreLabel),
      ),
    ];
  }

  String get heroShopLabel {
    final custom = kit.publicWeb.heroCta3Label?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return 'Shop';
  }
  String get heroShopUrl => _url(kit.publicWeb.heroCta3Url, RouteNames.publicStore);

  String get heroCta2Label => _text(kit.publicWeb.heroCta2Label, 'Try Calculator');
  String get heroCta2Url => _url(kit.publicWeb.heroCta2Url, RouteNames.publicCalculatorList);
  String get heroCta3Label => _text(kit.publicWeb.heroCta3Label, 'Download App');
  String get heroCta3Url => _url(kit.publicWeb.heroCta3Url, kit.publicWeb.playStoreUrl ?? '#');

  String get footerDescription => _text(
        kit.publicWeb.footerDescription,
        heroDescription,
      );
  String get contactEmail => _text(kit.publicWeb.contactEmail, '');
  String get contactPhone => _text(kit.publicWeb.contactPhone, '');
  String get contactAddress => _text(kit.publicWeb.contactAddress, '');

  String get appDownloadTitle =>
      _text(kit.publicWeb.appDownloadTitle, 'Download $companyShortName App');
  String get appDownloadDescription => _text(
        kit.publicWeb.appDownloadDescription,
        'Manage your business, track orders, and access the complete $companyShortName ecosystem on the go.',
      );
  String get playStoreUrl => _url(kit.publicWeb.playStoreUrl, '#');
  String get appStoreUrl => _url(kit.publicWeb.appStoreUrl, '#');
  String get appStoreLabel =>
      _text(kit.publicWeb.appStoreLabel, 'Coming to App Store');

  String get statProducts => _text(kit.publicWeb.statProducts, '2000+');
  String get statBrands => _text(kit.publicWeb.statBrands, '50+');
  String get statDeals => _text(kit.publicWeb.statDeals, '150+');
  String get statDealers => _text(kit.publicWeb.statDealers, '500+');
  String get statTechnicians => _text(kit.publicWeb.statTechnicians, '300+');
  String get statProjects => _text(kit.publicWeb.statProjects, '1000+');

  List<SocialLink> get socialLinks {
    final links = <SocialLink>[
      if (_has(kit.publicWeb.socialFacebookUrl))
        SocialLink('Facebook', kit.publicWeb.socialFacebookUrl!),
      if (_has(kit.publicWeb.socialInstagramUrl))
        SocialLink('Instagram', kit.publicWeb.socialInstagramUrl!),
      if (_has(kit.publicWeb.socialLinkedinUrl))
        SocialLink('LinkedIn', kit.publicWeb.socialLinkedinUrl!),
      if (_has(kit.publicWeb.socialTwitterUrl))
        SocialLink('Twitter', kit.publicWeb.socialTwitterUrl!),
      if (_has(kit.publicWeb.socialYoutubeUrl))
        SocialLink('YouTube', kit.publicWeb.socialYoutubeUrl!),
      if (_has(kit.publicWeb.socialWebsiteUrl))
        SocialLink('Website', kit.publicWeb.socialWebsiteUrl!),
    ];
    return links;
  }

  String _text(String? value, String fallback) {
    final v = value?.trim() ?? '';
    return v.isNotEmpty ? v : fallback;
  }

  String _url(String? value, String fallback) {
    final v = value?.trim() ?? '';
    return v.isNotEmpty ? v : fallback;
  }

  bool _has(String? value) => value != null && value.trim().isNotEmpty;

  String? _optionalUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || v == '#') return null;
    return v;
  }
}

class SocialLink {
  const SocialLink(this.label, this.url);
  final String label;
  final String url;
}

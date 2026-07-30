import '../utils/firestore_map_utils.dart';
import 'public_web_offer_bar_item.dart';

/// Public website branding & content managed from Admin → Brand Kit.
class BrandKitPublicWeb {
  const BrandKitPublicWeb({
    this.companyShortName,
    this.heroBadgeText,
    this.heroHeadline,
    this.heroSubheadline,
    this.heroDescription,
    this.heroCta1Label,
    this.heroCta1Url,
    this.heroCta1AndroidUrl,
    this.heroCta1IosUrl,
    this.heroCta1AndroidLabel,
    this.heroCta1IosLabel,
    this.heroCta1AndroidIconUrl,
    this.heroCta1IosIconUrl,
    this.heroCta2Label,
    this.heroCta2Url,
    this.heroCta3Label,
    this.heroCta3Url,
    this.footerDescription,
    this.contactEmail,
    this.contactPhone,
    this.contactAddress,
    this.socialFacebookUrl,
    this.socialInstagramUrl,
    this.socialLinkedinUrl,
    this.socialTwitterUrl,
    this.socialYoutubeUrl,
    this.socialWebsiteUrl,
    this.appDownloadTitle,
    this.appDownloadDescription,
    this.playStoreUrl,
    this.appStoreUrl,
    this.appStoreLabel,
    this.statProducts,
    this.statBrands,
    this.statDealers,
    this.statTechnicians,
    this.statDeals,
    this.statProjects,
    this.darkBackgroundColorHex,
    this.lightBackgroundColorHex,
    this.heroAccentWord,
    this.heroAccentColorHex,
    this.heroAccentFontWeight,
    this.heroAccentFontStyle,
    this.heroAccentFontFamily,
    this.heroAccentAnimation,
    this.webLogoTintMode,
    this.webLogoCustomTintHex,
    this.heroSlideUrls,
    this.topOfferBarItems,
  });

  final String? companyShortName;
  final String? heroBadgeText;
  final String? heroHeadline;
  final String? heroSubheadline;
  final String? heroDescription;
  final String? heroCta1Label;
  final String? heroCta1Url;
  final String? heroCta1AndroidUrl;
  final String? heroCta1IosUrl;
  final String? heroCta1AndroidLabel;
  final String? heroCta1IosLabel;
  final String? heroCta1AndroidIconUrl;
  final String? heroCta1IosIconUrl;
  final String? heroCta2Label;
  final String? heroCta2Url;
  final String? heroCta3Label;
  final String? heroCta3Url;
  final String? footerDescription;
  final String? contactEmail;
  final String? contactPhone;
  final String? contactAddress;
  final String? socialFacebookUrl;
  final String? socialInstagramUrl;
  final String? socialLinkedinUrl;
  final String? socialTwitterUrl;
  final String? socialYoutubeUrl;
  final String? socialWebsiteUrl;
  final String? appDownloadTitle;
  final String? appDownloadDescription;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? appStoreLabel;
  final String? statProducts;
  final String? statBrands;
  final String? statDealers;
  final String? statTechnicians;
  final String? statDeals;
  final String? statProjects;
  final String? darkBackgroundColorHex;
  final String? lightBackgroundColorHex;
  final String? heroAccentWord;
  final String? heroAccentColorHex;
  final String? heroAccentFontWeight;
  final String? heroAccentFontStyle;
  final String? heroAccentFontFamily;
  final String? heroAccentAnimation;
  /// Website navbar logo tint: original | primary | secondary | accent | white | black | custom
  final String? webLogoTintMode;
  final String? webLogoCustomTintHex;
  /// Homepage hero carousel images (landscape product shots).
  final List<String>? heroSlideUrls;
  /// Rotating promo lines below navbar (Apple-style offer bar).
  final List<PublicWebOfferBarItem>? topOfferBarItems;

  factory BrandKitPublicWeb.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const BrandKitPublicWeb();
    return BrandKitPublicWeb(
      companyShortName: data['companyShortName'] as String?,
      heroBadgeText: data['heroBadgeText'] as String?,
      heroHeadline: data['heroHeadline'] as String?,
      heroSubheadline: data['heroSubheadline'] as String?,
      heroDescription: data['heroDescription'] as String?,
      heroCta1Label: firestoreStringField(data['heroCta1Label']),
      heroCta1Url: firestoreStringField(data['heroCta1Url']),
      heroCta1AndroidUrl: firestoreStringField(data['heroCta1AndroidUrl']),
      heroCta1IosUrl: firestoreStringField(data['heroCta1IosUrl']),
      heroCta1AndroidLabel: firestoreStringField(data['heroCta1AndroidLabel']),
      heroCta1IosLabel: firestoreStringField(data['heroCta1IosLabel']),
      heroCta1AndroidIconUrl: firestoreStringField(data['heroCta1AndroidIconUrl']),
      heroCta1IosIconUrl: firestoreStringField(data['heroCta1IosIconUrl']),
      heroCta2Label: data['heroCta2Label'] as String?,
      heroCta2Url: data['heroCta2Url'] as String?,
      heroCta3Label: data['heroCta3Label'] as String?,
      heroCta3Url: data['heroCta3Url'] as String?,
      footerDescription: data['footerDescription'] as String?,
      contactEmail: data['contactEmail'] as String?,
      contactPhone: data['contactPhone'] as String?,
      contactAddress: data['contactAddress'] as String?,
      socialFacebookUrl: data['socialFacebookUrl'] as String?,
      socialInstagramUrl: data['socialInstagramUrl'] as String?,
      socialLinkedinUrl: data['socialLinkedinUrl'] as String?,
      socialTwitterUrl: data['socialTwitterUrl'] as String?,
      socialYoutubeUrl: data['socialYoutubeUrl'] as String?,
      socialWebsiteUrl: data['socialWebsiteUrl'] as String?,
      appDownloadTitle: data['appDownloadTitle'] as String?,
      appDownloadDescription: data['appDownloadDescription'] as String?,
      playStoreUrl: firestoreStringField(data['playStoreUrl']),
      appStoreUrl: firestoreStringField(data['appStoreUrl']),
      appStoreLabel: data['appStoreLabel'] as String?,
      statProducts: data['statProducts'] as String?,
      statBrands: data['statBrands'] as String?,
      statDealers: data['statDealers'] as String?,
      statTechnicians: data['statTechnicians'] as String?,
      statDeals: data['statDeals'] as String?,
      statProjects: data['statProjects'] as String?,
      darkBackgroundColorHex: data['darkBackgroundColorHex'] as String?,
      lightBackgroundColorHex: data['lightBackgroundColorHex'] as String?,
      heroAccentWord: data['heroAccentWord'] as String?,
      heroAccentColorHex: data['heroAccentColorHex'] as String?,
      heroAccentFontWeight: data['heroAccentFontWeight'] as String?,
      heroAccentFontStyle: data['heroAccentFontStyle'] as String?,
      heroAccentFontFamily: data['heroAccentFontFamily'] as String?,
      heroAccentAnimation: data['heroAccentAnimation'] as String?,
      webLogoTintMode: data['webLogoTintMode'] as String?,
      webLogoCustomTintHex: data['webLogoCustomTintHex'] as String?,
      heroSlideUrls: _parseUrlList(data['heroSlideUrls']),
      topOfferBarItems: _parseOfferBarItems(data['topOfferBarItems']),
    );
  }

  static List<PublicWebOfferBarItem>? _parseOfferBarItems(dynamic value) {
    final items = PublicWebOfferBarItem.parseList(value);
    return items.isEmpty ? null : items;
  }

  static List<String>? _parseUrlList(dynamic value) {
    final urls = firestoreStringList(value);
    return urls.isEmpty ? null : urls;
  }

  Map<String, dynamic> toMap() {
    return {
      if (companyShortName != null) 'companyShortName': companyShortName,
      if (heroBadgeText != null) 'heroBadgeText': heroBadgeText,
      if (heroHeadline != null) 'heroHeadline': heroHeadline,
      if (heroSubheadline != null) 'heroSubheadline': heroSubheadline,
      if (heroDescription != null) 'heroDescription': heroDescription,
      if (heroCta1Label != null) 'heroCta1Label': heroCta1Label,
      if (heroCta1Url != null) 'heroCta1Url': heroCta1Url,
      if (heroCta1AndroidUrl != null) 'heroCta1AndroidUrl': heroCta1AndroidUrl,
      if (heroCta1IosUrl != null) 'heroCta1IosUrl': heroCta1IosUrl,
      if (heroCta1AndroidLabel != null) 'heroCta1AndroidLabel': heroCta1AndroidLabel,
      if (heroCta1IosLabel != null) 'heroCta1IosLabel': heroCta1IosLabel,
      if (heroCta1AndroidIconUrl != null && heroCta1AndroidIconUrl!.trim().isNotEmpty)
        'heroCta1AndroidIconUrl': heroCta1AndroidIconUrl,
      if (heroCta1IosIconUrl != null && heroCta1IosIconUrl!.trim().isNotEmpty)
        'heroCta1IosIconUrl': heroCta1IosIconUrl,
      if (heroCta2Label != null) 'heroCta2Label': heroCta2Label,
      if (heroCta2Url != null) 'heroCta2Url': heroCta2Url,
      if (heroCta3Label != null) 'heroCta3Label': heroCta3Label,
      if (heroCta3Url != null) 'heroCta3Url': heroCta3Url,
      if (footerDescription != null) 'footerDescription': footerDescription,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (contactAddress != null) 'contactAddress': contactAddress,
      if (socialFacebookUrl != null) 'socialFacebookUrl': socialFacebookUrl,
      if (socialInstagramUrl != null) 'socialInstagramUrl': socialInstagramUrl,
      if (socialLinkedinUrl != null) 'socialLinkedinUrl': socialLinkedinUrl,
      if (socialTwitterUrl != null) 'socialTwitterUrl': socialTwitterUrl,
      if (socialYoutubeUrl != null) 'socialYoutubeUrl': socialYoutubeUrl,
      if (socialWebsiteUrl != null) 'socialWebsiteUrl': socialWebsiteUrl,
      if (appDownloadTitle != null) 'appDownloadTitle': appDownloadTitle,
      if (appDownloadDescription != null) 'appDownloadDescription': appDownloadDescription,
      if (playStoreUrl != null) 'playStoreUrl': playStoreUrl,
      if (appStoreUrl != null) 'appStoreUrl': appStoreUrl,
      if (appStoreLabel != null) 'appStoreLabel': appStoreLabel,
      if (statProducts != null) 'statProducts': statProducts,
      if (statBrands != null) 'statBrands': statBrands,
      if (statDealers != null) 'statDealers': statDealers,
      if (statTechnicians != null) 'statTechnicians': statTechnicians,
      if (statDeals != null) 'statDeals': statDeals,
      if (statProjects != null) 'statProjects': statProjects,
      if (darkBackgroundColorHex != null) 'darkBackgroundColorHex': darkBackgroundColorHex,
      if (lightBackgroundColorHex != null) 'lightBackgroundColorHex': lightBackgroundColorHex,
      if (heroAccentWord != null) 'heroAccentWord': heroAccentWord,
      if (heroAccentColorHex != null) 'heroAccentColorHex': heroAccentColorHex,
      if (heroAccentFontWeight != null) 'heroAccentFontWeight': heroAccentFontWeight,
      if (heroAccentFontStyle != null) 'heroAccentFontStyle': heroAccentFontStyle,
      if (heroAccentFontFamily != null) 'heroAccentFontFamily': heroAccentFontFamily,
      if (heroAccentAnimation != null) 'heroAccentAnimation': heroAccentAnimation,
      if (webLogoTintMode != null) 'webLogoTintMode': webLogoTintMode,
      if (webLogoCustomTintHex != null) 'webLogoCustomTintHex': webLogoCustomTintHex,
      if (heroSlideUrls != null && heroSlideUrls!.isNotEmpty) 'heroSlideUrls': heroSlideUrls,
      if (topOfferBarItems != null && topOfferBarItems!.isNotEmpty)
        'topOfferBarItems': topOfferBarItems!.map((e) => e.toMap()).toList(),
    };
  }

  BrandKitPublicWeb copyWith({
    String? companyShortName,
    String? heroBadgeText,
    String? heroHeadline,
    String? heroSubheadline,
    String? heroDescription,
    String? heroCta1Label,
    String? heroCta1Url,
    String? heroCta1AndroidUrl,
    String? heroCta1IosUrl,
    String? heroCta1AndroidLabel,
    String? heroCta1IosLabel,
    String? heroCta1AndroidIconUrl,
    String? heroCta1IosIconUrl,
    String? heroCta2Label,
    String? heroCta2Url,
    String? heroCta3Label,
    String? heroCta3Url,
    String? footerDescription,
    String? contactEmail,
    String? contactPhone,
    String? contactAddress,
    String? socialFacebookUrl,
    String? socialInstagramUrl,
    String? socialLinkedinUrl,
    String? socialTwitterUrl,
    String? socialYoutubeUrl,
    String? socialWebsiteUrl,
    String? appDownloadTitle,
    String? appDownloadDescription,
    String? playStoreUrl,
    String? appStoreUrl,
    String? appStoreLabel,
    String? statProducts,
    String? statBrands,
    String? statDealers,
    String? statTechnicians,
    String? statDeals,
    String? statProjects,
    String? darkBackgroundColorHex,
    String? lightBackgroundColorHex,
    String? heroAccentWord,
    String? heroAccentColorHex,
    String? heroAccentFontWeight,
    String? heroAccentFontStyle,
    String? heroAccentFontFamily,
    String? heroAccentAnimation,
    String? webLogoTintMode,
    String? webLogoCustomTintHex,
    List<String>? heroSlideUrls,
    List<PublicWebOfferBarItem>? topOfferBarItems,
  }) {
    return BrandKitPublicWeb(
      companyShortName: companyShortName ?? this.companyShortName,
      heroBadgeText: heroBadgeText ?? this.heroBadgeText,
      heroHeadline: heroHeadline ?? this.heroHeadline,
      heroSubheadline: heroSubheadline ?? this.heroSubheadline,
      heroDescription: heroDescription ?? this.heroDescription,
      heroCta1Label: heroCta1Label ?? this.heroCta1Label,
      heroCta1Url: heroCta1Url ?? this.heroCta1Url,
      heroCta1AndroidUrl: heroCta1AndroidUrl ?? this.heroCta1AndroidUrl,
      heroCta1IosUrl: heroCta1IosUrl ?? this.heroCta1IosUrl,
      heroCta1AndroidLabel: heroCta1AndroidLabel ?? this.heroCta1AndroidLabel,
      heroCta1IosLabel: heroCta1IosLabel ?? this.heroCta1IosLabel,
      heroCta1AndroidIconUrl: heroCta1AndroidIconUrl ?? this.heroCta1AndroidIconUrl,
      heroCta1IosIconUrl: heroCta1IosIconUrl ?? this.heroCta1IosIconUrl,
      heroCta2Label: heroCta2Label ?? this.heroCta2Label,
      heroCta2Url: heroCta2Url ?? this.heroCta2Url,
      heroCta3Label: heroCta3Label ?? this.heroCta3Label,
      heroCta3Url: heroCta3Url ?? this.heroCta3Url,
      footerDescription: footerDescription ?? this.footerDescription,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      contactAddress: contactAddress ?? this.contactAddress,
      socialFacebookUrl: socialFacebookUrl ?? this.socialFacebookUrl,
      socialInstagramUrl: socialInstagramUrl ?? this.socialInstagramUrl,
      socialLinkedinUrl: socialLinkedinUrl ?? this.socialLinkedinUrl,
      socialTwitterUrl: socialTwitterUrl ?? this.socialTwitterUrl,
      socialYoutubeUrl: socialYoutubeUrl ?? this.socialYoutubeUrl,
      socialWebsiteUrl: socialWebsiteUrl ?? this.socialWebsiteUrl,
      appDownloadTitle: appDownloadTitle ?? this.appDownloadTitle,
      appDownloadDescription: appDownloadDescription ?? this.appDownloadDescription,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      appStoreUrl: appStoreUrl ?? this.appStoreUrl,
      appStoreLabel: appStoreLabel ?? this.appStoreLabel,
      statProducts: statProducts ?? this.statProducts,
      statBrands: statBrands ?? this.statBrands,
      statDealers: statDealers ?? this.statDealers,
      statTechnicians: statTechnicians ?? this.statTechnicians,
      statDeals: statDeals ?? this.statDeals,
      statProjects: statProjects ?? this.statProjects,
      darkBackgroundColorHex: darkBackgroundColorHex ?? this.darkBackgroundColorHex,
      lightBackgroundColorHex: lightBackgroundColorHex ?? this.lightBackgroundColorHex,
      heroAccentWord: heroAccentWord ?? this.heroAccentWord,
      heroAccentColorHex: heroAccentColorHex ?? this.heroAccentColorHex,
      heroAccentFontWeight: heroAccentFontWeight ?? this.heroAccentFontWeight,
      heroAccentFontStyle: heroAccentFontStyle ?? this.heroAccentFontStyle,
      heroAccentFontFamily: heroAccentFontFamily ?? this.heroAccentFontFamily,
      heroAccentAnimation: heroAccentAnimation ?? this.heroAccentAnimation,
      webLogoTintMode: webLogoTintMode ?? this.webLogoTintMode,
      webLogoCustomTintHex: webLogoCustomTintHex ?? this.webLogoCustomTintHex,
      heroSlideUrls: heroSlideUrls ?? this.heroSlideUrls,
      topOfferBarItems: topOfferBarItems ?? this.topOfferBarItems,
    );
  }
}

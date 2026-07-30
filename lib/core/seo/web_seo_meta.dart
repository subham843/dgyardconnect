import 'dart:convert';

import 'site_seo_config.dart';

/// Per-page SEO payload applied to `document.head` on Flutter Web.
class WebSeoMeta {
  const WebSeoMeta({
    required this.title,
    required this.description,
    required this.canonicalPath,
    this.imageUrl,
    this.index = true,
    this.follow = true,
    this.ogType = 'website',
    this.jsonLd,
    this.twitterCard = 'summary_large_image',
  });

  final String title;
  final String description;
  final String canonicalPath;
  final String? imageUrl;
  final bool index;
  final bool follow;
  final String ogType;
  final Object? jsonLd;
  final String twitterCard;

  String get canonicalUrl => SiteSeoConfig.absolute(canonicalPath);

  String get robotsContent {
    final i = index ? 'index' : 'noindex';
    final f = follow ? 'follow' : 'nofollow';
    return '$i, $f';
  }

  String get resolvedImage => imageUrl ?? SiteSeoConfig.defaultImage;

  String? get jsonLdScript {
    if (jsonLd == null) return null;
    return jsonEncode(jsonLd);
  }

  factory WebSeoMeta.noIndex({
    required String title,
    String description = 'This page is not available for search indexing.',
    String canonicalPath = '/',
  }) {
    return WebSeoMeta(
      title: title,
      description: description,
      canonicalPath: canonicalPath,
      index: false,
      follow: false,
    );
  }

  WebSeoMeta copyWith({
    String? title,
    String? description,
    String? canonicalPath,
    String? imageUrl,
    bool? index,
    bool? follow,
    String? ogType,
    Object? jsonLd,
    String? twitterCard,
  }) {
    return WebSeoMeta(
      title: title ?? this.title,
      description: description ?? this.description,
      canonicalPath: canonicalPath ?? this.canonicalPath,
      imageUrl: imageUrl ?? this.imageUrl,
      index: index ?? this.index,
      follow: follow ?? this.follow,
      ogType: ogType ?? this.ogType,
      jsonLd: jsonLd ?? this.jsonLd,
      twitterCard: twitterCard ?? this.twitterCard,
    );
  }
}

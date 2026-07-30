import 'seo_city.dart';
import 'seo_service.dart';

/// Resolved content for /{citySlug}/{serviceSlug} — generated from templates + DB.
class SeoLandingPage {
  const SeoLandingPage({
    required this.city,
    required this.service,
    required this.canonicalPath,
    required this.title,
    required this.metaDescription,
    required this.metaKeywords,
    required this.ogTitle,
    required this.ogDescription,
    required this.robots,
    required this.h1,
    required this.h2Features,
    required this.intro,
    required this.whyChooseHeading,
    required this.processHeading,
    required this.areasHeading,
    required this.areasText,
    required this.faq,
    required this.breadcrumbs,
    required this.relatedServiceLinks,
    required this.jsonLd,
    this.heroImageUrl,
    this.index = true,
  });

  final SeoCity city;
  final SeoService service;
  final String canonicalPath;
  final String title;
  final String metaDescription;
  final String metaKeywords;
  final String ogTitle;
  final String ogDescription;
  final String robots;
  final String h1;
  final String h2Features;
  final String intro;
  final String whyChooseHeading;
  final String processHeading;
  final String areasHeading;
  final String areasText;
  final List<SeoFaqItem> faq;
  final List<SeoBreadcrumb> breadcrumbs;
  final List<SeoRelatedLink> relatedServiceLinks;
  final Map<String, dynamic> jsonLd;
  final String? heroImageUrl;
  final bool index;
}

class SeoBreadcrumb {
  const SeoBreadcrumb({required this.label, required this.path});

  final String label;
  final String path;
}

class SeoRelatedLink {
  const SeoRelatedLink({required this.label, required this.path});

  final String label;
  final String path;
}

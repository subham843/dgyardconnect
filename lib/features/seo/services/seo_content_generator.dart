import '../../../core/constants/route_names.dart';
import '../../../core/seo/site_seo_config.dart';
import '../domain/seo_city.dart';
import '../domain/seo_landing_page.dart';
import '../domain/seo_service.dart';
import 'seo_route_guard.dart';

/// Template engine — unique copy per city × service without static pages.
abstract final class SeoContentGenerator {
  SeoContentGenerator._();

  static String _vars(
    String template,
    SeoCity city,
    SeoService service,
  ) {
    return template
        .replaceAll('{{city}}', city.name)
        .replaceAll('{{City}}', city.name)
        .replaceAll('{{state}}', city.state)
        .replaceAll('{{State}}', city.state)
        .replaceAll('{{service}}', service.name)
        .replaceAll('{{Service}}', service.name)
        .replaceAll('{{slug}}', service.slug)
        .replaceAll('{{city_slug}}', city.slug);
  }

  static SeoLandingPage build({
    required SeoCity city,
    required SeoService service,
    List<SeoService> allServices = const [],
  }) {
    final path = SeoRouteGuard.landingPath(city.slug, service.slug);
    final landingTitle = '${service.name} in ${city.name} | ${SiteSeoConfig.siteName}';
    final pageTitle = _landingTitleOverride(city, service) ?? landingTitle;

    final metaDescription = city.metaDescription?.trim().isNotEmpty == true
        ? _vars(city.metaDescription!, city, service)
        : service.metaDescriptionTemplate?.trim().isNotEmpty == true
            ? _vars(service.metaDescriptionTemplate!, city, service)
            : 'Professional ${service.name.toLowerCase()} in ${city.name}, ${city.state}. '
                'Certified D.G.Yard technicians, transparent BOQ, branded equipment, and AMC support.';

    final h1 = service.h1Template?.trim().isNotEmpty == true
        ? _vars(service.h1Template!, city, service)
        : '${service.name} Services in ${city.name}';

    final h2Features = service.h2FeaturesTemplate?.trim().isNotEmpty == true
        ? _vars(service.h2FeaturesTemplate!, city, service)
        : 'Why ${city.name} businesses choose D.G.Yard for ${service.name.toLowerCase()}';

    final intro = _buildIntro(city, service);
    final areasText = _buildAreasText(city, service);
    final faq = _buildFaq(city, service);
    final related = _relatedServices(city, service, allServices);
    final breadcrumbs = _breadcrumbs(city, service);
    final jsonLd = _jsonLd(city, service, path, faq, breadcrumbs);

    final ogTitle = city.ogTitle?.trim().isNotEmpty == true
        ? _vars(city.ogTitle!, city, service)
        : pageTitle;
    final ogDescription = city.ogDescription?.trim().isNotEmpty == true
        ? _vars(city.ogDescription!, city, service)
        : metaDescription;

    final robots = city.robots.trim().isNotEmpty ? city.robots.trim() : 'index, follow';
    final index = !robots.toLowerCase().contains('noindex');

    return SeoLandingPage(
      city: city,
      service: service,
      canonicalPath: city.canonicalUrl?.trim().isNotEmpty == true
          ? city.canonicalUrl!.trim()
          : path,
      title: pageTitle,
      metaDescription: metaDescription,
      metaKeywords: city.metaKeywords?.trim().isNotEmpty == true
          ? _vars(city.metaKeywords!, city, service)
          : '${service.name}, ${city.name}, ${city.state}, installation, D.G.Yard',
      ogTitle: ogTitle,
      ogDescription: ogDescription,
      robots: robots,
      h1: h1,
      h2Features: h2Features,
      intro: intro,
      whyChooseHeading: 'Why Choose D.G.Yard in ${city.name}',
      processHeading: 'Our ${service.name} Process',
      areasHeading: 'Areas We Cover in ${city.name}',
      areasText: areasText,
      faq: faq,
      breadcrumbs: breadcrumbs,
      relatedServiceLinks: related,
      jsonLd: city.schemaOverride ?? jsonLd,
      heroImageUrl: city.heroImageUrl ?? service.heroImageUrl ?? city.imageUrl,
      index: index,
    );
  }

  static String? _landingTitleOverride(SeoCity city, SeoService service) {
    if (service.seoTitleTemplate?.trim().isNotEmpty == true) {
      return _vars(service.seoTitleTemplate!, city, service);
    }
    return null;
  }

  static String _buildIntro(SeoCity city, SeoService service) {
    final cityBit = city.businessDescription?.trim().isNotEmpty == true
        ? city.businessDescription!.trim()
        : city.description?.trim().isNotEmpty == true
            ? city.description!.trim()
            : 'D.G.Yard serves ${city.name} and surrounding districts in ${city.state}.';

    final serviceBit = service.description?.trim().isNotEmpty == true
        ? _vars(service.description!.trim(), city, service)
        : service.shortDescription?.trim().isNotEmpty == true
            ? _vars(service.shortDescription!.trim(), city, service)
            : 'We deliver professional ${service.name.toLowerCase()} with certified technicians and transparent pricing.';

    return '$serviceBit $cityBit';
  }

  static String _buildAreasText(SeoCity city, SeoService service) {
    if (service.areasCoveredTemplate?.trim().isNotEmpty == true) {
      return _vars(service.areasCoveredTemplate!.trim(), city, service);
    }
    final districts = city.nearbyDistricts.isNotEmpty
        ? city.nearbyDistricts.join(', ')
        : 'all major localities';
    return 'We provide ${service.name.toLowerCase()} across ${city.name} city limits and nearby districts including $districts in ${city.state}.';
  }

  static List<SeoFaqItem> _buildFaq(SeoCity city, SeoService service) {
    final items = <SeoFaqItem>[];
    for (final item in service.faqTemplate) {
      items.add(SeoFaqItem(
        question: _vars(item.question, city, service),
        answer: _vars(item.answer, city, service),
      ));
    }
    for (final item in city.faq) {
      items.add(SeoFaqItem(
        question: _vars(item.question, city, service),
        answer: _vars(item.answer, city, service),
      ));
    }
    if (items.isEmpty) {
      items.addAll([
        SeoFaqItem(
          question: 'Do you provide ${service.name.toLowerCase()} in ${city.name}?',
          answer:
              'Yes. D.G.Yard has active installation teams for ${service.name.toLowerCase()} in ${city.name}, ${city.state} with site survey, BOQ, and warranty-backed execution.',
        ),
        SeoFaqItem(
          question: 'How do I get a quotation for ${service.name.toLowerCase()} in ${city.name}?',
          answer:
              'Contact us via phone or WhatsApp, or use our BOQ calculator. We schedule a free site visit in ${city.name} and share an itemized quotation.',
        ),
        SeoFaqItem(
          question: 'Which areas near ${city.name} do you cover?',
          answer:
              'We cover ${city.name} and nearby districts${city.nearbyDistricts.isNotEmpty ? ': ${city.nearbyDistricts.join(', ')}' : ''} across ${city.state}.',
        ),
      ]);
    }
    return items;
  }

  static List<SeoRelatedLink> _relatedServices(
    SeoCity city,
    SeoService current,
    List<SeoService> all,
  ) {
    return all
        .where((s) => s.id != current.id && s.isActive)
        .take(6)
        .map(
          (s) => SeoRelatedLink(
            label: s.name,
            path: SeoRouteGuard.landingPath(city.slug, s.slug),
          ),
        )
        .toList();
  }

  static List<SeoBreadcrumb> _breadcrumbs(SeoCity city, SeoService service) => [
        const SeoBreadcrumb(label: 'Home', path: RouteNames.publicHome),
        const SeoBreadcrumb(label: 'Services', path: RouteNames.publicServices),
        SeoBreadcrumb(label: city.name, path: SeoRouteGuard.citiesHubPath()),
        SeoBreadcrumb(
          label: service.name,
          path: SeoRouteGuard.landingPath(city.slug, service.slug),
        ),
      ];

  static Map<String, dynamic> _jsonLd(
    SeoCity city,
    SeoService service,
    String path,
    List<SeoFaqItem> faq,
    List<SeoBreadcrumb> breadcrumbs,
  ) {
    final url = SiteSeoConfig.absolute(path);
    final serviceType = service.schemaServiceType ?? 'Service';

    return {
      '@context': 'https://schema.org',
      '@graph': [
        {
          '@type': 'BreadcrumbList',
          'itemListElement': [
            for (var i = 0; i < breadcrumbs.length; i++)
              {
                '@type': 'ListItem',
                'position': i + 1,
                'name': breadcrumbs[i].label,
                'item': SiteSeoConfig.absolute(breadcrumbs[i].path),
              },
          ],
        },
        {
          '@type': 'LocalBusiness',
          'name': 'D.G.Yard — ${city.name}',
          'url': SiteSeoConfig.baseUrl,
          'image': SiteSeoConfig.defaultImage,
          'telephone': '+918298955009',
          'email': 'info@dgyard.com',
          'address': {
            '@type': 'PostalAddress',
            'addressLocality': city.name,
            'addressRegion': city.state,
            'addressCountry': 'IN',
          },
          if (city.latitude != null && city.longitude != null)
            'geo': {
              '@type': 'GeoCoordinates',
              'latitude': city.latitude,
              'longitude': city.longitude,
            },
          'areaServed': {
            '@type': 'City',
            'name': city.name,
          },
        },
        {
          '@type': serviceType,
          'name': '${service.name} in ${city.name}',
          'description': service.shortDescription ?? service.description ?? service.name,
          'url': url,
          'provider': {
            '@type': 'Organization',
            'name': SiteSeoConfig.siteName,
            'url': SiteSeoConfig.baseUrl,
          },
          'areaServed': {
            '@type': 'City',
            'name': '${city.name}, ${city.state}',
          },
        },
        if (faq.isNotEmpty)
          {
            '@type': 'FAQPage',
            'mainEntity': [
              for (final item in faq)
                {
                  '@type': 'Question',
                  'name': item.question,
                  'acceptedAnswer': {
                    '@type': 'Answer',
                    'text': item.answer,
                  },
                },
            ],
          },
      ],
    };
  }
}

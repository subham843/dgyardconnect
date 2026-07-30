import '../../core/constants/route_names.dart';
import 'site_seo_config.dart';
import 'web_seo_meta.dart';

/// Static SEO definitions and path classification for public routes.
abstract final class PublicSeoRegistry {
  PublicSeoRegistry._();

  static const _orgJsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        'name': SiteSeoConfig.siteName,
        'url': SiteSeoConfig.baseUrl,
        'logo': SiteSeoConfig.defaultImage,
        'description': SiteSeoConfig.defaultDescription,
      },
      {
        '@type': 'LocalBusiness',
        'name': 'D.G.Yard',
        'url': SiteSeoConfig.baseUrl,
        'image': SiteSeoConfig.defaultImage,
        'description':
            'CCTV, networking, and IT infrastructure solutions with dealer dispatch and public ecommerce store.',
        'areaServed': 'IN',
        'address': {
          '@type': 'PostalAddress',
          'streetAddress': 'Piska More, Ratu Road',
          'addressLocality': 'Ranchi',
          'postalCode': '834005',
          'addressRegion': 'Jharkhand',
          'addressCountry': 'IN',
        },
        'telephone': '+918298955009',
        'email': 'info@dgyard.com',
      },
    ],
  };

  static WebSeoMeta home() => WebSeoMeta(
        title: '${SiteSeoConfig.siteName} — ${SiteSeoConfig.tagline}',
        description: SiteSeoConfig.defaultDescription,
        canonicalPath: RouteNames.publicHome,
        jsonLd: _orgJsonLd,
      );

  static WebSeoMeta store() => WebSeoMeta(
        title: 'IT & Security Store | ${SiteSeoConfig.siteName}',
        description:
            'Shop CCTV cameras, networking gear, computers, biometrics, and security products with transparent pricing from D.G.Yard.',
        canonicalPath: RouteNames.publicStore,
        jsonLd: {
          '@context': 'https://schema.org',
          '@type': 'CollectionPage',
          'name': 'D.G.Yard Store',
          'url': SiteSeoConfig.absolute(RouteNames.publicStore),
          'description':
              'Public ecommerce catalog for security, networking, and IT products.',
          'isPartOf': {'@type': 'WebSite', 'url': SiteSeoConfig.baseUrl},
        },
      );

  static WebSeoMeta storeCategory(String slug, {String? name, String? description, String? image}) {
    final titleName = (name != null && name.trim().isNotEmpty) ? name.trim() : slug;
    return WebSeoMeta(
      title: '$titleName | Store | ${SiteSeoConfig.siteName}',
      description: (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : 'Browse $titleName products — CCTV, networking, and IT solutions from D.G.Yard.',
      canonicalPath: RouteNames.publicStoreCategory(slug),
      imageUrl: image,
      jsonLd: {
        '@context': 'https://schema.org',
        '@type': 'CollectionPage',
        'name': titleName,
        'url': SiteSeoConfig.absolute(RouteNames.publicStoreCategory(slug)),
      },
    );
  }

  static WebSeoMeta product({
    required String slug,
    required String name,
    String? description,
    String? image,
    String? sku,
    double? price,
    String? brand,
  }) {
    final desc = (description != null && description.trim().isNotEmpty)
        ? description.trim()
        : 'Buy $name online from D.G.Yard — CCTV, networking, and IT infrastructure products.';
    return WebSeoMeta(
      title: '$name | ${SiteSeoConfig.siteName}',
      description: desc,
      canonicalPath: '/product/$slug',
      imageUrl: image,
      ogType: 'product',
      jsonLd: {
        '@context': 'https://schema.org',
        '@type': 'Product',
        'name': name,
        'url': SiteSeoConfig.absolute('/product/$slug'),
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        if (brand != null && brand.isNotEmpty) 'brand': {'@type': 'Brand', 'name': brand},
        if (image != null && image.isNotEmpty) 'image': image,
        if (price != null && price > 0)
          'offers': {
            '@type': 'Offer',
            'priceCurrency': 'INR',
            'price': price.toStringAsFixed(0),
            'availability': 'https://schema.org/InStock',
            'url': SiteSeoConfig.absolute('/product/$slug'),
          },
      },
    );
  }

  static WebSeoMeta calculatorList() => WebSeoMeta(
        title: 'Price Calculator | ${SiteSeoConfig.siteName}',
        description:
            'Instant price calculator for CCTV, PC assembly, networking and more. Select specs, get live product pricing and save quotations on D.G.Yard Connect.',
        canonicalPath: RouteNames.publicCalculatorList,
        jsonLd: {
          '@context': 'https://schema.org',
          '@type': 'WebApplication',
          'name': 'D.G.Yard Price Calculator',
          'url': SiteSeoConfig.absolute(RouteNames.publicCalculatorList),
          'applicationCategory': 'BusinessApplication',
          'operatingSystem': 'Web',
          'description':
              'Configurable product price calculator — admin-defined categories and questions, live catalog pricing for users.',
        },
      );

  static WebSeoMeta calculatorDetail({
    required String slug,
    required String name,
    String? description,
    String? image,
  }) {
    return WebSeoMeta(
      title: '$name Price Calculator | ${SiteSeoConfig.siteName}',
      description: (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : 'Calculate live prices for $name — select specifications and get an instant product estimate on D.G.Yard Connect.',
      canonicalPath: '/calculator/$slug',
      imageUrl: image,
      jsonLd: {
        '@context': 'https://schema.org',
        '@type': 'WebApplication',
        'name': '$name Price Calculator',
        'url': SiteSeoConfig.absolute('/calculator/$slug'),
        'applicationCategory': 'BusinessApplication',
        'operatingSystem': 'Web',
      },
    );
  }

  static WebSeoMeta blogDetail({
    required String slug,
    required String title,
    String? description,
    String? image,
  }) =>
      WebSeoMeta(
        title: '$title | ${SiteSeoConfig.siteName}',
        description: description ?? title,
        canonicalPath: '/blog/$slug',
        imageUrl: image,
        jsonLd: {
          '@context': 'https://schema.org',
          '@type': 'BlogPosting',
          'headline': title,
          'url': SiteSeoConfig.absolute('/blog/$slug'),
          if (image != null) 'image': image,
        },
      );

  static WebSeoMeta servicesInstallations() => WebSeoMeta(
        title: 'Installation Services — Select City | ${SiteSeoConfig.siteName}',
        description:
            'Choose a service and select your city for localized CCTV, networking, fire alarm, and IT installation pages across India.',
        canonicalPath: RouteNames.publicServicesInstallations,
      );

  static WebSeoMeta servicesCities() => WebSeoMeta(
        title: 'Service Cities — Installation Coverage | ${SiteSeoConfig.siteName}',
        description:
            'Browse D.G.Yard installation service cities across India. CCTV, networking, fire alarm, and IT infrastructure by state and city.',
        canonicalPath: RouteNames.publicServicesCities,
      );

  static WebSeoMeta services() => WebSeoMeta(
        title: 'Services — CCTV, IT, Networking & Digital | ${SiteSeoConfig.siteName}',
        description:
            'End-to-end CCTV installation, networking, software development, digital marketing, home automation, and AMC support across India.',
        canonicalPath: RouteNames.publicServices,
      );

  static WebSeoMeta connect() => WebSeoMeta(
        title: 'DG Yard Connect — Dealer & Technician Dispatch | ${SiteSeoConfig.siteName}',
        description:
            'Post jobs, receive bids, track technicians, and manage payouts on the D.G.Yard Connect field-service platform.',
        canonicalPath: RouteNames.publicConnect,
      );

  static WebSeoMeta about() => WebSeoMeta(
        title: 'About D.G.Yard | ${SiteSeoConfig.siteName}',
        description:
            'Learn about D.G.Yard — India\'s technology partner for security, IT infrastructure, smart automation, and field-service dispatch.',
        canonicalPath: RouteNames.publicAbout,
      );

  static WebSeoMeta contact() => WebSeoMeta(
        title: 'Contact D.G.Yard | ${SiteSeoConfig.siteName}',
        description:
            'Reach D.G.Yard in Ranchi for CCTV, networking, IT projects, store orders, and Connect platform support.',
        canonicalPath: RouteNames.publicContact,
        jsonLd: {
          '@context': 'https://schema.org',
          '@type': 'ContactPage',
          'name': 'Contact D.G.Yard',
          'url': SiteSeoConfig.absolute(RouteNames.publicContact),
        },
      );

  static WebSeoMeta support() => WebSeoMeta(
        title: 'Support & Help Center | ${SiteSeoConfig.siteName}',
        description:
            'Get help with store orders, Connect jobs, calculators, and technical support from the D.G.Yard team.',
        canonicalPath: RouteNames.supportHome,
      );

  static WebSeoMeta privacyPolicy() => WebSeoMeta(
        title: 'Privacy Policy | ${SiteSeoConfig.siteName}',
        description: 'How D.G.Yard collects, uses, and protects your personal data.',
        canonicalPath: RouteNames.webPrivacyPolicy,
        index: true,
        follow: true,
      );

  static WebSeoMeta dataDeletion() => WebSeoMeta(
        title: 'Data Deletion | ${SiteSeoConfig.siteName}',
        description: 'Request deletion of your D.G.Yard Connect account and associated data.',
        canonicalPath: RouteNames.webDataDeletion,
        index: true,
        follow: true,
      );

  static WebSeoMeta softNotFound({
    required String title,
    required String path,
    String? description,
  }) =>
      WebSeoMeta(
        title: '$title | ${SiteSeoConfig.siteName}',
        description: description ?? 'The page you requested could not be found on D.G.Yard.',
        canonicalPath: path,
        index: false,
        follow: true,
      );

  /// Applies registry SEO for known static paths; returns null for dynamic routes.
  static WebSeoMeta? forPath(String rawPath) {
    final path = SiteSeoConfig.normalizePath(rawPath);
    switch (path) {
      case RouteNames.publicHome:
        return home();
      case RouteNames.publicStore:
        return store();
      case RouteNames.publicCalculatorList:
        return calculatorList();
      case RouteNames.publicServices:
        return services();
      case RouteNames.publicServicesInstallations:
        return servicesInstallations();
      case RouteNames.publicServicesCities:
        return servicesCities();
      case RouteNames.publicConnect:
        return connect();
      case RouteNames.publicAbout:
        return about();
      case RouteNames.publicContact:
        return contact();
      case RouteNames.supportHome:
        return support();
      case RouteNames.webPrivacyPolicy:
        return privacyPolicy();
      case RouteNames.webDataDeletion:
        return dataDeletion();
      default:
        if (path.startsWith('/store/category/')) return null;
        if (path.startsWith('/product/')) return null;
        if (path.startsWith('/calculator/')) return null;
        if (path.startsWith('/blog/')) return null;
        // Dynamic /{city}/{service} — page sets its own SEO via WebSeoScope.
        final parts = path.split('/').where((p) => p.isNotEmpty).toList();
        if (parts.length == 2) return null;
        return null;
    }
  }

  static bool isPrivatePath(String rawPath) {
    final path = SiteSeoConfig.normalizePath(rawPath);
    const privatePrefixes = <String>[
      '/admin',
      '/dealer',
      '/technician',
      '/login',
      '/phone',
      '/otp',
      '/register',
      '/settings',
      '/legal',
      '/marketplace',
      '/app/',
      '/shop',
      '/walkthrough',
      '/service-area',
      '/role-choice',
      '/pending-approval',
      '/success',
      '/splash',
      '/verify',
      '/rate',
      '/chat',
      '/offers',
    ];
    for (final prefix in privatePrefixes) {
      if (path == prefix || path.startsWith('$prefix/')) return true;
    }
    if (path == RouteNames.publicCart || path == RouteNames.login) return true;
    return false;
  }

  static WebSeoMeta metaForPrivatePath(String path) {
    if (path.startsWith('/admin')) {
      return WebSeoMeta.noIndex(
        title: 'Admin | ${SiteSeoConfig.siteName}',
        canonicalPath: path,
      );
    }
    if (path == RouteNames.publicCart) {
      return WebSeoMeta.noIndex(
        title: 'Shopping Bag | ${SiteSeoConfig.siteName}',
        canonicalPath: RouteNames.publicCart,
      );
    }
    return WebSeoMeta.noIndex(
      title: SiteSeoConfig.siteName,
      canonicalPath: path,
    );
  }
}

/// Canonical production site URL for SEO (sitemap, canonical, Open Graph).
abstract final class SiteSeoConfig {
  SiteSeoConfig._();

  static const String siteHost = 'dgyard.com';

  static const String baseUrl = String.fromEnvironment(
    'SITE_SEO_BASE_URL',
    defaultValue: 'https://dgyard.com',
  );

  static const String siteName = 'D.G.Yard Connect';

  static const String tagline = 'Digital | Smart | Secure Living';

  static const String defaultDescription =
      'Enterprise security & IT solutions, public store, BOQ calculators, and the Connect dispatch platform for dealers and technicians across India.';

  static const String defaultImage = '$baseUrl/icons/Icon-512.png';

  static String absolute(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalized';
  }

  static String normalizePath(String path) {
    if (path.isEmpty || path == '/') return '/';
    var p = path;
    if (!p.startsWith('/')) p = '/$p';
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}

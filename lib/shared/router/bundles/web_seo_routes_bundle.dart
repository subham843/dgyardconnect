import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../features/seo/public/pages/seo_blog_detail_page.dart';
import '../../../features/seo/public/pages/seo_landing_page_screen.dart';
import '../../../features/seo/public/pages/services_cities_page.dart';
import '../../../features/seo/public/pages/services_hub_page.dart';
import '../../../features/seo/services/seo_route_guard.dart';

/// Deferred SEO / services dynamic routes bundle.
Widget buildSeoScreen(GoRouterState state) {
  final path = state.uri.path;

  if (path == RouteNames.publicServicesInstallations) {
    return const ServicesHubPage();
  }
  if (path == RouteNames.publicServicesCities) {
    return const ServicesCitiesPage();
  }
  if (path.startsWith('/blog/')) {
    return SeoBlogDetailPage(slug: state.pathParameters['slug'] ?? '');
  }

  final citySlug = state.pathParameters['citySlug'] ?? '';
  final serviceSlug = state.pathParameters['serviceSlug'] ?? '';
  if (SeoRouteGuard.isPotentialLandingPath(citySlug, serviceSlug)) {
    return SeoLandingPageScreen(citySlug: citySlug, serviceSlug: serviceSlug);
  }

  return const SizedBox.shrink();
}

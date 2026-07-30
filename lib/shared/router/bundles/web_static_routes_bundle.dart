import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/seo/public_seo_registry.dart';
import '../../../core/seo/web_seo_binder.dart';
import '../../../features/web/data_deletion_screen.dart';
import '../../../features/web/privacy_policy_screen.dart';
import '../../../features/web_public/pages/calculator/calculator_page.dart';
import '../../../features/web_public/pages/static/about_page.dart';
import '../../../features/web_public/pages/static/connect_page.dart';
import '../../../features/web_public/pages/static/contact_page.dart';
import '../../../features/web_public/pages/static/public_support_page.dart';
import '../../../features/web_public/pages/static/services_page.dart';

/// Deferred marketing / calculator / legal static pages.
Widget buildStaticScreen(GoRouterState state) {
  switch (state.uri.path) {
    case RouteNames.publicServices:
      return const ServicesPage();
    case RouteNames.publicConnect:
      return const ConnectPage();
    case RouteNames.publicAbout:
      return const AboutPage();
    case RouteNames.publicContact:
      return const ContactPage();
    case RouteNames.publicCalculatorList:
      return const CalculatorPage();
    case RouteNames.webPrivacyPolicy:
      return const PrivacyPolicyScreen();
    case RouteNames.webDataDeletion:
      return const DataDeletionScreen();
    case RouteNames.supportHome:
      return const PublicSupportPage();
    default:
      if (state.uri.path.startsWith('/calculator/')) {
        return CalculatorPage(
          initialFamilySlug: state.pathParameters['slug'] ?? '',
        );
      }
      return const _UnknownPublicRoute();
  }
}

class _UnknownPublicRoute extends StatelessWidget {
  const _UnknownPublicRoute();

  @override
  Widget build(BuildContext context) {
    return WebSeoScope(
      meta: PublicSeoRegistry.softNotFound(
        title: 'Page not found',
        path: GoRouterState.of(context).uri.path,
      ),
      child: const Scaffold(
        body: Center(child: Text('Page not found')),
      ),
    );
  }
}

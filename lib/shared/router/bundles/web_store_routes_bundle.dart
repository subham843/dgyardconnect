import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/seo/public_seo_registry.dart';
import '../../../core/seo/web_seo_binder.dart';
import '../../../features/web_public/pages/shop/product_detail_page.dart';
import '../../../features/web_public/pages/shop/store_checkout_page.dart';
import '../../../features/web_public/pages/shop/store_cart_page.dart';
import '../../../features/web_public/pages/shop/store_category_page.dart';
import '../../../features/web_public/pages/shop/store_page.dart';

/// Deferred public store bundle — Supabase catalog + cart (not on home cold start).
Widget buildStoreScreen(GoRouterState state) {
  final path = state.uri.path;
  final qp = state.uri.queryParameters;

  if (path == RouteNames.publicStore) {
    return StorePage(
      key: ValueKey('store-${state.uri.query}'),
      categorySlug: qp['category'],
      subcategorySlug: qp['subcategory'],
      brandSlug: qp['brand'],
      initialQuery: qp['q'],
    );
  }
  if (path.startsWith('/store/category/')) {
    return StoreCategoryPage(
      categorySlug: state.pathParameters['slug'] ?? '',
    );
  }
  if (path == RouteNames.publicCart) {
    return const StoreCartPage();
  }
  if (path == RouteNames.publicCheckout) {
    return const StoreCheckoutPage();
  }
  if (path.startsWith('/product/')) {
    return ProductDetailPage(
      productSlug: state.pathParameters['slug'] ?? '',
    );
  }

  return WebSeoScope(
    meta: PublicSeoRegistry.softNotFound(
      title: 'Page not found',
      path: path,
    ),
    child: const Scaffold(
      body: Center(child: Text('Unknown store route')),
    ),
  );
}

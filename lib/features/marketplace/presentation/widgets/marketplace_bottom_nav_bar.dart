import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';

class MarketplaceBottomNavBar extends StatelessWidget {
  const MarketplaceBottomNavBar({super.key});

  int _indexForLocation(String location) {
    if (location.startsWith(RouteNames.marketplaceHome)) return 0;
    if (location.startsWith(RouteNames.marketplaceSellerHub)) return 1;
    if (location.startsWith(RouteNames.marketplaceSearch)) return 2;
    if (location.startsWith(RouteNames.marketplaceOrders)) return 3;
    if (location.startsWith(RouteNames.marketplaceCart)) return 4;
    if (location.startsWith('/marketplace/category')) return 0; // Categories are accessed from Home chips.
    return 0; // default: Home
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RouteNames.marketplaceHome);
        return;
      case 1:
        context.push(RouteNames.marketplaceSellerHub);
        return;
      case 2:
        context.push(RouteNames.marketplaceSearch);
        return;
      case 3:
        context.push(RouteNames.marketplaceOrders);
        return;
      case 4:
        context.push(RouteNames.marketplaceCart);
        return;
    }
  }

  Widget _coloredIcon(IconData icon, Color color, {bool selected = false}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: selected ? 0.30 : 0.20)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _indexForLocation(loc);
    const cHome = Color(0xFF2563EB);
    const cSell = Color(0xFF7C3AED);
    const cSearch = Color(0xFF059669);
    const cOrders = Color(0xFFF59E0B);
    const cCart = Color(0xFFDB2777);

    return NavigationBar(
      height: 70,
      selectedIndex: idx,
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) => _go(context, i),
      destinations: [
        NavigationDestination(
          icon: _coloredIcon(Icons.home_outlined, cHome),
          selectedIcon: _coloredIcon(Icons.home_rounded, cHome, selected: true),
          label: 'Home',
        ),
        NavigationDestination(
          icon: _coloredIcon(Icons.storefront_outlined, cSell),
          selectedIcon: _coloredIcon(Icons.storefront_rounded, cSell, selected: true),
          label: 'Sell',
        ),
        NavigationDestination(
          icon: _coloredIcon(Icons.search_rounded, cSearch),
          selectedIcon: _coloredIcon(Icons.search_rounded, cSearch, selected: true),
          label: 'Search',
        ),
        NavigationDestination(
          icon: _coloredIcon(Icons.receipt_long_outlined, cOrders),
          selectedIcon: _coloredIcon(Icons.receipt_long_rounded, cOrders, selected: true),
          label: 'Orders',
        ),
        NavigationDestination(
          icon: _coloredIcon(Icons.shopping_cart_outlined, cCart),
          selectedIcon: _coloredIcon(Icons.shopping_cart_rounded, cCart, selected: true),
          label: 'Cart',
        ),
      ],
    );
  }
}


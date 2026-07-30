import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../data/shop_catalog_repository.dart';
import '../domain/shop_category.dart';

class ShopHomeScreen extends StatefulWidget {
  const ShopHomeScreen({super.key});

  @override
  State<ShopHomeScreen> createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends State<ShopHomeScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _categories = await _repo.listCategories();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DG Yard Shop'),
        actions: [
          IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => context.push(RouteNames.shopCart)),
          IconButton(icon: const Icon(Icons.receipt_long_outlined), onPressed: () => context.push(RouteNames.shopOrders)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('Catalog coming soon'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.2),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final c = _categories[i];
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(RouteNames.shopCategory(c.id)),
                        child: Center(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Slivers for dealer home shop tab embedding.
class ShopHomeSlivers {
  ShopHomeSlivers._();

  static List<Widget> build(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Buy equipment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: () => context.push(RouteNames.shopHome),
                child: const Text('Open shop'),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 320,
          child: ShopHomeScreen(),
        ),
      ),
    ];
  }
}

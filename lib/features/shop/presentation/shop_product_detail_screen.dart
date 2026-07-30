import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/shop_catalog_repository.dart';
import '../domain/shop_product.dart';
import '../state/shop_cart_controller.dart';

class ShopProductDetailScreen extends StatefulWidget {
  const ShopProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ShopProductDetailScreen> createState() => _ShopProductDetailScreenState();
}

class _ShopProductDetailScreenState extends State<ShopProductDetailScreen> {
  final _repo = ShopCatalogRepository();
  ShopProduct? _product;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _product = await _repo.getProduct(widget.productId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    return Scaffold(
      appBar: AppBar(title: Text(p?.name ?? 'Product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? const Center(child: Text('Not found'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                      Text('SKU: ${p.sku}'),
                      Text('₹${p.basePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      if (p.description != null) ...[const SizedBox(height: 12), Text(p.description!)],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await context.read<ShopCartController>().addProduct(p.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
                            }
                          },
                          child: const Text('Add to cart'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/marketplace_catalog_repository.dart';
import 'widgets/marketplace_product_card.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceSearchScreen extends StatefulWidget {
  const MarketplaceSearchScreen({super.key});

  @override
  State<MarketplaceSearchScreen> createState() => _MarketplaceSearchScreenState();
}

class _MarketplaceSearchScreenState extends State<MarketplaceSearchScreen> {
  final _repo = MarketplaceCatalogRepository();
  final _controller = TextEditingController();
  String _q = '';
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarketplacePremiumShell(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search catalog',
            border: InputBorder.none,
            isDense: true,
          ),
          style: const TextStyle(color: AppColors.textOnPrimary),
          cursorColor: AppColors.textOnPrimary,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _repo.watchLiveProducts(
                limit: 120,
                excludeSellerUid: FirebaseAuth.instance.currentUser?.uid,
              ),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final filtered = _q.isEmpty
                    ? all
                    : all
                        .where((p) =>
                            p.title.toLowerCase().contains(_q) ||
                            p.description.toLowerCase().contains(_q) ||
                            p.categoryId.toLowerCase().contains(_q))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No matches',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => MarketplaceProductCard(product: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

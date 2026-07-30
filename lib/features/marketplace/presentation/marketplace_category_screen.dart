import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/marketplace_catalog_repository.dart';
import '../data/marketplace_taxonomy_repository.dart';
import '../domain/marketplace_taxonomy.dart';
import 'widgets/marketplace_product_card.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceCategoryScreen extends StatefulWidget {
  const MarketplaceCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<MarketplaceCategoryScreen> createState() => _MarketplaceCategoryScreenState();
}

class _MarketplaceCategoryScreenState extends State<MarketplaceCategoryScreen> {
  String? _subFilterId;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceCatalogRepository();
    final tax = MarketplaceTaxonomyRepository();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<MarketplaceSubcategoryNode>>(
          stream: tax.watchSubcategories(widget.categoryId, activeOnly: true),
          builder: (context, subSnap) {
            final subs = subSnap.data ?? [];
            if (subs.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _subFilterId == null,
                      onSelected: (_) => setState(() => _subFilterId = null),
                    ),
                    const SizedBox(width: 8),
                    ...subs.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s.name),
                          selected: _subFilterId == s.id,
                          onSelected: (_) => setState(() => _subFilterId = s.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Expanded(
          child: StreamBuilder(
            stream: repo.watchLiveProductsByCategory(
              widget.categoryId,
              limit: 120,
              excludeSellerUid: FirebaseAuth.instance.currentUser?.uid,
            ),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var list = snap.data!;
              if (_subFilterId != null) {
                list = list.where((p) => p.subcategoryId == _subFilterId).toList();
              }
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No products in this category yet.',
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
                itemCount: list.length,
                itemBuilder: (context, i) => MarketplaceProductCard(product: list[i]),
              );
            },
          ),
        ),
      ],
    );

    return MarketplacePremiumShell(
      appBar: AppBar(
        title: StreamBuilder<List<MarketplaceCategoryNode>>(
          stream: tax.watchCategories(activeOnly: true),
          builder: (context, snap) {
            String title = widget.categoryId;
            for (final c in snap.data ?? []) {
              if (c.id == widget.categoryId && c.name.trim().isNotEmpty) {
                title = c.name.trim();
                break;
              }
            }
            return Text(title);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(child: body),
        ],
      ),
    );
  }
}

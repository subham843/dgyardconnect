import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_taxonomy_repository.dart';
import '../../marketplace/domain/marketplace_taxonomy.dart';

/// Admin: subcategories under one category (e.g. UTP, Fiber under Cable).
class AdminMarketplaceSubcategoriesScreen extends StatelessWidget {
  const AdminMarketplaceSubcategoriesScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceTaxonomyRepository();
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<MarketplaceCategoryNode>>(
          stream: repo.watchCategoriesForAdmin(),
          builder: (context, snap) {
            var title = categoryId;
            final cats = snap.data;
            if (cats != null) {
              for (final c in cats) {
                if (c.id == categoryId) {
                  title = c.name;
                  break;
                }
              }
            }
            return Text(title);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSubDialog(context, repo),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Subcategory'),
      ),
      body: StreamBuilder<List<MarketplaceSubcategoryNode>>(
        stream: repo.watchSubcategories(categoryId, activeOnly: false),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Add subcategories sellers will pick from (e.g. UTP, Fiber). Then open one to define features like "Cable type" with values CAT5e, CAT6.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = list[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(s.active ? 'Active' : 'Hidden'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _editSubDialog(context, repo, s),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: s.active ? 'Hide' : 'Show',
                        onPressed: () => repo.setSubcategoryActive(categoryId, s.id, !s.active),
                        icon: Icon(s.active ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => context.push(RouteNames.adminMarketplaceTaxonomyAttrs(categoryId, s.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addSubDialog(BuildContext context, MarketplaceTaxonomyRepository repo) async {
    final nameCtrl = TextEditingController();
    final sortCtrl = TextEditingController(text: '0');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('New subcategory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. UTP, Fiber optic'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final n = nameCtrl.text.trim();
      if (n.isEmpty) return;
      final so = int.tryParse(sortCtrl.text.trim()) ?? 0;
      await repo.createSubcategory(categoryId: categoryId, name: n, sortOrder: so);
    } finally {
      nameCtrl.dispose();
      sortCtrl.dispose();
    }
  }

  Future<void> _editSubDialog(
    BuildContext context,
    MarketplaceTaxonomyRepository repo,
    MarketplaceSubcategoryNode s,
  ) async {
    final nameCtrl = TextEditingController(text: s.name);
    final sortCtrl = TextEditingController(text: '${s.sortOrder}');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit subcategory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final n = nameCtrl.text.trim();
      if (n.isEmpty) return;
      final so = int.tryParse(sortCtrl.text.trim());
      await repo.updateSubcategory(categoryId, s.id, name: n, sortOrder: so);
    } finally {
      nameCtrl.dispose();
      sortCtrl.dispose();
    }
  }
}

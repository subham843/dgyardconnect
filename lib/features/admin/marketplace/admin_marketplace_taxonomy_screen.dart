import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../marketplace/data/marketplace_taxonomy_repository.dart';
import '../../marketplace/domain/marketplace_taxonomy.dart';

/// Admin: top-level marketplace categories (e.g. Cable).
class AdminMarketplaceTaxonomyScreen extends StatelessWidget {
  const AdminMarketplaceTaxonomyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = MarketplaceTaxonomyRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Product categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCategoryDialog(context, repo),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Category'),
      ),
      body: StreamBuilder<List<MarketplaceCategoryNode>>(
        stream: repo.watchCategoriesForAdmin(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No categories yet. Add "Cable", "Tools", etc. Then open a category to add subcategories (UTP, Fiber) and attribute options (e.g. cable type: CAT6).',
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
              final c = list[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.active ? 'Active · order ${c.sortOrder}' : 'Hidden'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _editCategoryDialog(context, repo, c),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: c.active ? 'Hide' : 'Show',
                        onPressed: () => repo.setCategoryActive(c.id, !c.active),
                        icon: Icon(c.active ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => context.push(RouteNames.adminMarketplaceTaxonomySubs(c.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addCategoryDialog(BuildContext context, MarketplaceTaxonomyRepository repo) async {
    final nameCtrl = TextEditingController();
    final sortCtrl = TextEditingController(text: '0');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('New category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Cable'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sort order',
                  helperText: 'Lower numbers appear first',
                ),
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
      await repo.createCategory(name: n, sortOrder: so);
    } finally {
      nameCtrl.dispose();
      sortCtrl.dispose();
    }
  }

  Future<void> _editCategoryDialog(
    BuildContext context,
    MarketplaceTaxonomyRepository repo,
    MarketplaceCategoryNode c,
  ) async {
    final nameCtrl = TextEditingController(text: c.name);
    final sortCtrl = TextEditingController(text: '${c.sortOrder}');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit category'),
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
      await repo.updateCategory(c.id, name: n, sortOrder: so);
    } finally {
      nameCtrl.dispose();
      sortCtrl.dispose();
    }
  }
}

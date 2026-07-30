import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/seo_admin_repository.dart';
import '../domain/seo_blog_post.dart';

class AdminSeoBlogPostsScreen extends StatefulWidget {
  const AdminSeoBlogPostsScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminSeoBlogPostsScreen> createState() => _AdminSeoBlogPostsScreenState();
}

class _AdminSeoBlogPostsScreenState extends State<AdminSeoBlogPostsScreen> {
  final _repo = SeoAdminRepository();
  List<SeoBlogPost> _items = [];
  bool _loading = true;

  void _go(String route) {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
    } else {
      context.push(route);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listBlogPosts();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final b = _items[i];
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '/blog/${b.slug} · cities: ${b.citySlugs.join(', ')} · services: ${b.serviceSlugs.join(', ')}${b.isActive ? '' : ' · hidden'}',
                ),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => _go(RouteNames.adminSeoBlogEdit(b.id)),
              );
            },
          );

    return AdminEmbeddedScaffold(
      title: 'SEO Blog Posts',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _go(RouteNames.adminSeoBlogCreate),
        icon: const Icon(Icons.add),
        label: const Text('Add post'),
      ),
      body: body,
    );
  }
}

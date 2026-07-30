import 'package:flutter/material.dart';

import '../../shop/data/supabase_repository_base.dart';
import '../data/seo_admin_repository.dart';
import '../domain/seo_blog_post.dart';
import 'widgets/seo_image_url_field.dart';

class AdminSeoBlogEditorScreen extends StatefulWidget {
  const AdminSeoBlogEditorScreen({super.key, this.blogId});

  final String? blogId;

  @override
  State<AdminSeoBlogEditorScreen> createState() => _AdminSeoBlogEditorScreenState();
}

class _AdminSeoBlogEditorScreenState extends State<AdminSeoBlogEditorScreen> {
  final _repo = SeoAdminRepository();
  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _excerpt = TextEditingController();
  final _body = TextEditingController();
  final _heroImage = TextEditingController();
  final _author = TextEditingController(text: 'D.G.Yard');
  final _citySlugs = TextEditingController();
  final _serviceSlugs = TextEditingController();
  final _seoTitle = TextEditingController();
  final _metaDescription = TextEditingController();
  final _sortOrder = TextEditingController(text: '0');

  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_autoSlug);
    _load();
  }

  void _autoSlug() {
    if (widget.blogId != null) return;
    _slug.text = SupabaseRepositoryBase.slugify(_title.text);
  }

  Future<void> _load() async {
    if (widget.blogId != null) {
      final post = await _repo.getBlogPost(widget.blogId!);
      if (post != null) {
        _title.text = post.title;
        _slug.text = post.slug;
        _excerpt.text = post.excerpt ?? '';
        _body.text = post.body ?? '';
        _heroImage.text = post.heroImageUrl ?? '';
        _author.text = post.authorName;
        _citySlugs.text = post.citySlugs.join(', ');
        _serviceSlugs.text = post.serviceSlugs.join(', ');
        _seoTitle.text = post.seoTitle ?? '';
        _metaDescription.text = post.metaDescription ?? '';
        _sortOrder.text = post.sortOrder.toString();
        _isActive = post.isActive;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _excerpt.dispose();
    _body.dispose();
    _heroImage.dispose();
    _author.dispose();
    _citySlugs.dispose();
    _serviceSlugs.dispose();
    _seoTitle.dispose();
    _metaDescription.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  List<String> _csv(String raw) =>
      raw.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final post = SeoBlogPost(
        id: widget.blogId ?? '',
        title: _title.text.trim(),
        slug: _slug.text.trim(),
        excerpt: _excerpt.text.trim().isEmpty ? null : _excerpt.text.trim(),
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        heroImageUrl: _heroImage.text.trim().isEmpty ? null : _heroImage.text.trim(),
        authorName: _author.text.trim().isEmpty ? 'D.G.Yard' : _author.text.trim(),
        citySlugs: _csv(_citySlugs.text),
        serviceSlugs: _csv(_serviceSlugs.text),
        seoTitle: _seoTitle.text.trim().isEmpty ? null : _seoTitle.text.trim(),
        metaDescription: _metaDescription.text.trim().isEmpty ? null : _metaDescription.text.trim(),
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
        isActive: _isActive,
        publishedAt: DateTime.now(),
      );
      await _repo.upsertBlogPost(post, id: widget.blogId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.blogId == null ? 'Add blog post' : 'Edit blog post'),
        actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _excerpt, decoration: const InputDecoration(labelText: 'Excerpt', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(controller: _body, decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()), maxLines: 12),
                const SizedBox(height: 12),
                SeoImageUrlField(label: 'Hero image URL', controller: _heroImage),
                TextFormField(controller: _author, decoration: const InputDecoration(labelText: 'Author', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _citySlugs,
                  decoration: const InputDecoration(
                    labelText: 'City slugs (comma-separated)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g. ranchi, patna — shows in Related blogs on city pages',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _serviceSlugs,
                  decoration: const InputDecoration(
                    labelText: 'Service slugs (comma-separated)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g. cctv-installation, networking',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _seoTitle, decoration: const InputDecoration(labelText: 'SEO title', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _metaDescription, decoration: const InputDecoration(labelText: 'Meta description', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(controller: _sortOrder, decoration: const InputDecoration(labelText: 'Sort order', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                SwitchListTile(title: const Text('Active / published'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                Text(
                  'Public URL: /blog/${_slug.text.isEmpty ? 'your-slug' : _slug.text}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

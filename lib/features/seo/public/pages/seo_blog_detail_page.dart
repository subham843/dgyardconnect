import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/seo/public_seo_registry.dart';
import '../../../../core/seo/site_seo_config.dart';
import '../../../../core/seo/web_seo_binder.dart';
import '../../../../core/seo/web_seo_meta.dart';
import '../../../web_public/v2/v2_font_styles.dart';
import '../../../web_public/v2/v2_colors.dart';
import '../../../web_public/v2/v2_tokens.dart' show V2;
import '../../../web_public/v2/widgets/v2_footer.dart';
import '../../../web_public/widgets/public_floating_menu.dart';
import '../../data/public_seo_repository.dart';
import '../../domain/seo_blog_post.dart';

class SeoBlogDetailPage extends StatefulWidget {
  const SeoBlogDetailPage({super.key, required this.slug});

  final String slug;

  @override
  State<SeoBlogDetailPage> createState() => _SeoBlogDetailPageState();
}

class _SeoBlogDetailPageState extends State<SeoBlogDetailPage> {
  final _repo = PublicSeoRepository();
  SeoBlogPost? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final post = await _repo.getBlogBySlug(widget.slug);
    if (!mounted) return;
    setState(() {
      _post = post;
      _loading = false;
    });
  }

  WebSeoMeta _seoMeta() {
    final path = RouteNames.publicBlog(widget.slug);
    if (!_loading && _post == null) {
      return PublicSeoRegistry.softNotFound(title: 'Article not found', path: path);
    }
    final p = _post!;
    return WebSeoMeta(
      title: p.seoTitle?.trim().isNotEmpty == true ? p.seoTitle!.trim() : '${p.title} | ${SiteSeoConfig.siteName}',
      description: p.metaDescription?.trim().isNotEmpty == true
          ? p.metaDescription!.trim()
          : (p.excerpt ?? p.title),
      canonicalPath: path,
      imageUrl: p.heroImageUrl,
      jsonLd: {
        '@context': 'https://schema.org',
        '@type': 'BlogPosting',
        'headline': p.title,
        'description': p.excerpt ?? p.metaDescription,
        'url': SiteSeoConfig.absolute(path),
        if (p.heroImageUrl != null) 'image': p.heroImageUrl,
        'author': {'@type': 'Organization', 'name': p.authorName},
        'datePublished': p.publishedAt?.toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebSeoScope(
      meta: _seoMeta(),
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        body: CustomScrollView(
          slivers: [
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_post == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Article not found', style: V2FontStyles.display(fontSize: 24)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => context.go(RouteNames.publicServices), child: const Text('Services')),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _Hero(post: _post!)),
              SliverToBoxAdapter(child: _Body(post: _post!)),
            ],
            const SliverToBoxAdapter(child: V2Footer()),
            SliverToBoxAdapter(
              child: SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.post});
  final SeoBlogPost post;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.heroImageUrl != null && post.heroImageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(imageUrl: post.heroImageUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(post.title, style: V2FontStyles.display(fontSize: 34, fontWeight: FontWeight.w700)),
              if (post.excerpt != null) ...[
                const SizedBox(height: 12),
                Text(post.excerpt!, style: V2FontStyles.inter(fontSize: 18, color: V2Colors.fgMuted, height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.post});
  final SeoBlogPost post;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxNarrow),
          child: Text(
            post.body ?? '',
            style: V2FontStyles.inter(fontSize: 17, height: 1.7),
          ),
        ),
      ),
    );
  }
}

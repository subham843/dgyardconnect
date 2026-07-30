import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/seo/public_seo_registry.dart';
import '../../../../core/seo/web_seo_binder.dart';
import '../../../../core/seo/web_seo_meta.dart';
import '../../../web_public/v2/v2_font_styles.dart';
import '../../../web_public/v2/v2_colors.dart';
import '../../../web_public/v2/v2_tokens.dart' show V2;
import '../../../web_public/v2/widgets/v2_footer.dart';
import '../../../web_public/widgets/public_floating_menu.dart';
import '../../data/public_seo_repository.dart';
import '../../domain/seo_blog_post.dart';
import '../../domain/seo_landing_page.dart';
import '../../services/seo_content_generator.dart';
import '../../services/seo_route_guard.dart';

/// Dynamic SEO landing page — /{citySlug}/{serviceSlug}
class SeoLandingPageScreen extends StatefulWidget {
  const SeoLandingPageScreen({
    super.key,
    required this.citySlug,
    required this.serviceSlug,
  });

  final String citySlug;
  final String serviceSlug;

  @override
  State<SeoLandingPageScreen> createState() => _SeoLandingPageScreenState();
}

class _SeoLandingPageScreenState extends State<SeoLandingPageScreen> {
  final _repo = PublicSeoRepository();
  final _scroll = ScrollController();

  SeoLandingPage? _page;
  List<SeoBlogPost> _blogs = [];
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!SeoRouteGuard.isPotentialLandingPath(widget.citySlug, widget.serviceSlug)) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _notFound = false;
    });

    final resolved = await _repo.resolveLanding(widget.citySlug, widget.serviceSlug);
    if (!mounted) return;

    if (resolved == null) {
      setState(() {
        _page = null;
        _loading = false;
        _notFound = true;
      });
      return;
    }

    final allServices = await _repo.listServices();
    final blogs = await _repo.listRelatedBlogs(
      citySlug: widget.citySlug,
      serviceSlug: widget.serviceSlug,
    );
    if (!mounted) return;

    setState(() {
      _page = SeoContentGenerator.build(
        city: resolved.city,
        service: resolved.service,
        allServices: allServices,
      );
      _blogs = blogs;
      _loading = false;
    });
  }

  WebSeoMeta _seoMeta() {
    final path = SeoRouteGuard.landingPath(widget.citySlug, widget.serviceSlug);
    if (_notFound || (!_loading && _page == null)) {
      return PublicSeoRegistry.softNotFound(
        title: 'Service page not found',
        path: path,
      );
    }
    if (_page == null) {
      return PublicSeoRegistry.services();
    }
    final p = _page!;
    final follow = !p.robots.toLowerCase().contains('nofollow');
    return WebSeoMeta(
      title: p.title,
      description: p.metaDescription,
      canonicalPath: p.canonicalPath,
      imageUrl: p.heroImageUrl,
      index: p.index,
      follow: follow,
      jsonLd: p.jsonLd,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebSeoScope(
      meta: _seoMeta(),
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_notFound || _page == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Page not found', style: V2FontStyles.display(fontSize: 28)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go(RouteNames.publicServices),
                        child: const Text('Browse services'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._contentSlivers(_page!, _blogs),
            const SliverToBoxAdapter(child: V2Footer()),
            SliverToBoxAdapter(
              child: SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(SeoLandingPage page, List<SeoBlogPost> blogs) {
    return [
      SliverToBoxAdapter(child: _HeroSection(page: page)),
      SliverToBoxAdapter(child: _Breadcrumbs(page: page)),
      SliverToBoxAdapter(child: _IntroSection(page: page)),
      SliverToBoxAdapter(child: _WhyChooseSection(page: page)),
      SliverToBoxAdapter(child: _FeaturesSection(page: page)),
      SliverToBoxAdapter(child: _ProcessSection(page: page)),
      SliverToBoxAdapter(child: _PricingCta(page: page)),
      SliverToBoxAdapter(child: _AreasSection(page: page)),
      SliverToBoxAdapter(child: _RelatedServices(page: page)),
      SliverToBoxAdapter(child: _NearbyCities(page: page)),
      SliverToBoxAdapter(child: _RelatedProducts(page: page)),
      SliverToBoxAdapter(child: _RelatedBlogs(blogs: blogs)),
      SliverToBoxAdapter(child: _FaqSection(page: page)),
      SliverToBoxAdapter(child: _ContactCta(page: page)),
    ];
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            V2Colors.ember.withValues(alpha: 0.12),
            V2Colors.bg,
          ],
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (page.heroImageUrl != null && page.heroImageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 21 / 9,
                  child: CachedNetworkImage(
                    imageUrl: page.heroImageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(page.h1, style: V2FontStyles.display(fontSize: 36, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              page.service.shortDescription ?? page.intro,
              style: V2FontStyles.inter(fontSize: 18, color: V2Colors.fgMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < page.breadcrumbs.length; i++) ...[
              if (i > 0) Text('›', style: V2FontStyles.inter(fontSize: 12, color: V2Colors.fgMuted)),
              InkWell(
                onTap: i < page.breadcrumbs.length - 1
                    ? () => context.go(page.breadcrumbs[i].path)
                    : null,
                child: Text(
                  page.breadcrumbs[i].label,
                  style: V2FontStyles.inter(
                    fontSize: 12,
                    color: i < page.breadcrumbs.length - 1 ? V2Colors.ember : V2Colors.fgMuted,
                    fontWeight: i == page.breadcrumbs.length - 1 ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Text(page.intro, style: V2FontStyles.inter(fontSize: 17, height: 1.6)),
    );
  }
}

class _WhyChooseSection extends StatelessWidget {
  const _WhyChooseSection({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    final items = page.service.whyChoose;
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: page.whyChooseHeading,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map(
              (t) => Chip(
                label: Text(t),
                backgroundColor: V2Colors.surface,
                side: BorderSide(color: V2Colors.border),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    final items = page.service.features;
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: page.h2Features,
      child: Column(
        children: items
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: V2Colors.ember, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f, style: V2FontStyles.inter(fontSize: 15))),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProcessSection extends StatelessWidget {
  const _ProcessSection({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    final steps = page.service.processSteps;
    if (steps.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: page.processHeading,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 0,
                color: V2Colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: V2Colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}'.padLeft(2, '0'),
                      style: V2FontStyles.inter(fontSize: 20, fontWeight: FontWeight.w700, color: V2Colors.ember),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].title, style: V2FontStyles.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(steps[i].description, style: V2FontStyles.inter(fontSize: 14, color: V2Colors.fgMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PricingCta extends StatelessWidget {
  const _PricingCta({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Card(
        elevation: 0,
        color: V2Colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: V2Colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transparent pricing for ${page.city.name}', style: V2FontStyles.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Get a site survey and itemized BOQ for ${page.service.name.toLowerCase()}.',
                    style: V2FontStyles.inter(fontSize: 15, color: V2Colors.fgMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: () => context.go(RouteNames.publicContact),
              child: Text(page.service.pricingCtaText),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AreasSection extends StatelessWidget {
  const _AreasSection({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: page.areasHeading,
      child: Text(page.areasText, style: V2FontStyles.inter(fontSize: 17, height: 1.6)),
    );
  }
}

class _RelatedServices extends StatelessWidget {
  const _RelatedServices({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    if (page.relatedServiceLinks.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Related services in ${page.city.name}',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: page.relatedServiceLinks
            .map(
              (l) => ActionChip(
                label: Text(l.label),
                onPressed: () => context.go(l.path),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NearbyCities extends StatelessWidget {
  const _NearbyCities({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    final nearby = page.city.nearbyCities;
    if (nearby.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Nearby cities',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: nearby
            .map(
              (c) => ActionChip(
                label: Text('${c.name}, ${c.state}'),
                onPressed: () => context.go(
                  SeoRouteGuard.landingPath(c.slug, page.service.slug),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RelatedProducts extends StatelessWidget {
  const _RelatedProducts({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    final slugs = page.service.relatedProductCategorySlugs;
    if (slugs.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Related products',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: slugs
            .map(
              (slug) => ActionChip(
                label: Text(slug.replaceAll('-', ' ')),
                onPressed: () => context.go(RouteNames.publicStoreCategory(slug)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RelatedBlogs extends StatelessWidget {
  const _RelatedBlogs({required this.blogs});
  final List<SeoBlogPost> blogs;

  @override
  Widget build(BuildContext context) {
    if (blogs.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Related articles',
      child: Column(
        children: blogs
            .map(
              (b) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(b.title, style: V2FontStyles.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: b.excerpt != null
                    ? Text(b.excerpt!, maxLines: 2, overflow: TextOverflow.ellipsis, style: V2FontStyles.inter(fontSize: 13, color: V2Colors.fgMuted))
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => context.go(RouteNames.publicBlog(b.slug)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    if (page.faq.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Frequently asked questions',
      child: Column(
        children: page.faq
            .map(
              (f) => ExpansionTile(
                title: Text(f.question, style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(f.answer, style: V2FontStyles.inter(fontSize: 14, color: V2Colors.fgMuted, height: 1.5)),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ContactCta extends StatelessWidget {
  const _ContactCta({required this.page});
  final SeoLandingPage page;

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Center(
        child: Column(
          children: [
            Text('Ready for ${page.service.name} in ${page.city.name}?', style: V2FontStyles.inter(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(RouteNames.publicContact),
              child: const Text('Contact D.G.Yard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title!, style: V2FontStyles.display(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

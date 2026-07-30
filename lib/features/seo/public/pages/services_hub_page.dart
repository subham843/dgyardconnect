import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/seo/public_seo_registry.dart';
import '../../../../core/seo/web_seo_binder.dart';
import '../../../web_public/v2/v2_font_styles.dart';
import '../../../web_public/v2/v2_colors.dart';
import '../../../web_public/v2/v2_glass.dart' show v2BackdropGlass;
import '../../../web_public/v2/v2_tokens.dart' show V2;
import '../../../web_public/v2/widgets/v2_footer.dart';
import '../../../web_public/widgets/public_floating_menu.dart';
import '../../data/public_seo_repository.dart';
import '../../domain/seo_service.dart';
import '../../services/seo_route_guard.dart';

/// Dynamic /services hub — service menu + city picker (no static city pages).
class ServicesHubPage extends StatefulWidget {
  const ServicesHubPage({super.key});

  @override
  State<ServicesHubPage> createState() => _ServicesHubPageState();
}

class _ServicesHubPageState extends State<ServicesHubPage> {
  final _repo = PublicSeoRepository();
  List<SeoService> _services = [];
  bool _loading = true;
  SeoService? _pendingService;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = await _repo.listServices();
    if (!mounted) return;
    setState(() {
      _services = services;
      _loading = false;
    });
  }

  void _onServiceTap(SeoService service) {
    setState(() => _pendingService = service);
    _showCityPicker(service);
  }

  Future<void> _showCityPicker(SeoService service) async {
    final cities = await _repo.listCitiesForService(service.slug);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V2Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.paddingOf(ctx).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select city — ${service.name}', style: V2FontStyles.inter(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                cities.isEmpty
                    ? 'No cities are assigned to this service yet.'
                    : 'Choose your city to view localized installation services.',
                style: V2FontStyles.inter(fontSize: 14, color: V2Colors.fgMuted),
              ),
              const SizedBox(height: 16),
              ...cities.map(
                (c) => ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: V2Colors.bg,
                  title: Text(c.name),
                  subtitle: Text(c.state),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go(SeoRouteGuard.landingPath(c.slug, service.slug));
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(RouteNames.publicServicesCities);
                },
                child: const Text('View all cities'),
              ),
            ],
          ),
        );
      },
    );
    setState(() => _pendingService = null);
  }

  @override
  Widget build(BuildContext context) {
    return WebSeoScope(
      meta: PublicSeoRegistry.servicesInstallations(),
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Installation Services', style: V2FontStyles.display(fontSize: 36, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          'CCTV, networking, fire safety, and IT infrastructure — select a service, then your city.',
                          style: V2FontStyles.inter(fontSize: 18, color: V2Colors.fgMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _services
                            .map(
                              (s) => _ServiceCard(
                                service: s,
                                selected: _pendingService?.id == s.id,
                                onTap: () => _onServiceTap(s),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: OutlinedButton.icon(
                    onPressed: () => context.go(RouteNames.publicServicesCities),
                    icon: const Icon(Icons.location_city_rounded),
                    label: const Text('View all cities'),
                  ),
                ),
              ),
            ),
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onTap,
    this.selected = false,
  });

  final SeoService service;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: v2BackdropGlass(
        backgroundColor: V2Colors.surface.withValues(alpha: 0.9),
        border: Border.all(color: V2Colors.border),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.build_rounded, color: selected ? V2Colors.ember : V2Colors.fgMuted),
              const SizedBox(height: 12),
              Text(service.name, style: V2FontStyles.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                service.shortDescription ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: V2FontStyles.inter(fontSize: 13, color: V2Colors.fgMuted),
              ),
              const SizedBox(height: 12),
              Text('Select city →', style: V2FontStyles.inter(fontSize: 12, color: V2Colors.ember)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

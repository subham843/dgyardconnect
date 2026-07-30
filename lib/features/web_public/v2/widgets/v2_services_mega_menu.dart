// Services mega menu — matches Shop mega menu styling with city flyout on hover.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../../seo/data/public_seo_repository.dart';
import '../../../seo/domain/seo_city.dart';
import '../../../seo/domain/seo_service.dart';
import '../../../seo/services/seo_route_guard.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../v2_perf.dart';

class V2ServicesMegaMenu extends StatefulWidget {
  const V2ServicesMegaMenu({
    super.key,
    required this.visible,
    required this.onClose,
    required this.anchorWidth,
    required this.cityFlyoutWidth,
  });

  final bool visible;
  final VoidCallback onClose;
  final double anchorWidth;
  final double cityFlyoutWidth;

  @override
  State<V2ServicesMegaMenu> createState() => _V2ServicesMegaMenuState();
}

class _V2ServicesMegaMenuState extends State<V2ServicesMegaMenu> {
  final _repo = PublicSeoRepository();
  List<SeoService> _services = [];
  bool _loading = true;
  String? _hoveredServiceSlug;
  List<SeoCity> _citiesForService = [];
  bool _citiesLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final services = await _repo.listServices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onServiceHover(String slug) async {
    if (_hoveredServiceSlug == slug && _citiesForService.isNotEmpty) return;
    setState(() {
      _hoveredServiceSlug = slug;
      _citiesLoading = true;
      _citiesForService = [];
    });
    try {
      final cities = await _repo.listCitiesForService(slug);
      if (!mounted || _hoveredServiceSlug != slug) return;
      setState(() {
        _citiesForService = cities;
        _citiesLoading = false;
      });
    } catch (_) {
      if (!mounted || _hoveredServiceSlug != slug) return;
      setState(() => _citiesLoading = false);
    }
  }

  SeoService? get _hoveredService {
    final slug = _hoveredServiceSlug;
    if (slug == null) return null;
    for (final s in _services) {
      if (s.slug == slug) return s;
    }
    return null;
  }

  BoxDecoration get _panelDecoration => BoxDecoration(
        borderRadius: BorderRadius.circular(V2.rXl),
        color: Colors.white.withValues(alpha: 0.94),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: V2Colors.paperHigh,
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final hovered = _hoveredService;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildServicesPanel(),
          if (hovered != null) ...[
            const SizedBox(width: 10),
            _buildCityFlyout(hovered),
          ],
        ],
      ),
    )
        .v2Animate(
          (w) => w
              .animate()
              .fadeIn(duration: 220.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.06,
                end: 0,
                duration: 280.ms,
                curve: Curves.easeOutCubic,
              ),
        );
  }

  Widget _buildServicesPanel() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.anchorWidth.clamp(320, 520),
        minWidth: 320,
      ),
      child: DecoratedBox(
        decoration: _panelDecoration,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Installation Services',
                style: V2FontStyles.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: V2Colors.inkMutedSaaS,
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_services.isEmpty)
                Text(
                  'Services loading unavailable. Browse all below.',
                  style: V2FontStyles.inter(
                    fontSize: 12.5,
                    color: V2Colors.inkMutedSaaS,
                  ),
                )
              else ...[
                Text(
                  'Select a service',
                  style: V2FontStyles.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: V2Colors.inkMutedSaaS,
                  ),
                ),
                const SizedBox(height: 10),
                for (final service in _services)
                  _ServiceRow(
                    label: service.name,
                    selected: service.slug == _hoveredServiceSlug,
                    showChevron: true,
                    onHover: () => _onServiceHover(service.slug),
                    onTap: () => _onServiceHover(service.slug),
                  ),
              ],
              const SizedBox(height: 12),
              _ViewAllRow(
                label: 'All services (city-wise)',
                onTap: () {
                  widget.onClose();
                  context.go(RouteNames.publicServicesInstallations);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityFlyout(SeoService service) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.cityFlyoutWidth.clamp(240, 320),
        minWidth: 240,
      ),
      child: DecoratedBox(
        decoration: _panelDecoration,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select City',
                style: V2FontStyles.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: V2Colors.inkMutedSaaS,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                service.name,
                style: V2FontStyles.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: V2Colors.premiumOrange,
                ),
              ),
              const SizedBox(height: 14),
              if (_citiesLoading)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_citiesForService.isEmpty)
                Text(
                  'No cities assigned for this service yet.',
                  style: V2FontStyles.inter(
                    fontSize: 12.5,
                    color: V2Colors.inkMutedSaaS,
                  ),
                )
              else
                for (final city in _citiesForService)
                  _ServiceRow(
                    label: city.name,
                    subtitle: city.state,
                    onTap: () {
                      final url = SeoRouteGuard.landingPath(city.slug, service.slug);
                      widget.onClose();
                      context.go(url);
                    },
                  ),
              const SizedBox(height: 12),
              _ViewAllRow(
                label: 'View all cities',
                onTap: () {
                  widget.onClose();
                  context.go(RouteNames.publicServicesCities);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatefulWidget {
  const _ServiceRow({
    required this.label,
    this.subtitle,
    this.selected = false,
    this.showChevron = false,
    this.onHover,
    this.onTap,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final bool showChevron;
  final VoidCallback? onHover;
  final VoidCallback? onTap;

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || widget.selected;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hover = true);
        widget.onHover?.call();
      },
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: V2.dFast,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V2.rMd),
            color: active
                ? V2Colors.premiumOrange.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? V2Colors.premiumOrange.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: V2FontStyles.inter(
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? V2Colors.inkSaaS : V2Colors.inkMutedSaaS,
                      ),
                    ),
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: V2FontStyles.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: V2Colors.inkMutedSaaS,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.showChevron)
                AnimatedSlide(
                  duration: V2.dFast,
                  offset: active ? Offset.zero : const Offset(-0.15, 0),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: active ? V2Colors.premiumOrangeDeep : V2Colors.fgFaint,
                  ),
                )
              else
                AnimatedSlide(
                  duration: V2.dFast,
                  offset: active ? Offset.zero : const Offset(-0.15, 0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: active ? V2Colors.premiumOrangeDeep : V2Colors.fgFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewAllRow extends StatefulWidget {
  const _ViewAllRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ViewAllRow> createState() => _ViewAllRowState();
}

class _ViewAllRowState extends State<_ViewAllRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: V2.dFast,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V2.rMd),
            color: _hover
                ? V2Colors.premiumOrange.withValues(alpha: 0.14)
                : Colors.transparent,
            border: Border.all(
              color: _hover
                  ? V2Colors.premiumOrange.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _hover
                      ? V2Colors.premiumOrangeDeep
                      : V2Colors.premiumOrange,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_outward_rounded,
                size: 15,
                color: _hover
                    ? V2Colors.premiumOrangeDeep
                    : V2Colors.premiumOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

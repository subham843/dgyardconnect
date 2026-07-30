// Products mega menu — glass dropdown with category quick links.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../data/repositories/public_catalog_repository.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../v2_perf.dart';

class V2ProductsMegaMenu extends StatefulWidget {
  const V2ProductsMegaMenu({
    super.key,
    required this.visible,
    required this.onClose,
    required this.anchorWidth,
  });

  final bool visible;
  final VoidCallback onClose;
  final double anchorWidth;

  @override
  State<V2ProductsMegaMenu> createState() => _V2ProductsMegaMenuState();
}

class _V2ProductsMegaMenuState extends State<V2ProductsMegaMenu> {
  final _repo = PublicCatalogRepository();
  List<Map<String, dynamic>> _categories = const [];
  bool _loading = true;

  static const _quickLinks = [
    _QuickLink(
      'All Products',
      RouteNames.publicStore,
      Icons.storefront_rounded,
    ),
    _QuickLink(
      'CCTV & Security',
      '${RouteNames.publicStore}?q=cctv',
      Icons.videocam_rounded,
    ),
    _QuickLink(
      'Computers & IT',
      '${RouteNames.publicStore}?q=computer',
      Icons.computer_rounded,
    ),
    _QuickLink(
      'Networking',
      '${RouteNames.publicStore}?q=network',
      Icons.router_rounded,
    ),
    _QuickLink(
      'Access Control',
      '${RouteNames.publicStore}?q=access',
      Icons.fingerprint_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats.take(8).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Material(
          color: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.anchorWidth.clamp(320, 520),
                minWidth: 320,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(V2.rXl),
                  color: Colors.white.withValues(alpha: 0.94),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  boxShadow: V2Colors.paperHigh,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'IT Products Marketplace',
                        style: V2FontStyles.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: V2Colors.inkMutedSaaS,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final link in _quickLinks)
                            _MegaChip(
                              label: link.label,
                              icon: link.icon,
                              onTap: () {
                                widget.onClose();
                                context.go(link.route);
                              },
                            ),
                        ],
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ] else if (_categories.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Browse Categories',
                          style: V2FontStyles.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: V2Colors.inkMutedSaaS,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._categories.map((cat) {
                          final name = (cat['name'] as String?) ?? 'Category';
                          final slug = (cat['slug'] as String?) ?? '';
                          return _CategoryRow(
                            label: name,
                            onTap: () {
                              widget.onClose();
                              if (slug.isNotEmpty) {
                                context.go(
                                  RouteNames.publicStoreCategory(slug),
                                );
                              } else {
                                context.go(RouteNames.publicStore);
                              }
                            },
                          );
                        }),
                      ],
                      const SizedBox(height: 12),
                      _ViewAllRow(
                        onTap: () {
                          widget.onClose();
                          context.go(RouteNames.publicStore);
                        },
                      ),
                    ],
                  ),
                ),
              ),
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
}

class _QuickLink {
  const _QuickLink(this.label, this.route, this.icon);
  final String label;
  final String route;
  final IconData icon;
}

class _MegaChip extends StatefulWidget {
  const _MegaChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_MegaChip> createState() => _MegaChipState();
}

class _MegaChipState extends State<_MegaChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V2.rMd),
            color: _hover
                ? V2Colors.premiumOrange.withValues(alpha: 0.18)
                : V2Colors.paperMuted,
            border: Border.all(
              color: _hover
                  ? V2Colors.premiumOrange.withValues(alpha: 0.65)
                  : V2Colors.borderSubtle,
              width: _hover ? 1.4 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: V2Colors.premiumOrange.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: _hover
                    ? V2Colors.premiumOrangeDeep
                    : V2Colors.inkMutedSaaS,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _hover ? V2Colors.inkSaaS : V2Colors.inkMutedSaaS,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
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
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V2.rMd),
            color: _hover
                ? V2Colors.premiumOrange.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: _hover
                  ? V2Colors.premiumOrange.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: V2FontStyles.inter(
                    fontSize: 14,
                    fontWeight: _hover ? FontWeight.w700 : FontWeight.w500,
                    color: _hover ? V2Colors.inkSaaS : V2Colors.inkMutedSaaS,
                  ),
                ),
              ),
              AnimatedSlide(
                duration: V2.dFast,
                offset: _hover ? Offset.zero : const Offset(-0.15, 0),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _hover ? V2Colors.premiumOrangeDeep : V2Colors.fgFaint,
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
  const _ViewAllRow({required this.onTap});
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
                'View all products',
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

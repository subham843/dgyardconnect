// Apple Store–style intro — hero ke neeche category discovery strip.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../data/models/public_store_models.dart';
import '../../data/repositories/public_store_repository.dart';
import '../../pages/shop/widgets/store_atoms.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../widgets/v2_section.dart';
import '../widgets/v2_tilt_3d_card.dart';

/// Apple.com/store jaisa light-grey block: bada "Store" title + horizontal category rail.
class V2StoreIntro extends StatefulWidget {
  const V2StoreIntro({super.key});

  static const Color background = Color(0xFFF5F5F7);

  @override
  State<V2StoreIntro> createState() => _V2StoreIntroState();
}

class _V2StoreIntroState extends State<V2StoreIntro> {
  final _repo = PublicStoreRepository();
  final _railCtrl = ScrollController();

  List<PublicCategory> _categories = const [];
  bool _loading = true;
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _railCtrl.addListener(_syncScrollButtons);
    _load();
  }

  @override
  void dispose() {
    _railCtrl.removeListener(_syncScrollButtons);
    _railCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categories = await _repo.loadCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollButtons());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncScrollButtons() {
    if (!_railCtrl.hasClients) return;
    final pos = _railCtrl.position;
    final back = pos.pixels > 4;
    final forward = pos.pixels < pos.maxScrollExtent - 4;
    if (back != _canScrollBack || forward != _canScrollForward) {
      setState(() {
        _canScrollBack = back;
        _canScrollForward = forward;
      });
    }
  }

  void _scrollRail(double delta) {
    if (!_railCtrl.hasClients) return;
    final target = (_railCtrl.offset + delta).clamp(
      0.0,
      _railCtrl.position.maxScrollExtent,
    );
    _railCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.md;

    return V2Section(
      background: V2StoreIntro.background,
      padTopOverride: v.r<double>(xs: 42, md: 56, lg: 66),
      padBottomOverride: v.r<double>(xs: 44, md: 56, lg: 68),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          wide ? _DesktopHeader(v: v) : _MobileHeader(v: v),
          SizedBox(height: v.r<double>(xs: 26, md: 34, lg: 40)),
          const _QuickShopCards(),
          SizedBox(height: v.r<double>(xs: 28, md: 34, lg: 40)),
          if (_loading)
            _CategoryRailSkeleton(v: v)
          else if (_categories.isEmpty)
            const SizedBox.shrink()
          else
            _CategoryRail(
              v: v,
              categories: _categories,
              controller: _railCtrl,
              canScrollBack: _canScrollBack,
              canScrollForward: _canScrollForward,
              onBack: () => _scrollRail(-280),
              onForward: () => _scrollRail(280),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 480.ms, curve: Curves.easeOut);
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: _StoreHeadline(fontSize: v.r<double>(xs: 40, md: 50, lg: 62)),
        ),
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.topRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _HeaderAside(alignEnd: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StoreHeadline(fontSize: v.r<double>(xs: 38, md: 48)),
        SizedBox(height: v.r<double>(xs: 16, md: 20)),
        const _HeaderAside(alignEnd: false),
      ],
    );
  }
}

class _HeaderAside extends StatelessWidget {
  const _HeaderAside({required this.alignEnd});

  final bool alignEnd;

  static const _linkColor = Color(0xFF0066CC);

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          'Everything for your project. Products, BOQ pricing and technician support in one place.',
          textAlign: textAlign,
          style: V2FontStyles.inter(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
            letterSpacing: -0.2,
            color: V2Colors.inkSaaS,
          ),
        ),
        const SizedBox(height: 12),
        _HeaderLink(
          label: 'Buy IT Products',
          onTap: () => context.go(RouteNames.publicStore),
          color: _linkColor,
          alignEnd: alignEnd,
        ),
        const SizedBox(height: 6),
        _HeaderLink(
          label: 'Generate BOQ',
          onTap: () => context.go(RouteNames.publicCalculatorList),
          color: _linkColor,
          alignEnd: alignEnd,
        ),
      ],
    );
  }
}

class _HeaderLink extends StatefulWidget {
  const _HeaderLink({
    required this.label,
    required this.onTap,
    required this.color,
    required this.alignEnd,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool alignEnd;

  @override
  State<_HeaderLink> createState() => _HeaderLinkState();
}

class _HeaderLinkState extends State<_HeaderLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: widget.alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                widget.label,
                textAlign: widget.alignEnd ? TextAlign.right : TextAlign.left,
                style: V2FontStyles.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: widget.color,
                  decoration: _hover
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: widget.color,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.north_east_rounded, size: 13, color: widget.color),
          ],
        ),
      ),
    );
  }
}

class _StoreHeadline extends StatelessWidget {
  const _StoreHeadline({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = V2FontStyles.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.8,
      height: 1.02,
      color: V2Colors.inkSaaS,
    );
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Shop the DG Yard Store. '),
          TextSpan(
            text: 'All your IT needs in one place.',
            style: style.copyWith(color: V2Colors.inkMutedSaaS),
          ),
        ],
      ),
    );
  }
}

class _QuickShopCards extends StatelessWidget {
  const _QuickShopCards();

  static const _cards = [
    _QuickShopCardData(
      title: 'Buy products',
      subtitle: 'CCTV, networking, computers and security gear.',
      icon: Icons.storefront_rounded,
      route: RouteNames.publicStore,
      color: Color(0xFF0F172A),
    ),
    _QuickShopCardData(
      title: 'Build BOQ',
      subtitle: 'Calculate project pricing before you purchase.',
      icon: Icons.calculate_rounded,
      route: RouteNames.publicCalculatorList,
      color: Color(0xFFFF5E1B),
    ),
    _QuickShopCardData(
      title: 'Find technician',
      subtitle: 'Get installation help from DG Yard Connect.',
      icon: Icons.engineering_rounded,
      route: RouteNames.phoneEntry,
      color: Color(0xFF635BFF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final desktop = v.width >= V2Breakpoints.lg;
    final height = v.r<double>(xs: 178, md: 190, lg: 214, xl: 226);

    if (!desktop) {
      return SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) => SizedBox(
            width: 250,
            child: _QuickShopCard(data: _cards[i], index: i),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < _cards.length; i++) ...[
            Expanded(
              child: _QuickShopCard(data: _cards[i], index: i),
            ),
            if (i < _cards.length - 1) const SizedBox(width: 18),
          ],
        ],
      ),
    );
  }
}

class _QuickShopCardData {
  const _QuickShopCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
}

class _QuickShopCard extends StatelessWidget {
  const _QuickShopCard({required this.data, required this.index});

  final _QuickShopCardData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    return V2Tilt3DCard(
          borderRadius: 26,
          maxTilt: 0.06,
          hoverLift: 5,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(22),
          onTap: () => context.go(data.route),
          child: Stack(
            children: [
              Positioned(
                right: -22,
                bottom: -24,
                child: Icon(
                  data.icon,
                  size: 112,
                  color: data.color.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(data.icon, color: data.color, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    data.title,
                    style: V2FontStyles.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: V2Colors.inkSaaS,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: V2FontStyles.inter(
                      fontSize: 14,
                      height: 1.4,
                      color: V2Colors.inkMutedSaaS,
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(delay: (80 + index * 70).ms)
        .fadeIn(duration: 460.ms)
        .slideY(begin: 0.08, end: 0);
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.v,
    required this.categories,
    required this.controller,
    required this.canScrollBack,
    required this.canScrollForward,
    required this.onBack,
    required this.onForward,
  });

  final V2Responsive v;
  final List<PublicCategory> categories;
  final ScrollController controller;
  final bool canScrollBack;
  final bool canScrollForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final tileWidth = v.r<double>(xs: 136, sm: 152, md: 170, lg: 184);
    final railHeight = v.r<double>(xs: 184, md: 202, lg: 216);

    return SizedBox(
      height: railHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: canScrollBack ? 44 : 0,
              right: canScrollForward ? 44 : 0,
            ),
            itemCount: categories.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: v.r<double>(xs: 14, md: 18)),
            itemBuilder: (context, index) {
              return _CategoryTile(
                category: categories[index],
                width: tileWidth,
              );
            },
          ),
          if (canScrollBack)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _RailNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onBack,
                ),
              ),
            ),
          if (canScrollForward)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _RailNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onForward,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.width});

  final PublicCategory category;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: V2Tilt3DCard(
        borderRadius: 28,
        maxTilt: 0.07,
        hoverLift: 5,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.all(14),
        onTap: () => context.go(RouteNames.publicStoreCategory(category.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: StoreImage(
                  url: category.imageUrl,
                  fit: BoxFit.contain,
                  backgroundColor: const Color(0xFFF5F5F7),
                  fallbackIcon: Icons.category_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: V2FontStyles.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: -0.2,
                color: V2Colors.inkSaaS,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Shop now',
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0066CC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailNavButton extends StatefulWidget {
  const _RailNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_RailNavButton> createState() => _RailNavButtonState();
}

class _RailNavButtonState extends State<_RailNavButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? const Color(0xFFDCDCE0) : const Color(0xFFE8E8ED),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: V2Colors.inkSaaS.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}

class _CategoryRailSkeleton extends StatelessWidget {
  const _CategoryRailSkeleton({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    final tileWidth = v.r<double>(xs: 96, sm: 108, md: 116);
    return SizedBox(
      height: v.r<double>(xs: 118, md: 128),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (_, _) =>
            SizedBox(width: v.r<double>(xs: 18, md: 24)),
        itemBuilder: (_, _) => SizedBox(
          width: tileWidth,
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: V2Colors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 10,
                width: tileWidth * 0.72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

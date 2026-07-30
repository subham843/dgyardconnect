// Apple-style rotating offer bar — sits directly below the navbar.

import 'dart:async';

import 'package:flutter/material.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../shared/models/brand_kit_model.dart';
import '../../../../shared/models/public_web_offer_bar_item.dart';
import '../../../../shared/services/brand_kit_service.dart';
import '../../../../shared/widgets/brand_kit_provider.dart';
import '../../core/brand/public_brand_content.dart';
import '../../core/brand/public_brand_navigation.dart';
import '../v2_colors.dart';

class V2OfferBar extends StatefulWidget {
  const V2OfferBar({
    super.key,
    this.items,
  });

  /// When set, uses these items instead of loading from Brand Kit.
  final List<PublicWebOfferBarItem>? items;

  static const double barHeight = 40;

  /// Very light grey — distinct from the white navbar.
  static const Color backgroundColor = Color(0xFFF3F4F6);

  static double insetFor(List<PublicWebOfferBarItem> items) =>
      items.isEmpty ? 0 : barHeight;

  @override
  State<V2OfferBar> createState() => _V2OfferBarState();
}

class _V2OfferBarState extends State<V2OfferBar> {
  final _pageCtrl = PageController();
  Timer? _timer;
  int _index = 0;
  int _autoPlayCount = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _ensureAutoPlay(int count) {
    if (_autoPlayCount == count) return;
    _autoPlayCount = count;
    _restartAutoPlay(count);
  }

  void _restartAutoPlay(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final next = (_index + 1) % count;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _go(int delta, int count) {
    if (count <= 1) return;
    var next = _index + delta;
    if (next < 0) next = count - 1;
    if (next >= count) next = 0;
    _pageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items != null) {
      return _buildBar(context, widget.items!);
    }

    return StreamBuilder<BrandKitModel>(
      stream: BrandKitService.stream(),
      initialData: BrandKitProvider.of(context),
      builder: (context, snapshot) {
        final kit = snapshot.data ?? BrandKitProvider.of(context);
        final items = PublicBrandContent(kit).topOfferBarItems;
        return _buildBar(context, items);
      },
    );
  }

  Widget _buildBar(BuildContext context, List<PublicWebOfferBarItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    _ensureAutoPlay(items.length);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: V2OfferBar.backgroundColor,
        border: Border(
          bottom: BorderSide(color: V2Colors.border.withValues(alpha: 0.75)),
        ),
      ),
      child: SizedBox(
        height: V2OfferBar.barHeight,
        child: Row(
          children: [
            _NavChevron(
              visible: items.length > 1,
              icon: Icons.chevron_left_rounded,
              onTap: () => _go(-1, items.length),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: items.length,
                itemBuilder: (context, i) => _OfferSlide(item: items[i]),
              ),
            ),
            _NavChevron(
              visible: items.length > 1,
              icon: Icons.chevron_right_rounded,
              onTap: () => _go(1, items.length),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavChevron extends StatelessWidget {
  const _NavChevron({
    required this.visible,
    required this.icon,
    required this.onTap,
  });

  final bool visible;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: visible
          ? IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(icon, size: 18, color: V2Colors.inkSaaS.withValues(alpha: 0.72)),
              onPressed: onTap,
            )
          : null,
    );
  }
}

class _OfferSlide extends StatelessWidget {
  const _OfferSlide({required this.item});

  final PublicWebOfferBarItem item;

  @override
  Widget build(BuildContext context) {
    final linkUrl = item.linkUrl?.trim();
    final linkLabel = item.linkLabel?.trim();
    final hasLink = linkUrl != null && linkUrl.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                item.text.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: V2FontStyles.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  color: V2Colors.inkSaaS,
                  height: 1.2,
                ),
              ),
            ),
            if (hasLink) ...[
              const SizedBox(width: 6),
              _OfferLink(
                label: linkLabel?.isNotEmpty == true ? linkLabel! : 'Shop',
                url: linkUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfferLink extends StatefulWidget {
  const _OfferLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  State<_OfferLink> createState() => _OfferLinkState();
}

class _OfferLinkState extends State<_OfferLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => navigateBrandUrl(context, widget.url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: V2Colors.inkSaaS,
                decoration: _hover ? TextDecoration.underline : TextDecoration.none,
                decorationColor: V2Colors.inkSaaS,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: V2Colors.inkSaaS,
            ),
          ],
        ),
      ),
    );
  }
}

// Our Clients — dual-band partner marquee, Apple editorial style.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/supabase/public_rest_client.dart';
import '../../data/models/public_cms_item.dart';
import '../v2_colors.dart';
import '../v2_tokens.dart';
import '../widgets/v2_section.dart';

class V2OurClients extends StatefulWidget {
  const V2OurClients({super.key});

  static const background = Color(0xFFF5F5F7);

  @override
  State<V2OurClients> createState() => _V2OurClientsState();
}

class _V2OurClientsState extends State<V2OurClients> with TickerProviderStateMixin {
  late final AnimationController _bandA;
  late final AnimationController _bandB;
  List<_ClientItem> _clients = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bandA = AnimationController(vsync: this, duration: const Duration(seconds: 42))..repeat();
    _bandB = AnimationController(vsync: this, duration: const Duration(seconds: 36))..repeat();
    _load();
  }

  @override
  void dispose() {
    _bandA.dispose();
    _bandB.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await PublicRestClient.select(
        'public_cms_content',
        order: 'sort_order,title',
        eq: {'content_type': 'partner_logo', 'is_active': 'true'},
      );
      final items = rows.map(PublicCmsItem.fromRow).map(_ClientItem.fromCms).toList();
      if (!mounted) return;
      setState(() {
        _clients = items.isNotEmpty ? items : _ClientItem.fallback;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _clients = _ClientItem.fallback;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _clients.isEmpty) return const SizedBox.shrink();

    final v = V2Responsive(context);
    final rowA = _clients;
    final rowB = [..._clients.reversed, ..._clients.reversed.take(3)];

    return V2Section(
      background: V2OurClients.background,
      borderTop: true,
      padTopOverride: v.r<double>(xs: 32, md: 40, lg: 44),
      padBottomOverride: v.r<double>(xs: 32, md: 40, lg: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(v: v),
          SizedBox(height: v.r<double>(xs: 24, md: 32)),
          if (_loading)
            _Skeleton(v: v)
          else
            MouseRegion(
              onEnter: (_) {
                _bandA.stop();
                _bandB.stop();
              },
              onExit: (_) {
                _bandA.repeat();
                _bandB.repeat();
              },
              child: Column(
                children: [
                  _ClientBand(
                    clients: rowA,
                    controller: _bandA,
                    reverse: false,
                  ),
                  SizedBox(height: v.r<double>(xs: 10, md: 12)),
                  _ClientBand(
                    clients: rowB,
                    controller: _bandB,
                    reverse: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _ClientItem {
  const _ClientItem({required this.name, this.logoUrl, this.sector});

  final String name;
  final String? logoUrl;
  final String? sector;

  factory _ClientItem.fromCms(PublicCmsItem item) {
    return _ClientItem(
      name: item.title?.trim().isNotEmpty == true ? item.title!.trim() : 'Client',
      logoUrl: item.imageUrl,
      sector: item.subtitle ?? item.metaString('sector'),
    );
  }

  static const fallback = [
    _ClientItem(name: 'Tata Projects', sector: 'Infrastructure'),
    _ClientItem(name: 'Reliance Retail', sector: 'Retail'),
    _ClientItem(name: 'Infosys Campus', sector: 'IT Parks'),
    _ClientItem(name: 'DLF Cyber City', sector: 'Commercial'),
    _ClientItem(name: 'L&T Construction', sector: 'Construction'),
    _ClientItem(name: 'Apollo Hospitals', sector: 'Healthcare'),
    _ClientItem(name: 'Indian Oil', sector: 'Energy'),
    _ClientItem(name: 'Maruti Suzuki', sector: 'Automotive'),
  ];
}

class _Header extends StatelessWidget {
  const _Header({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: V2Colors.aurora, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'Our clients',
              style: V2FontStyles.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: V2Colors.aurora,
              ),
            ),
          ],
        ),
        SizedBox(height: v.r<double>(xs: 8, md: 10)),
        Text(
          'Trusted across industries.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 32, md: 40, lg: 44),
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.04,
            color: V2Colors.inkSaaS,
          ),
        ),
        SizedBox(height: v.r<double>(xs: 8, md: 10)),
        Text(
          'From retail chains to IT parks — teams that scale with D.G.Yard.',
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 14, md: 15),
            height: 1.45,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
      ],
    );
  }
}

class _ClientBand extends StatelessWidget {
  const _ClientBand({
    required this.clients,
    required this.controller,
    required this.reverse,
  });

  final List<_ClientItem> clients;
  final AnimationController controller;
  final bool reverse;

  static const _chipStride = 196.0;

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) return const SizedBox.shrink();

    final loop = [...clients, ...clients];

    return SizedBox(
      height: 64,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRect(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final total = clients.length * _chipStride;
                final t = reverse ? controller.value : (1 - controller.value);
                final dx = -t * total;

                return OverflowBox(
                  maxWidth: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in loop) ...[
                          _ClientChip(client: c),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const _EdgeFade(left: true),
          const _EdgeFade(left: false),
        ],
      ),
    );
  }
}

class _ClientChip extends StatefulWidget {
  const _ClientChip({required this.client});
  final _ClientItem client;

  @override
  State<_ClientChip> createState() => _ClientChipState();
}

class _ClientChipState extends State<_ClientChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 184,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _hover ? Colors.white : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hover ? V2Colors.aurora.withValues(alpha: 0.4) : V2Colors.borderSubtle,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _ClientAvatar(name: c.name, logoUrl: c.logoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2FontStyles.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: V2Colors.inkSaaS,
                    ),
                  ),
                  if (c.sector != null)
                    Text(
                      c.sector!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2FontStyles.inter(
                        fontSize: 10,
                        color: V2Colors.inkMutedSaaS,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.name, this.logoUrl});
  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: V2Colors.paperMist,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: V2Colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.contain,
              width: 30,
              height: 30,
              memCacheWidth: 72,
              errorWidget: (_, _, _) => _Initial(name: name),
            )
          : _Initial(name: name),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final init = name.isNotEmpty ? name[0].toUpperCase() : '·';
    return Text(
      init,
      style: V2FontStyles.inter(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: V2Colors.plasma,
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      width: 72,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                V2OurClients.background,
                V2OurClients.background.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.v});
  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => Container(
              width: 184,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: V2Colors.borderSubtle),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1400.ms, color: V2Colors.bgSubtle),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => Container(
              width: 184,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: V2Colors.borderSubtle),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1400.ms, color: V2Colors.bgSubtle),
          ),
        ),
      ],
    );
  }
}

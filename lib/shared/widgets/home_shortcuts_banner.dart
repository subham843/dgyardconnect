import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../services/firestore_service.dart';
import '../utils/firestore_dynamic.dart';

class HomeShortcutsBanner extends StatefulWidget {
  const HomeShortcutsBanner({super.key, required this.role});

  final String role;

  @override
  State<HomeShortcutsBanner> createState() => _HomeShortcutsBannerState();
}

class _HomeShortcutsBannerState extends State<HomeShortcutsBanner> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _index = 0;
  bool _isUserInteracting = false;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isUserInteracting) return;
      final next = (_index + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.ads().snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final now = DateTime.now();
        final items =
            docs.where((doc) {
              final d = doc.data();
              if (!_asBool(d['active'], fallback: false)) return false;
              if (!_asBool(d['showInHomeBanner'], fallback: false)) {
                return false;
              }
              final role = ((d['targetRole'] as String?) ?? 'all')
                  .trim()
                  .toLowerCase();
              if (role != 'all' && role != widget.role) return false;
              final type = ((d['type'] as String?) ?? 'image')
                  .trim()
                  .toLowerCase();
              final url = (d['url'] as String? ?? '').trim();
              final link = (d['link'] as String? ?? '').trim();
              if (type == 'link' && link.isEmpty && url.isEmpty) return false;
              if (type != 'link' && url.isEmpty) return false;
              final start = _parseDate(d['startDate']);
              final end = _parseDate(d['endDate']);
              if (start != null && now.isBefore(start)) return false;
              if (end != null && now.isAfter(end)) return false;
              return true;
            }).toList()..sort((a, b) {
              final oa = a.data()['order'] as num? ?? 0;
              final ob = b.data()['order'] as num? ?? 0;
              return oa.compareTo(ob);
            });

        if (items.isEmpty) {
          _timer?.cancel();
          return const SizedBox.shrink();
        }

        _startAutoSlide(items.length);
        final height = 196.0;

        if (items.length == 1) {
          return _HomeBannerChrome(
            height: height,
            child: _BannerTile(data: items.first.data(), height: height),
          );
        }

        return _HomeBannerChrome(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                onPointerDown: (_) => _isUserInteracting = true,
                onPointerUp: (_) => _isUserInteracting = false,
                onPointerCancel: (_) => _isUserInteracting = false,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double page = _index.toDouble();
                        if (_pageController.hasClients) {
                          page = _pageController.page ?? _index.toDouble();
                        }
                        final delta = (i - page).clamp(-1.0, 1.0);
                        final translateY = delta * 24;
                        final scale = 1 - (delta.abs() * 0.04);
                        return Transform.translate(
                          offset: Offset(0, translateY),
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: _BannerTile(data: items[i].data(), height: height),
                    );
                  },
                ),
              ),
              Positioned(
                right: 8,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1}/${items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(items.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Elevated frame: thin rim + soft shadow (radius 20).
class _HomeBannerChrome extends StatelessWidget {
  const _HomeBannerChrome({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.52),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 9),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.38),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(height: height, width: double.infinity, child: child),
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({required this.data, required this.height});

  final Map<String, dynamic> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final type = ((data['type'] as String?) ?? 'image').trim().toLowerCase();
    final url = (data['url'] as String? ?? '').trim();
    final title = (data['title'] as String? ?? '').trim();
    final description = (data['description'] as String? ?? '').trim();
    final link = (data['link'] as String? ?? '').trim();
    final effectiveLink = link.isNotEmpty ? link : url;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effectiveLink.isEmpty
            ? null
            : () async {
                final uri = Uri.tryParse(effectiveLink);
                if (uri == null || !uri.hasScheme) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (type == 'video')
              _BannerVideoBackground(url: url)
            else if (type == 'link')
              Container(
                color: const Color(0xFF1E293B),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.link_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: Color(0xFFCBD5E1)),
              ),
            if (title.isNotEmpty || description.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerVideoBackground extends StatefulWidget {
  const _BannerVideoBackground({required this.url});

  final String url;

  @override
  State<_BannerVideoBackground> createState() => _BannerVideoBackgroundState();
}

class _BannerVideoBackgroundState extends State<_BannerVideoBackground> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (!mounted) return;
          _controller!
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF334155));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

bool _asBool(dynamic value, {required bool fallback}) {
  return boolFromFirestore(value, fallback: fallback);
}

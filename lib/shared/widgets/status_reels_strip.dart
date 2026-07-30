import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/firestore_service.dart';
import '../utils/firestore_dynamic.dart';

class StatusReelsStrip extends StatefulWidget {
  const StatusReelsStrip({super.key, required this.role});

  final String role;

  @override
  State<StatusReelsStrip> createState() => _StatusReelsStripState();
}

class _StatusReelsStripState extends State<StatusReelsStrip> {
  Set<String> _seenIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'status_seen_${widget.role}';
    final values = prefs.getStringList(key) ?? const [];
    if (!mounted) return;
    setState(() => _seenIds = values.toSet());
  }

  Future<void> _markSeen(String id) async {
    if (_seenIds.contains(id)) return;
    final next = <String>{..._seenIds, id};
    setState(() => _seenIds = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('status_seen_${widget.role}', next.toList());
  }

  Future<void> _bumpMetric(String docId, String field) async {
    try {
      await FirestoreService.ads().doc(docId).set({
        field: FieldValue.increment(1),
        'lastStatusMetricAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore analytics failures; UI should not break.
    }
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
              if (!boolFromFirestore(d['active'], fallback: false)) {
                return false;
              }
              // Backward compatible: old ads without this field should still appear.
              if (!boolFromFirestore(d['showInStatus'], fallback: true)) {
                return false;
              }
              final targetRole = (d['targetRole'] as String? ?? 'all')
                  .toLowerCase();
              if (targetRole != 'all' && targetRole != widget.role) {
                return false;
              }
              final start = _parseDate(d['startDate']);
              final end = _parseDate(d['endDate']);
              if (start != null && now.isBefore(start)) return false;
              if (end != null && now.isAfter(end)) return false;
              final type = (d['type'] as String? ?? 'image').toLowerCase();
              final url = (d['url'] as String? ?? '').trim();
              final link = (d['link'] as String? ?? '').trim();
              if (type == 'link') return link.isNotEmpty || url.isNotEmpty;
              return url.isNotEmpty;
            }).toList()..sort((a, b) {
              final oa = a.data()['order'] as num? ?? 0;
              final ob = b.data()['order'] as num? ?? 0;
              return oa.compareTo(ob);
            });

        if (items.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final data = items[index].data();
              final type = (data['type'] as String? ?? 'image').toLowerCase();
              final title = (data['title'] as String? ?? '').trim();
              final thumb = (data['url'] as String? ?? '').trim();
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  final openedId = items[index].id;
                  _markSeen(openedId);
                  _bumpMetric(openedId, 'statusTapCount');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _StatusFullScreenViewer(
                        docs: items,
                        initialIndex: index,
                        onSeen: _markSeen,
                        onMetric: _bumpMetric,
                      ),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _seenIds.contains(items[index].id)
                              ? const [Color(0xFF94A3B8), Color(0xFFCBD5E1)]
                              : const [
                                  Color(0xFF60A5FA),
                                  Color(0xFF3B82F6),
                                  Color(0xFF8B5CF6),
                                ],
                        ),
                      ),
                      child: ClipOval(
                        child: Container(
                          color: const Color(0xFFE2E8F0),
                          child: type == 'video'
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (thumb.isNotEmpty)
                                      _VideoThumbPreview(url: thumb)
                                    else
                                      const ColoredBox(
                                        color: Color(0xFF94A3B8),
                                      ),
                                    const Align(
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ],
                                )
                              : (type == 'link'
                                    ? const ColoredBox(
                                        color: Color(0xFFBFDBFE),
                                        child: Center(
                                          child: Icon(
                                            Icons.link_rounded,
                                            color: Color(0xFF1D4ED8),
                                            size: 26,
                                          ),
                                        ),
                                      )
                                    : (thumb.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: thumb,
                                              fit: BoxFit.cover,
                                            )
                                          : const ColoredBox(
                                              color: Color(0xFF94A3B8),
                                            ))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 70,
                      child: Text(
                        title.isEmpty ? 'Update' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusFullScreenViewer extends StatefulWidget {
  const _StatusFullScreenViewer({
    required this.docs,
    required this.initialIndex,
    required this.onSeen,
    required this.onMetric,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final int initialIndex;
  final ValueChanged<String> onSeen;
  final Future<void> Function(String docId, String field) onMetric;

  @override
  State<_StatusFullScreenViewer> createState() =>
      _StatusFullScreenViewerState();
}

class _StatusFullScreenViewerState extends State<_StatusFullScreenViewer> {
  late final PageController _pageController;
  int _index = 0;
  Timer? _timer;
  Timer? _progressTicker;
  double _progress = 0;
  bool _paused = false;
  static const Duration _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    widget.onSeen(widget.docs[_index].id);
    widget.onMetric(widget.docs[_index].id, 'statusViewCount');
    _startProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressTicker?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progress = 0;
    _timer?.cancel();
    _progressTicker?.cancel();
    final item = widget.docs[_index].data();
    final type = (item['type'] as String? ?? 'image').toLowerCase();
    if (type == 'image' || type == 'link') {
      const tick = Duration(milliseconds: 50);
      _progressTicker = Timer.periodic(tick, (_) {
        if (!mounted || _paused) return;
        final next =
            _progress + (tick.inMilliseconds / _storyDuration.inMilliseconds);
        if (next >= 1) {
          _progress = 1;
          _progressTicker?.cancel();
          _next();
          return;
        }
        setState(() => _progress = next);
      });
      _timer = Timer(_storyDuration, _next);
    }
  }

  void _next() {
    if (!mounted) return;
    if (_index >= widget.docs.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _prev() {
    if (!mounted) return;
    if (_index == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.docs.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                  widget.onSeen(widget.docs[_index].id);
                  widget.onMetric(widget.docs[_index].id, 'statusViewCount');
                  _startProgress();
                },
                itemBuilder: (context, i) => _StatusViewerItem(
                  data: widget.docs[i].data(),
                  docId: widget.docs[i].id,
                  onVideoCompleted: i == _index ? _next : null,
                  paused: _paused,
                  onOpenLinkMetric: () =>
                      widget.onMetric(widget.docs[i].id, 'statusLinkOpenCount'),
                  onVideoProgress: i == _index
                      ? (value) => setState(() => _progress = value.clamp(0, 1))
                      : null,
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 8,
              child: Row(
                children: List.generate(widget.docs.length, (i) {
                  final active = i < _index;
                  final current = i == _index;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: active ? 1 : (current ? _progress : 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Center(
                child: Text(
                  'Swipe up to open link',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 8,
              child: Row(
                children: [
                  _VideoMuteButton(
                    data: widget.docs[_index].data(),
                    onToggle: () => _StatusVideoSoundBus.instance.toggle(),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: (_) => setState(() => _paused = true),
                onLongPressEnd: (_) => setState(() => _paused = false),
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < -350) {
                    _openCurrentLinkExternally();
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _prev,
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _next,
                        behavior: HitTestBehavior.translucent,
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

  Future<void> _openCurrentLinkExternally() async {
    final data = widget.docs[_index].data();
    final url = (data['url'] as String? ?? '').trim();
    final link = (data['link'] as String? ?? '').trim();
    final target = link.isNotEmpty ? link : url;
    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme) return;
    await widget.onMetric(widget.docs[_index].id, 'statusLinkOpenCount');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _StatusViewerItem extends StatelessWidget {
  const _StatusViewerItem({
    required this.data,
    required this.docId,
    this.onVideoCompleted,
    required this.paused,
    required this.onOpenLinkMetric,
    this.onVideoProgress,
  });

  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback? onVideoCompleted;
  final bool paused;
  final VoidCallback onOpenLinkMetric;
  final ValueChanged<double>? onVideoProgress;

  @override
  Widget build(BuildContext context) {
    final type = (data['type'] as String? ?? 'image').toLowerCase();
    final url = (data['url'] as String? ?? '').trim();
    final link = (data['link'] as String? ?? '').trim();
    final effectiveLink = link.isNotEmpty ? link : url;
    if (type == 'video') {
      return _StatusVideoPlayer(
        url: url,
        paused: paused,
        onCompleted: onVideoCompleted,
        onProgress: onVideoProgress,
      );
    }
    if (type == 'link') {
      return _StatusLinkPage(
        url: effectiveLink,
        onOpenMetric: onOpenLinkMetric,
      );
    }
    return Center(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, _) =>
            const CircularProgressIndicator(color: Colors.white),
        errorWidget: (_, _, _) => const Icon(
          Icons.broken_image_rounded,
          color: Colors.white70,
          size: 44,
        ),
      ),
    );
  }
}

class _StatusVideoPlayer extends StatefulWidget {
  const _StatusVideoPlayer({
    required this.url,
    required this.paused,
    this.onCompleted,
    this.onProgress,
  });

  final String url;
  final bool paused;
  final VoidCallback? onCompleted;
  final ValueChanged<double>? onProgress;

  @override
  State<_StatusVideoPlayer> createState() => _StatusVideoPlayerState();
}

class _StatusVideoPlayerState extends State<_StatusVideoPlayer> {
  VideoPlayerController? _controller;
  StreamSubscription<bool>? _muteSub;

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _controller!.setVolume(_StatusVideoSoundBus.instance.muted ? 0 : 1);
          _controller!.play();
          _controller!.addListener(_checkCompletion);
        });
    }
    _muteSub = _StatusVideoSoundBus.instance.stream.listen((muted) {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
      c.setVolume(muted ? 0 : 1);
      if (mounted) setState(() {});
    });
  }

  void _checkCompletion() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || widget.onCompleted == null) {
      return;
    }
    if (widget.onProgress != null && c.value.duration > Duration.zero) {
      final p =
          c.value.position.inMilliseconds / c.value.duration.inMilliseconds;
      widget.onProgress!(p);
    }
    if (!c.value.isPlaying &&
        c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero) {
      widget.onCompleted!.call();
    }
  }

  @override
  void didUpdateWidget(covariant _StatusVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused == widget.paused) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.paused) {
      c.pause();
    } else {
      c.play();
    }
  }

  @override
  void dispose() {
    _muteSub?.cancel();
    _controller?.removeListener(_checkCompletion);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }
}

class _StatusLinkPage extends StatefulWidget {
  const _StatusLinkPage({required this.url, required this.onOpenMetric});

  final String url;
  final VoidCallback onOpenMetric;

  @override
  State<_StatusLinkPage> createState() => _StatusLinkPageState();
}

class _StatusLinkPageState extends State<_StatusLinkPage> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    final parsed = Uri.tryParse(widget.url);
    if (parsed != null && parsed.hasScheme) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Center(
        child: FilledButton.icon(
          onPressed: () async {
            final uri = Uri.tryParse(widget.url);
            if (uri == null || !uri.hasScheme) return;
            widget.onOpenMetric();
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open link'),
        ),
      );
    }
    if (_controller == null) {
      return Center(
        child: Text(
          'Invalid link URL',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
  }
}

class _VideoThumbPreview extends StatefulWidget {
  const _VideoThumbPreview({required this.url});

  final String url;

  @override
  State<_VideoThumbPreview> createState() => _VideoThumbPreviewState();
}

class _VideoThumbPreviewState extends State<_VideoThumbPreview> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller!.setVolume(0);
        _controller!.play();
        _controller!.pause();
        setState(() {});
      });
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
      return const ColoredBox(color: Color(0xFF94A3B8));
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

class _VideoMuteButton extends StatefulWidget {
  const _VideoMuteButton({required this.data, required this.onToggle});

  final Map<String, dynamic> data;
  final VoidCallback onToggle;

  @override
  State<_VideoMuteButton> createState() => _VideoMuteButtonState();
}

class _VideoMuteButtonState extends State<_VideoMuteButton> {
  StreamSubscription<bool>? _sub;
  bool _muted = _StatusVideoSoundBus.instance.muted;

  @override
  void initState() {
    super.initState();
    _sub = _StatusVideoSoundBus.instance.stream.listen((value) {
      if (mounted) setState(() => _muted = value);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = (widget.data['type'] as String? ?? 'image').toLowerCase();
    if (type != 'video') return const SizedBox.shrink();
    return IconButton(
      onPressed: widget.onToggle,
      icon: Icon(
        _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: Colors.white,
      ),
    );
  }
}

class _StatusVideoSoundBus {
  _StatusVideoSoundBus._();
  static final _StatusVideoSoundBus instance = _StatusVideoSoundBus._();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool muted = false;

  Stream<bool> get stream => _controller.stream;

  void toggle() {
    muted = !muted;
    _controller.add(muted);
  }
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

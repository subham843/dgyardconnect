import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../data/shop_media_processor.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/entity_image_placements.dart';
import '../../domain/shop_image_display_slots.dart';
import '../../domain/shop_media_models.dart';
import 'entity_image_preview_widgets.dart';

/// Popup editor — separate zoom/pan per surface (homepage, category page, mobile, …).
class EntityImageEditorScreen extends StatefulWidget {
  const EntityImageEditorScreen({
    super.key,
    required this.imageBytes,
    required this.preset,
    required this.entityName,
    this.initialLayout = const BrandLogoLayout(),
    this.initialPlacements,
    this.sourceProvider,
    this.attribution,
  });

  final Uint8List imageBytes;
  final ShopImagePreset preset;
  final String entityName;
  final BrandLogoLayout initialLayout;
  final EntityImagePlacements? initialPlacements;
  final String? sourceProvider;
  final String? attribution;

  static Future<ProcessedShopImage?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required ShopImagePreset preset,
    required String entityName,
    BrandLogoLayout initialLayout = const BrandLogoLayout(),
    EntityImagePlacements? initialPlacements,
    String? sourceProvider,
    String? attribution,
  }) async {
    await _waitForNavigator();
    if (!context.mounted) return null;
    final edited = await showDialog<ProcessedShopImage>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => EntityImageEditorScreen(
        imageBytes: imageBytes,
        preset: preset,
        entityName: entityName,
        initialLayout: initialLayout,
        initialPlacements: initialPlacements,
        sourceProvider: sourceProvider,
        attribution: attribution,
      ),
    );
    return edited;
  }

  static Future<void> _waitForNavigator() async {
    await Future<void>.delayed(Duration.zero);
    await SchedulerBinding.instance.endOfFrame;
  }

  @override
  State<EntityImageEditorScreen> createState() => _EntityImageEditorScreenState();
}

class _EntityImageEditorScreenState extends State<EntityImageEditorScreen>
    with SingleTickerProviderStateMixin {
  late EntityImagePlacements _placements;
  late TabController _slotTabs;
  late Uint8List _workingBytes;
  late int _imgW;
  late int _imgH;
  var _busy = false;
  var _showGrid = false;

  static const _editorMaxWidth = 520.0;
  static const _bgSwatches = <Color>[
    Color(0xFF0F172A),
    Color(0xFF1E3A8A),
    Color(0xFF0D9488),
    Color(0xFF7C2D12),
    Color(0xFF1F2937),
    Colors.white,
    Color(0xFFF8FAFC),
    Color(0xFFE2E8F0),
  ];

  List<ShopImageDisplaySlot> get _slots => ShopImageDisplaySlots.forPreset(widget.preset);

  ShopImageDisplaySlot get _activeSlot => _slots[_slotTabs.index];

  BrandLogoLayout get _layout => _placements.layoutFor(_activeSlot.id);

  double get _canvasW => _editorMaxWidth;
  double get _canvasH => _editorMaxWidth / widget.preset.aspectRatio;

  @override
  void initState() {
    super.initState();
    _workingBytes = widget.imageBytes;
    final decoded = img.decodeImage(_workingBytes);
    _imgW = decoded?.width ?? 1;
    _imgH = decoded?.height ?? 1;
    if (widget.initialPlacements != null && widget.initialPlacements!.bySlot.isNotEmpty) {
      _placements = widget.initialPlacements!;
    } else if (!EntityImageFrameMath.isDefaultLayout(widget.initialLayout)) {
      _placements = EntityImagePlacements.fromSingle(widget.initialLayout, widget.preset);
    } else {
      _placements = EntityImagePlacements.autoFitForPreset(
        preset: widget.preset,
        sourceW: _imgW,
        sourceH: _imgH,
      );
    }
    _slotTabs = TabController(length: _slots.length, vsync: this);
    _slotTabs.addListener(() {
      if (_slotTabs.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _slotTabs.dispose();
    super.dispose();
  }

  double get _offsetScaleX => widget.preset.width / _canvasW;
  double get _offsetScaleY => widget.preset.height / _canvasH;

  void _setLayout(BrandLogoLayout layout) {
    setState(() => _placements = _placements.withSlot(_activeSlot.id, layout));
  }

  void _zoom(double delta) {
    _setLayout(_layout.copyWith(scale: (_layout.scale + delta).clamp(0.35, 4.0)));
  }

  void _pan(double dx, double dy) {
    _setLayout(_layout.copyWith(
      offsetX: _layout.offsetX + dx * _offsetScaleX,
      offsetY: _layout.offsetY + dy * _offsetScaleY,
    ));
  }

  void _reset() => _setLayout(_autoFitLayout());

  BrandLogoLayout _autoFitLayout() => EntityImageFrameMath.autoFitLayout(
        sourceW: _imgW,
        sourceH: _imgH,
        canvasW: widget.preset.width,
        canvasH: widget.preset.height,
      );

  void _fillFrame() => _setLayout(const BrandLogoLayout());

  void _fitToFrame() => _setLayout(_autoFitLayout());

  void _copyToAllSlots() {
    final current = _layout;
    setState(() => _placements = EntityImagePlacements.fromSingle(current, widget.preset));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Current framing copied to all surfaces')),
    );
  }

  void _rotate90() {
    final decoded = img.decodeImage(_workingBytes);
    if (decoded == null) return;
    final rotated = img.copyRotate(decoded, angle: 90);
    setState(() {
      _workingBytes = Uint8List.fromList(img.encodePng(rotated));
      _imgW = rotated.width;
      _imgH = rotated.height;
      _placements = EntityImagePlacements.autoFitForPreset(
        preset: widget.preset,
        sourceW: _imgW,
        sourceH: _imgH,
      );
    });
  }

  void _pickBackground(Color? color) {
    if (color == null) {
      _setLayout(_layout.copyWith(clearBackground: true));
    } else {
      _setLayout(_layout.copyWith(backgroundColorHex: BrandLogoLayout.colorToHex(color)));
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final defaultLayout = _placements.defaultLayout;
      final processed = await ShopMediaProcessor.processEntityImage(
        input: _workingBytes,
        preset: widget.preset,
        altText: ShopMediaProcessor.suggestAltText(entityName: widget.entityName, preset: widget.preset),
        layout: defaultLayout,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(
        processed.copyWith(
          sourceProvider: widget.sourceProvider ?? processed.sourceProvider,
          attribution: widget.attribution ?? processed.attribution,
          editorSourceBytes: _workingBytes,
          editorLayout: defaultLayout,
          editorPlacements: _placements,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not process image: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < 600 ? 12 : 32,
        vertical: size.height < 700 ? 12 : 28,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(
              title: '${widget.preset.label} — ${widget.entityName}',
              busy: _busy,
              onCancel: () => Navigator.of(context, rootNavigator: true).pop(),
              onConfirm: _busy ? null : _confirm,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pick a surface tab — adjust zoom/pan separately for homepage, category page, mobile, etc. '
                      'Each surface saves its own framing.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    TabBar(
                      controller: _slotTabs,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [for (final s in _slots) Tab(text: s.label)],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _copyToAllSlots,
                        icon: const Icon(Icons.copy_all_outlined, size: 18),
                        label: const Text('Copy to all surfaces'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _InteractiveCanvas(
                            bytes: _workingBytes,
                            sourceW: _imgW,
                            sourceH: _imgH,
                            width: _canvasW,
                            height: _canvasH,
                            outputW: widget.preset.width,
                            outputH: widget.preset.height,
                            layout: _layout,
                            showGrid: _showGrid,
                            onPan: _pan,
                            onZoom: _zoom,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Scale ${_layout.scale.toStringAsFixed(2)} · '
                      'Offset (${_layout.offsetX.toStringAsFixed(0)}, ${_layout.offsetY.toStringAsFixed(0)})',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _ToolSection(
                      title: 'Zoom',
                      child: Row(
                        children: [
                          IconButton.outlined(
                            onPressed: () => _zoom(-0.08),
                            icon: const Icon(Icons.remove),
                            tooltip: 'Zoom out',
                          ),
                          Expanded(
                            child: Slider(
                              value: _layout.scale.clamp(0.35, 4.0),
                              min: 0.35,
                              max: 4.0,
                              divisions: 73,
                              label: _layout.scale.toStringAsFixed(2),
                              onChanged: (v) => _setLayout(_layout.copyWith(scale: v)),
                            ),
                          ),
                          IconButton.outlined(
                            onPressed: () => _zoom(0.08),
                            icon: const Icon(Icons.add),
                            tooltip: 'Zoom in',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ToolSection(
                      title: 'Position',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _ToolBtn(icon: Icons.arrow_back, label: 'Left', onPressed: () => _pan(-16, 0)),
                          _ToolBtn(icon: Icons.arrow_forward, label: 'Right', onPressed: () => _pan(16, 0)),
                          _ToolBtn(icon: Icons.arrow_upward, label: 'Up', onPressed: () => _pan(0, -16)),
                          _ToolBtn(icon: Icons.arrow_downward, label: 'Down', onPressed: () => _pan(0, 16)),
                          _ToolBtn(icon: Icons.rotate_90_degrees_ccw, label: 'Rotate', onPressed: _rotate90),
                          _ToolBtn(icon: Icons.fit_screen, label: 'Fit', onPressed: _fitToFrame),
                          _ToolBtn(icon: Icons.crop_free, label: 'Fill', onPressed: _fillFrame),
                          _ToolBtn(icon: Icons.restart_alt, label: 'Reset', onPressed: _reset),
                          _ToolBtn(
                            icon: Icons.grid_on,
                            label: 'Grid',
                            selected: _showGrid,
                            onPressed: () => setState(() => _showGrid = !_showGrid),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ToolSection(
                      title: 'Background',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Default'),
                            onPressed: () => _pickBackground(const Color(0xFF0F172A)),
                          ),
                          for (final c in _bgSwatches)
                            _BgSwatch(
                              color: c,
                              selected: _layout.backgroundColor == c,
                              onTap: () => _pickBackground(c),
                            ),
                        ],
                      ),
                    ),
                    EntityImagePreviewStrip(
                      preset: widget.preset,
                      sourceBytes: _workingBytes,
                      sourceW: _imgW,
                      sourceH: _imgH,
                      placements: _placements,
                      highlightSlotId: _activeSlot.id,
                      title: 'Live previews (all surfaces)',
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

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: busy ? null : onCancel,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Image editor', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(title, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Apply'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolSection extends StatelessWidget {
  const _ToolSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
      label: Text(label),
      onSelected: (_) => onPressed(),
    );
  }
}

class _BgSwatch extends StatelessWidget {
  const _BgSwatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _InteractiveCanvas extends StatelessWidget {
  const _InteractiveCanvas({
    required this.bytes,
    required this.sourceW,
    required this.sourceH,
    required this.width,
    required this.height,
    required this.outputW,
    required this.outputH,
    required this.layout,
    required this.showGrid,
    required this.onPan,
    required this.onZoom,
  });

  final Uint8List bytes;
  final int sourceW;
  final int sourceH;
  final double width;
  final double height;
  final int outputW;
  final int outputH;
  final BrandLogoLayout layout;
  final bool showGrid;
  final void Function(double dx, double dy) onPan;
  final void Function(double delta) onZoom;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final delta = event.scrollDelta.dy > 0 ? -0.06 : 0.06;
          onZoom(delta);
        }
      },
      child: GestureDetector(
        onPanUpdate: (d) => onPan(d.delta.dx, d.delta.dy),
        child: Stack(
          children: [
            EntityImageCoverPreview(
              bytes: bytes,
              sourceW: sourceW,
              sourceH: sourceH,
              width: width,
              height: height,
              outputW: outputW,
              outputH: outputH,
              layout: layout,
            ),
            if (showGrid)
              Positioned.fill(
                child: CustomPaint(painter: _GridPainter()),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Drag to move', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 0.8;
    const thirds = 3;
    for (var i = 1; i < thirds; i++) {
      final x = size.width * i / thirds;
      final y = size.height * i / thirds;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<Uint8List?> loadEntityImageBytesFromUrl(String url) async {
  try {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
    if (res.statusCode >= 400) return null;
    return res.bodyBytes;
  } catch (_) {
    return null;
  }
}

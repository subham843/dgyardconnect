import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/widgets/brand_logo_canvas.dart';
import '../../data/shop_media_processor.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/shop_media_models.dart';
import 'brand_logo_source_flow.dart';
import 'entity_image_preview_widgets.dart';

class BrandLogoEditorScreen extends StatefulWidget {
  const BrandLogoEditorScreen({
    super.key,
    this.imageBytes,
    this.mimeType,
    required this.brandName,
    this.initialLayout = const BrandLogoLayout(),
    this.existingLogoUrl,
    this.existingMimeType,
  });

  final Uint8List? imageBytes;
  final String? mimeType;
  final String brandName;
  final BrandLogoLayout initialLayout;
  final String? existingLogoUrl;
  final String? existingMimeType;

  static Future<BrandLogoEditorResult?> show(
    BuildContext context, {
    Uint8List? imageBytes,
    String? mimeType,
    required String brandName,
    BrandLogoLayout initialLayout = const BrandLogoLayout(),
    String? existingLogoUrl,
    String? existingMimeType,
  }) async {
    await Future<void>.delayed(Duration.zero);
    await SchedulerBinding.instance.endOfFrame;
    if (!context.mounted) return null;
    return showDialog<BrandLogoEditorResult>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => BrandLogoEditorScreen(
        imageBytes: imageBytes,
        mimeType: mimeType,
        brandName: brandName,
        initialLayout: initialLayout,
        existingLogoUrl: existingLogoUrl,
        existingMimeType: existingMimeType,
      ),
    );
  }

  @override
  State<BrandLogoEditorScreen> createState() => _BrandLogoEditorScreenState();
}

class _BrandLogoEditorScreenState extends State<BrandLogoEditorScreen> {
  late BrandLogoLayout _layout;
  var _busy = false;
  String? _previewUrl;
  String? _previewMime;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _layout = widget.initialLayout;
    _previewBytes = widget.imageBytes;
    _previewMime = widget.mimeType ?? widget.existingMimeType;
    _previewUrl = widget.imageBytes == null ? widget.existingLogoUrl : null;
  }

  void _zoom(double delta) {
    setState(() {
      _layout = _layout.copyWith(
        scale: (_layout.scale + delta).clamp(0.4, 3.0),
      );
    });
  }

  void _pan(double dx, double dy) {
    setState(() {
      _layout = _layout.copyWith(
        offsetX: _layout.offsetX + dx,
        offsetY: _layout.offsetY + dy,
      );
    });
  }

  void _reset() {
    setState(() => _layout = const BrandLogoLayout());
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      ProcessedShopImage? processed;
      if (widget.imageBytes != null && widget.mimeType != null) {
        processed = await ShopMediaProcessor.processBrandLogo(
          input: widget.imageBytes!,
          altText: ShopMediaProcessor.suggestAltText(
            entityName: widget.brandName,
            preset: null,
            contextLabel: 'brand logo',
          ),
          mimeType: widget.mimeType!,
        );
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(
        BrandLogoEditorResult(processed: processed, layout: _layout),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not process logo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = BrandLogoCanvasPreset.adminEditor;
    final logoUrl = _previewUrl;
    final hasBytes = _previewBytes != null;

    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: size.width < 600 ? 12 : 32, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.of(context, rootNavigator: true).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Text(
                        'Brand logo — ${widget.brandName}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      FilledButton(onPressed: _confirm, child: const Text('Apply')),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            BrandLogoSourceFlow.uploadGuidance,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          Text('Editor canvas', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasBytes
                  ? _MemoryLogoCanvas(
                      bytes: _previewBytes!,
                      mimeType: _previewMime,
                      width: editor.width,
                      height: editor.height,
                      layout: _layout,
                      fallbackLabel: widget.brandName,
                    )
                  : BrandLogoCanvas(
                      width: editor.width,
                      height: editor.height,
                      logoUrl: logoUrl,
                      mimeType: _previewMime,
                      layout: _layout,
                      fallbackLabel: widget.brandName,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _ControlRow(
            onZoomIn: () => _zoom(0.1),
            onZoomOut: () => _zoom(-0.1),
            onLeft: () => _pan(-8, 0),
            onRight: () => _pan(8, 0),
            onUp: () => _pan(0, -8),
            onDown: () => _pan(0, 8),
            onReset: _reset,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final color = await showDialog<Color>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Canvas background'),
                      content: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ColorChip(Colors.transparent, label: 'None', onPick: () => Navigator.pop(ctx, null)),
                          for (final c in [Colors.white, const Color(0xFFF8FAFC), const Color(0xFF0F172A)])
                            _ColorChip(c, onPick: () => Navigator.pop(ctx, c)),
                        ],
                      ),
                    ),
                  );
                  if (!mounted) return;
                  setState(() {
                    if (color == null) {
                      _layout = _layout.copyWith(clearBackground: true);
                    } else {
                      _layout = _layout.copyWith(
                        backgroundColorHex: BrandLogoLayout.colorToHex(color),
                      );
                    }
                  });
                },
                icon: const Icon(Icons.format_color_fill_outlined),
                label: const Text('Background'),
              ),
              Text(
                'Scale ${_layout.scale.toStringAsFixed(2)} · '
                'Offset (${_layout.offsetX.toStringAsFixed(0)}, ${_layout.offsetY.toStringAsFixed(0)})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          BrandLogoPreviewStrip(
            brandName: widget.brandName,
            layout: _layout,
            bytes: _previewBytes,
            mimeType: _previewMime,
            logoUrl: logoUrl,
            title: 'Where this logo will appear',
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

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLeft,
    required this.onRight,
    required this.onUp,
    required this.onDown,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton(onPressed: onZoomOut, child: const Text('Zoom out')),
        OutlinedButton(onPressed: onZoomIn, child: const Text('Zoom in')),
        OutlinedButton(onPressed: onLeft, child: const Icon(Icons.arrow_back)),
        OutlinedButton(onPressed: onRight, child: const Icon(Icons.arrow_forward)),
        OutlinedButton(onPressed: onUp, child: const Icon(Icons.arrow_upward)),
        OutlinedButton(onPressed: onDown, child: const Icon(Icons.arrow_downward)),
        FilledButton.tonal(onPressed: onReset, child: const Text('Reset position')),
      ],
    );
  }
}

class _MemoryLogoCanvas extends StatelessWidget {
  const _MemoryLogoCanvas({
    required this.bytes,
    required this.width,
    required this.height,
    required this.layout,
    this.mimeType,
    this.fallbackLabel,
  });

  final Uint8List bytes;
  final double width;
  final double height;
  final BrandLogoLayout layout;
  final String? mimeType;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final isSvg = mimeType?.contains('svg') ?? false;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: layout.backgroundColor),
      clipBehavior: Clip.antiAlias,
      child: Transform.translate(
        offset: Offset(layout.offsetX, layout.offsetY),
        child: Transform.scale(
          scale: layout.scale,
          child: isSvg
              ? SvgPicture.memory(bytes, fit: BoxFit.contain, width: width, height: height)
              : Image.memory(bytes, fit: BoxFit.contain, width: width, height: height),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip(this.color, {this.label, required this.onPick});

  final Color color;
  final String? label;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label ?? ''),
      backgroundColor: color == Colors.transparent ? null : color,
      onPressed: onPick,
    );
  }
}

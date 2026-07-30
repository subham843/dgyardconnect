import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/widgets/brand_logo_canvas.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/shop_media_models.dart';
import '../media/brand_logo_editor_screen.dart';
import '../media/brand_logo_source_flow.dart';
import '../media/entity_image_preview_widgets.dart';

class BrandLogoField extends StatelessWidget {
  const BrandLogoField({
    super.key,
    required this.brandName,
    required this.layout,
    required this.onLayoutChanged,
    this.existingLogoUrl,
    this.existingMimeType,
    this.pendingProcessed,
    required this.onPendingChanged,
    required this.onClear,
  });

  final String brandName;
  final BrandLogoLayout layout;
  final ValueChanged<BrandLogoLayout> onLayoutChanged;
  final String? existingLogoUrl;
  final String? existingMimeType;
  final ProcessedShopImage? pendingProcessed;
  final ValueChanged<ProcessedShopImage?> onPendingChanged;
  final VoidCallback onClear;

  bool get _hasLogo =>
      pendingProcessed != null || (existingLogoUrl != null && existingLogoUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final canvas = BrandLogoCanvasPreset.adminEditor;
    final previewUrl = pendingProcessed?.publicUrl ?? existingLogoUrl;
    final previewMime = pendingProcessed?.mimeType ?? existingMimeType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Brand logo', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          BrandLogoSourceFlow.uploadGuidance,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 12),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: pendingProcessed != null
                ? _PendingLogoPreview(
                    processed: pendingProcessed!,
                    width: canvas.width,
                    height: canvas.height,
                    layout: layout,
                  )
                : BrandLogoCanvas(
                    width: canvas.width,
                    height: canvas.height,
                    logoUrl: previewUrl,
                    mimeType: previewMime,
                    layout: layout,
                    fallbackLabel: brandName,
                  ),
          ),
        ),
        BrandLogoPreviewStrip(
          brandName: brandName,
          layout: layout,
          bytes: pendingProcessed?.bytes,
          mimeType: previewMime,
          logoUrl: pendingProcessed == null ? previewUrl : null,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final result = await BrandLogoSourceFlow.pickAndEdit(
                  context,
                  brandName: brandName,
                  initialLayout: layout,
                  existingLogoUrl: existingLogoUrl,
                  existingMimeType: existingMimeType,
                );
                if (result == null) return;
                onLayoutChanged(result.layout);
                onPendingChanged(result.processed);
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_hasLogo ? 'Replace logo' : 'Upload logo'),
            ),
            if (_hasLogo)
              OutlinedButton.icon(
                onPressed: () async {
                  final result = pendingProcessed != null
                      ? await BrandLogoEditorScreen.show(
                          context,
                          imageBytes: pendingProcessed!.bytes,
                          mimeType: pendingProcessed!.mimeType,
                          brandName: brandName,
                          initialLayout: layout,
                        )
                      : existingLogoUrl != null && existingLogoUrl!.isNotEmpty
                          ? await BrandLogoSourceFlow.editExisting(
                              context,
                              brandName: brandName,
                              logoUrl: existingLogoUrl!,
                              mimeType: existingMimeType,
                              initialLayout: layout,
                            )
                          : null;
                  if (result != null) {
                    onLayoutChanged(result.layout);
                    if (result.processed != null) onPendingChanged(result.processed);
                  }
                },
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Adjust & preview'),
              ),
            if (_hasLogo)
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}

class _PendingLogoPreview extends StatelessWidget {
  const _PendingLogoPreview({
    required this.processed,
    required this.width,
    required this.height,
    required this.layout,
  });

  final ProcessedShopImage processed;
  final double width;
  final double height;
  final BrandLogoLayout layout;

  @override
  Widget build(BuildContext context) {
    final isSvg = processed.mimeType.contains('svg');
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
              ? SvgPicture.memory(processed.bytes, fit: BoxFit.contain, width: width, height: height)
              : Image.memory(processed.bytes, fit: BoxFit.contain, width: width, height: height),
        ),
      ),
    );
  }
}

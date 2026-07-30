import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/shop_media_processor.dart';
import '../../data/shop_media_storage_service.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/shop_media_models.dart';
import '../../../../core/editing/dg_image_search_context.dart';
import '../media/entity_image_editor_screen.dart';
import '../media/entity_image_preview_widgets.dart';
import '../media/entity_image_source_flow.dart';

/// Category / sub-category image — upload, Google, Gemini AI, zoom +/− editor.
class ShopEntityImageField extends StatelessWidget {
  const ShopEntityImageField({
    super.key,
    required this.label,
    required this.preset,
    required this.entityName,
    this.pending,
    this.existingUrl,
    required this.onPendingChanged,
    this.onClear,
    this.searchContext,
  });

  final String label;
  final ShopImagePreset preset;
  final String entityName;
  final ProcessedShopImage? pending;
  final String? existingUrl;
  final ValueChanged<ProcessedShopImage?> onPendingChanged;
  final VoidCallback? onClear;
  final DgImageSearchContext? searchContext;

  bool get _hasPendingPreview => pending != null && pending!.bytes.isNotEmpty;

  bool get _hasUrlPreview {
    final url = pending?.publicUrl ?? existingUrl;
    return url != null && url.isNotEmpty;
  }

  bool get _hasPreview => _hasPendingPreview || _hasUrlPreview;

  bool get _canAdjust => pending?.editorSourceBytes != null;

  @override
  Widget build(BuildContext context) {
    final networkUrl = _hasPendingPreview ? null : (pending?.publicUrl ?? existingUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Upload, Google, or Gemini AI → adjust with live previews for every page → Save uploads WebP.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: preset.aspectRatio,
            child: _hasPendingPreview
                ? Image.memory(pending!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
                : _hasUrlPreview && networkUrl != null
                    ? CachedNetworkImage(imageUrl: networkUrl, fit: BoxFit.cover)
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Text(
                          'No image yet',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
          ),
        ),
        if (_hasPendingPreview) ...[
          const SizedBox(height: 6),
          Text(
            'Preview (${ShopMediaProcessor.formatByteSize(pending!.bytes.length)} WebP)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        EntityImagePreviewStrip(
          preset: preset,
          sourceBytes: pending?.editorSourceBytes,
          layout: pending?.editorLayout ?? const BrandLogoLayout(),
          placements: pending?.editorPlacements,
          composedBytes: pending?.bytes,
          imageUrl: _hasPendingPreview ? null : networkUrl,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final processed = await EntityImageSourceFlow.pickProcessedImage(
                  context,
                  preset: preset,
                  entityName: entityName,
                  searchContext: searchContext ?? DgImageSearchContext(categoryName: entityName),
                );
                if (processed != null) onPendingChanged(processed);
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_hasPreview ? 'Change image' : 'Add image'),
            ),
            if (_canAdjust)
              OutlinedButton.icon(
                onPressed: () async {
                  final src = pending!.editorSourceBytes!;
                  final adjusted = await EntityImageSourceFlow.adjustExisting(
                    context,
                    preset: preset,
                    entityName: entityName,
                    sourceBytes: src,
                    initialLayout: pending!.editorLayout ?? const BrandLogoLayout(),
                    initialPlacements: pending!.editorPlacements,
                  );
                  if (adjusted != null) onPendingChanged(adjusted);
                },
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Adjust & preview'),
              ),
            if (_hasPreview && !_canAdjust && (pending?.publicUrl != null || existingUrl != null))
              OutlinedButton.icon(
                onPressed: () async {
                  final url = pending?.publicUrl ?? existingUrl;
                  if (url == null) return;
                  final bytes = await loadEntityImageBytesFromUrl(url);
                  if (!context.mounted) return;
                  if (bytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not load image for adjustment')),
                    );
                    return;
                  }
                  final adjusted = await EntityImageSourceFlow.adjustExisting(
                    context,
                    preset: preset,
                    entityName: entityName,
                    sourceBytes: bytes,
                  );
                  if (adjusted != null) onPendingChanged(adjusted);
                },
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Adjust & preview'),
              ),
            if (_hasPreview)
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
        if (pending != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Will upload on Save · ${pending!.altText}'
              '${pending!.attribution != null ? ' · ${pending!.attribution}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

Future<ProcessedShopImage?> uploadPendingCategoryImage({
  required String categoryId,
  required ProcessedShopImage? pending,
}) async {
  if (pending == null || pending.storagePath != null) return pending;
  return ShopMediaStorageService.uploadCategoryImage(categoryId: categoryId, processed: pending);
}

Future<ProcessedShopImage?> uploadPendingSubCategoryImage({
  required String subCategoryId,
  required ProcessedShopImage? pending,
}) async {
  if (pending == null || pending.storagePath != null) return pending;
  return ShopMediaStorageService.uploadSubCategoryImage(subCategoryId: subCategoryId, processed: pending);
}

Future<ProcessedShopImage?> uploadPendingBrandLogo({
  required String brandId,
  required ProcessedShopImage? pending,
}) async {
  if (pending == null || pending.storagePath != null) return pending;
  return ShopMediaStorageService.uploadBrandLogo(brandId: brandId, processed: pending);
}

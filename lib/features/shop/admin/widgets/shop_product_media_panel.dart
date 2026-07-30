import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/shop_media_processor.dart';
import '../../data/shop_media_repository.dart';
import '../../data/shop_media_storage_service.dart';
import '../../domain/shop_media_models.dart';
import '../../../../core/editing/dg_image_search_context.dart';
import '../media/entity_image_editor_screen.dart';
import '../media/entity_image_preview_widgets.dart';
import '../media/shop_image_source_flow.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/entity_image_placements.dart';

/// Product main + gallery + datasheets + brochures (upload on save).
class ShopProductMediaPanel extends StatefulWidget {
  const ShopProductMediaPanel({
    super.key,
    required this.productName,
    required this.items,
    required this.onChanged,
    this.mainPending,
    this.onMainPendingChanged,
    this.onClearMain,
    this.existingMainUrl,
    this.existingEditorSourceUrl,
    this.existingPlacements,
    this.existingSourceW,
    this.existingSourceH,
    this.searchContext,
    this.onDatasheetPdfAdded,
  });

  final String productName;
  final List<ShopProductMediaItem> items;
  final ValueChanged<List<ShopProductMediaItem>> onChanged;
  final ProcessedShopImage? mainPending;
  final ValueChanged<ProcessedShopImage?>? onMainPendingChanged;
  final VoidCallback? onClearMain;
  final String? existingMainUrl;
  final String? existingEditorSourceUrl;
  final EntityImagePlacements? existingPlacements;
  final int? existingSourceW;
  final int? existingSourceH;
  final DgImageSearchContext? searchContext;
  final void Function(List<int> bytes, String fileName)? onDatasheetPdfAdded;

  @override
  State<ShopProductMediaPanel> createState() => _ShopProductMediaPanelState();
}

class _ShopProductMediaPanelState extends State<ShopProductMediaPanel> {
  Uint8List? _cachedEditorSourceBytes;

  List<ShopProductMediaItem> get _items => widget.items;

  @override
  void initState() {
    super.initState();
    _loadExistingEditorSource();
  }

  @override
  void didUpdateWidget(covariant ShopProductMediaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingEditorSourceUrl != widget.existingEditorSourceUrl) {
      _cachedEditorSourceBytes = null;
      _loadExistingEditorSource();
    }
  }

  Future<void> _loadExistingEditorSource() async {
    final url = widget.existingEditorSourceUrl?.trim();
    if (url == null || url.isEmpty) return;
    final bytes = await loadEntityImageBytesFromUrl(url);
    if (mounted && bytes != null) {
      setState(() => _cachedEditorSourceBytes = bytes);
    }
  }

  void _update(List<ShopProductMediaItem> next) => widget.onChanged(next);

  Future<void> _addMain() async {
    final processed = await ShopImageSourceFlow.pickProcessedImage(
      context,
      preset: ShopImagePreset.productMain,
      altTextHint: widget.productName,
      searchContext: widget.searchContext ??
          DgImageSearchContext(productName: widget.productName),
    );
    if (processed != null) widget.onMainPendingChanged?.call(processed);
  }

  Future<void> _adjustMain(ProcessedShopImage current) async {
    final src = current.editorSourceBytes;
    if (src == null) return;
    final adjusted = await ShopImageSourceFlow.adjustExisting(
      context,
      sourceBytes: src,
      preset: ShopImagePreset.productMain,
      altTextHint: widget.productName,
      initialLayout: current.editorLayout ?? const BrandLogoLayout(),
      initialPlacements: current.editorPlacements,
      sourceProvider: current.sourceProvider,
      attribution: current.attribution,
    );
    if (adjusted != null) widget.onMainPendingChanged?.call(adjusted);
  }

  Future<void> _adjustMainFromUrl(String url) async {
    final sourceUrl = widget.existingEditorSourceUrl?.trim();
    final bytes = await loadEntityImageBytesFromUrl(
      (sourceUrl != null && sourceUrl.isNotEmpty) ? sourceUrl : url,
    );
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load image')));
      return;
    }
    final adjusted = await ShopImageSourceFlow.adjustExisting(
      context,
      sourceBytes: bytes,
      preset: ShopImagePreset.productMain,
      altTextHint: widget.productName,
      initialPlacements: widget.existingPlacements,
    );
    if (adjusted != null) widget.onMainPendingChanged?.call(adjusted);
  }

  Future<void> _adjustGalleryItem(ShopProductMediaItem item) async {
    final src = item.editorSourceBytes;
    if (src == null && item.publicUrl.isEmpty) return;
    final bytes = src ?? await loadEntityImageBytesFromUrl(item.publicUrl);
    if (!mounted || bytes == null) return;
    final adjusted = await ShopImageSourceFlow.adjustExisting(
      context,
      sourceBytes: bytes,
      preset: ShopImagePreset.productGallery,
      altTextHint: widget.productName,
      initialLayout: item.editorLayout ?? const BrandLogoLayout(),
      initialPlacements: item.editorPlacements,
      sourceProvider: item.sourceProvider,
      attribution: item.attribution,
    );
    if (adjusted == null) return;
    _update(_items.map((i) {
      if (i != item) return i;
      return i.copyWith(
        pendingBytes: adjusted.bytes,
        pendingThumbBytes: adjusted.thumbBytes,
        mimeType: adjusted.mimeType,
        altText: adjusted.altText,
        editorSourceBytes: adjusted.editorSourceBytes,
        editorLayout: adjusted.editorLayout,
        editorPlacements: adjusted.editorPlacements,
      );
    }).toList());
  }

  Future<void> _addGallery() async {
    final processed = await ShopImageSourceFlow.pickProcessedImage(
      context,
      preset: ShopImagePreset.productGallery,
      altTextHint: widget.productName,
      searchContext: widget.searchContext ??
          DgImageSearchContext(productName: widget.productName),
    );
    if (processed == null) return;
    final gallery = _items.where((i) => i.kind == ShopProductMediaKind.gallery && !i.markedForDelete).toList();
    _update([
      ..._items,
      ShopProductMediaItem(
        kind: ShopProductMediaKind.gallery,
        publicUrl: '',
        altText: processed.altText,
        sortOrder: gallery.length,
        pendingBytes: processed.bytes,
        pendingThumbBytes: processed.thumbBytes,
        mimeType: processed.mimeType,
        sourceUrl: processed.sourceUrl,
        sourceProvider: processed.sourceProvider,
        attribution: processed.attribution,
        editorSourceBytes: processed.editorSourceBytes,
        editorLayout: processed.editorLayout,
      ),
    ]);
  }

  Future<void> _addDocument(ShopProductMediaKind kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kind == ShopProductMediaKind.datasheet ? ['pdf'] : ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final docs = _items.where((i) => i.kind == kind && !i.markedForDelete).length;
    _update([
      ..._items,
      ShopProductMediaItem(
        kind: kind,
        publicUrl: '',
        fileName: f.name,
        mimeType: 'application/pdf',
        sortOrder: docs,
        pendingBytes: bytes,
        altText: f.name,
      ),
    ]);
    if (kind == ShopProductMediaKind.datasheet) {
      widget.onDatasheetPdfAdded?.call(bytes, f.name);
    }
  }

  List<ShopProductMediaItem> get _galleryVisible =>
      _items.where((i) => i.kind == ShopProductMediaKind.gallery && !i.markedForDelete).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Widget build(BuildContext context) {
    final mainUrl = widget.existingMainUrl;
    final mainPreview = widget.mainPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Media', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Upload from device only. Images open the editor before upload.'),
        const SizedBox(height: 16),
        Text('Main image', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _MainPreview(url: mainUrl, pending: mainPreview),
        EntityImagePreviewStrip(
          preset: ShopImagePreset.productMain,
          sourceBytes: mainPreview?.editorSourceBytes ?? _cachedEditorSourceBytes,
          sourceW: mainPreview != null ? null : widget.existingSourceW,
          sourceH: mainPreview != null ? null : widget.existingSourceH,
          layout: mainPreview?.editorLayout ?? const BrandLogoLayout(),
          placements: mainPreview?.editorPlacements ?? widget.existingPlacements,
          composedBytes: mainPreview?.bytes,
          imageUrl: mainPreview == null && _cachedEditorSourceBytes == null ? mainUrl : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(onPressed: _addMain, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Main image')),
            if (mainPreview?.editorSourceBytes != null)
              OutlinedButton.icon(
                onPressed: () => _adjustMain(mainPreview!),
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Adjust & preview'),
              ),
            if ((mainUrl?.isNotEmpty ?? false) && mainPreview?.editorSourceBytes == null)
              OutlinedButton.icon(
                onPressed: () => _adjustMainFromUrl(mainUrl!),
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Adjust & preview'),
              ),
            if (mainUrl != null || mainPreview != null)
              TextButton(
                onPressed: () {
                  widget.onMainPendingChanged?.call(null);
                  widget.onClearMain?.call();
                },
                child: const Text('Remove'),
              ),
          ],
        ),
        const Divider(height: 32),
        Row(
          children: [
            Text('Gallery', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(onPressed: _addGallery, icon: const Icon(Icons.add), label: const Text('Add')),
          ],
        ),
        const SizedBox(height: 8),
        if (_galleryVisible.isEmpty)
          const Text('No gallery images')
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _galleryVisible.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final list = List<ShopProductMediaItem>.from(_galleryVisible);
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
              final others = _items.where((i) => i.kind != ShopProductMediaKind.gallery || i.markedForDelete).toList();
              for (var i = 0; i < list.length; i++) {
                list[i] = list[i].copyWith(sortOrder: i);
              }
              _update([...others, ...list]);
            },
            itemBuilder: (context, index) {
              final item = _galleryVisible[index];
              return ListTile(
                key: ValueKey(item.id ?? 'pending_$index'),
                leading: _thumb(item),
                title: Text(item.altText ?? 'Gallery ${index + 1}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(item.isPrimary ? Icons.star : Icons.star_border),
                      onPressed: () {
                        final next = _items.map((i) {
                          if (i.kind != ShopProductMediaKind.gallery) return i;
                          return i.copyWith(isPrimary: i == item);
                        }).toList();
                        _update(next);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune_outlined),
                      tooltip: 'Adjust & preview',
                      onPressed: () => _adjustGalleryItem(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final next = _items.map((i) => i == item ? i.copyWith(markedForDelete: true) : i).toList();
                        _update(next);
                      },
                    ),
                    const Icon(Icons.drag_handle),
                  ],
                ),
              );
            },
          ),
        const Divider(height: 32),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _addDocument(ShopProductMediaKind.datasheet),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Datasheet (PDF)'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addDocument(ShopProductMediaKind.brochure),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Brochure (PDF)'),
            ),
          ],
        ),
        ..._items.where((i) => (i.kind == ShopProductMediaKind.datasheet || i.kind == ShopProductMediaKind.brochure) && !i.markedForDelete).map(
          (doc) => ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(doc.fileName ?? doc.altText ?? 'Document'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _update(_items.map((i) => i == doc ? i.copyWith(markedForDelete: true) : i).toList());
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumb(ShopProductMediaItem item) {
    if (item.pendingBytes != null) {
      return Image.memory(item.pendingBytes!, width: 48, height: 48, fit: BoxFit.cover);
    }
    if (item.publicUrl.isNotEmpty) {
      return Image.network(item.publicUrl, width: 48, height: 48, fit: BoxFit.cover);
    }
    return const SizedBox(width: 48, height: 48, child: Icon(Icons.image_outlined));
  }
}

class _MainPreview extends StatelessWidget {
  const _MainPreview({this.url, this.pending});

  final String? url;
  final ProcessedShopImage? pending;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: pending != null && pending!.bytes.isNotEmpty
            ? Image.memory(pending!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : url != null && url!.isNotEmpty
                ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(child: Text('No main image')),
                  ),
      ),
    );
  }
}

/// True when save must upload/delete media (skip otherwise for faster save).
bool productMediaHasPendingWork({
  required ProcessedShopImage? mainPending,
  required List<ShopProductMediaItem> items,
}) {
  if (mainPending != null && mainPending.storagePath == null) return true;
  for (final item in items) {
    if (item.markedForDelete && (item.id != null || item.storagePath != null)) return true;
    if (item.pendingBytes != null) return true;
  }
  return false;
}

/// Persist all pending product media after product id is known.
Future<void> persistProductMediaOnSave({
  required String productId,
  required String productName,
  required ProcessedShopImage? mainPending,
  required String? existingMainUrl,
  required List<ShopProductMediaItem> items,
  required ShopMediaRepository repo,
}) async {
  if (!productMediaHasPendingWork(mainPending: mainPending, items: items)) return;

  var mainUrl = existingMainUrl;

  if (mainPending != null && mainPending.storagePath == null) {
    final up = await ShopMediaStorageService.uploadProductMain(
      productId: productId,
      processed: mainPending,
    );
    await repo.applyProductMainMedia(productId, uploaded: up);
    mainUrl = up.publicUrl;
  } else if (mainPending?.publicUrl != null && mainPending!.publicUrl!.isNotEmpty) {
    mainUrl = mainPending.publicUrl;
  }

  final galleryUrls = <String>[];
  final galleryItems = items
      .where((i) => i.kind == ShopProductMediaKind.gallery && !i.markedForDelete)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<ShopProductMediaItem> uploadGallery(ShopProductMediaItem item, int sort) async {
    final processed = ProcessedShopImage(
      bytes: item.pendingBytes!,
      thumbBytes: item.pendingThumbBytes ?? item.pendingBytes!,
      mimeType: item.mimeType ?? 'image/webp',
      width: ShopImagePreset.productGallery.width,
      height: ShopImagePreset.productGallery.height,
      altText: item.altText ??
          ShopMediaProcessor.suggestAltText(
            entityName: productName,
            preset: ShopImagePreset.productGallery,
          ),
    );
    final saved = await ShopMediaStorageService.uploadProductGalleryItem(
      productId: productId,
      processed: processed,
      sortOrder: sort,
      isPrimary: item.isPrimary,
    );
    await repo.upsertProductMediaRow(productId: productId, item: saved);
    return saved;
  }

  final uploadTasks = <Future<ShopProductMediaItem>>[];
  final uploadSorts = <int>[];
  for (var sort = 0; sort < galleryItems.length; sort++) {
    final item = galleryItems[sort];
    if (item.markedForDelete || item.pendingBytes == null) continue;
    uploadSorts.add(sort);
    uploadTasks.add(uploadGallery(item, sort));
  }
  final uploaded = uploadTasks.isEmpty ? <ShopProductMediaItem>[] : await Future.wait(uploadTasks);
  final uploadedBySort = {for (var i = 0; i < uploaded.length; i++) uploadSorts[i]: uploaded[i]};

  for (var sort = 0; sort < galleryItems.length; sort++) {
    final item = galleryItems[sort];
    if (item.markedForDelete) continue;
    final saved = uploadedBySort[sort] ?? item;
    if (saved.publicUrl.isNotEmpty) galleryUrls.add(saved.publicUrl);
  }

  final savedItems = <ShopProductMediaItem>[];
  final docUploads = <Future<void>>[];
  for (final item in items) {
    if (item.markedForDelete) {
      docUploads.add(() async {
        if (item.id != null) await repo.deleteProductMediaRow(item.id!);
        if (item.storagePath != null) await ShopMediaStorageService.removePath(item.storagePath);
      }());
      continue;
    }
    if (item.kind == ShopProductMediaKind.datasheet || item.kind == ShopProductMediaKind.brochure) {
      if (item.pendingBytes != null) {
        docUploads.add(() async {
          final saved = await ShopMediaStorageService.uploadProductDocument(
            productId: productId,
            kind: item.kind,
            bytes: item.pendingBytes!,
            fileName: item.fileName ?? 'file.pdf',
            mimeType: item.mimeType ?? 'application/pdf',
            sortOrder: item.sortOrder,
            altText: item.altText,
          );
          await repo.upsertProductMediaRow(productId: productId, item: saved);
          savedItems.add(saved);
        }());
      } else if (item.publicUrl.isNotEmpty) {
        savedItems.add(item);
      }
    }
  }
  if (docUploads.isNotEmpty) await Future.wait(docUploads);

  await repo.syncProductImagesTable(
    productId: productId,
    mainUrl: mainUrl,
    galleryUrls: galleryUrls,
  );
  await repo.syncProductDocumentMetadata(productId, [...galleryItems, ...savedItems]);
}

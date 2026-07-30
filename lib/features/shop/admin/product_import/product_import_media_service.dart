import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/shop_media_processor.dart';
import '../../data/shop_media_repository.dart';
import '../../domain/shop_media_models.dart';
import '../widgets/shop_product_media_panel.dart';

abstract final class ProductImportMediaService {
  static Future<Uint8List?> downloadBytes(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final res = await http.get(uri, headers: const {
        'User-Agent': 'DG-Yard-Connect-Product-Import/1.0',
        'Accept': 'image/*,application/pdf,*/*',
      }).timeout(const Duration(seconds: 25));
      if (res.statusCode >= 400) return null;
      return res.bodyBytes;
    } catch (e) {
      debugPrint('ProductImportMediaService download failed: $url — $e');
      return null;
    }
  }

  static Future<ProcessedShopImage?> downloadMainImage({
    required String url,
    required String productName,
  }) async {
    final bytes = await downloadBytes(url);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return ShopMediaProcessor.process(
        input: bytes,
        preset: ShopImagePreset.productMain,
        altText: ShopMediaProcessor.suggestAltText(
          entityName: productName,
          preset: ShopImagePreset.productMain,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<ShopProductMediaItem>> buildMediaItems({
    required String productName,
    required List<String> imageUrls,
    required List<String> datasheetUrls,
    required List<String> manualUrls,
    ProcessedShopImage? mainImage,
  }) async {
    final items = <ShopProductMediaItem>[];
    var gallerySort = 0;

    if (mainImage != null) {
      // main handled separately via mainPending
    }

    for (final url in imageUrls.take(8)) {
      final bytes = await downloadBytes(url);
      if (bytes == null) continue;
      try {
        final processed = await ShopMediaProcessor.process(
          input: bytes,
          preset: ShopImagePreset.productGallery,
          altText: ShopMediaProcessor.suggestAltText(
            entityName: productName,
            preset: ShopImagePreset.productGallery,
          ),
        );
        items.add(ShopProductMediaItem(
          kind: ShopProductMediaKind.gallery,
          publicUrl: '',
          sortOrder: gallerySort++,
          pendingBytes: processed.bytes,
          pendingThumbBytes: processed.thumbBytes,
          mimeType: processed.mimeType,
          altText: processed.altText,
        ));
      } catch (_) {}
    }

    for (final url in datasheetUrls.take(3)) {
      final bytes = await downloadBytes(url);
      if (bytes == null) continue;
      items.add(ShopProductMediaItem(
        kind: ShopProductMediaKind.datasheet,
        publicUrl: '',
        fileName: _fileNameFromUrl(url, 'datasheet.pdf'),
        mimeType: 'application/pdf',
        sortOrder: items.where((i) => i.kind == ShopProductMediaKind.datasheet).length,
        pendingBytes: bytes,
        altText: _fileNameFromUrl(url, 'datasheet.pdf'),
      ));
    }

    for (final url in manualUrls.take(3)) {
      final bytes = await downloadBytes(url);
      if (bytes == null) continue;
      items.add(ShopProductMediaItem(
        kind: ShopProductMediaKind.brochure,
        publicUrl: '',
        fileName: _fileNameFromUrl(url, 'manual.pdf'),
        mimeType: 'application/pdf',
        sortOrder: items.where((i) => i.kind == ShopProductMediaKind.brochure).length,
        pendingBytes: bytes,
        altText: _fileNameFromUrl(url, 'manual.pdf'),
      ));
    }

    return items;
  }

  static String _fileNameFromUrl(String url, String fallback) {
    try {
      final path = Uri.parse(url).pathSegments.last;
      if (path.isNotEmpty) return path;
    } catch (_) {}
    return fallback;
  }

  static Future<void> persistAll({
    required String productId,
    required String productName,
    required ProcessedShopImage? mainPending,
    required List<ShopProductMediaItem> items,
    ShopMediaRepository? repo,
  }) async {
    await persistProductMediaOnSave(
      productId: productId,
      productName: productName,
      mainPending: mainPending,
      existingMainUrl: null,
      items: items,
      repo: repo ?? ShopMediaRepository(),
    );
  }
}

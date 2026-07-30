import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../domain/shop_media_models.dart';
import 'shop_media_processor.dart';

/// Upload shop media to Supabase Storage bucket `shop-media` (after editor confirm).
abstract final class ShopMediaStorageService {
  ShopMediaStorageService._();

  static const bucket = 'shop-media';
  static const _uuid = Uuid();

  static SupabaseClient? get _client => SupabaseBootstrap.clientOrNull;

  static String categoryImagePath(String categoryId) =>
      'categories/$categoryId/${_uuid.v4()}.webp';

  static String categoryThumbPath(String categoryId) =>
      'categories/$categoryId/${_uuid.v4()}_thumb.webp';

  static String categorySourcePath(String categoryId) =>
      'categories/$categoryId/source_${_uuid.v4()}.webp';

  static String subCategorySourcePath(String subCategoryId) =>
      'subcategories/$subCategoryId/source_${_uuid.v4()}.webp';

  static String productMainSourcePath(String productId) =>
      'products/$productId/source_${_uuid.v4()}.webp';

  static String subCategoryImagePath(String subCategoryId) =>
      'subcategories/$subCategoryId/${_uuid.v4()}.webp';

  static String subCategoryThumbPath(String subCategoryId) =>
      'subcategories/$subCategoryId/${_uuid.v4()}_thumb.webp';

  static String brandLogoPath(String brandId, String extension) =>
      'brands/$brandId/${_uuid.v4()}.$extension';

  static String brandLogoThumbPath(String brandId, String extension) =>
      'brands/$brandId/${_uuid.v4()}_thumb.$extension';

  static String productMainPath(String productId) => 'products/$productId/main_${_uuid.v4()}.webp';

  static String productMainThumbPath(String productId) =>
      'products/$productId/main_${_uuid.v4()}_thumb.webp';

  static String productGalleryPath(String productId, int sort) =>
      'products/$productId/gallery_${sort}_${_uuid.v4()}.webp';

  static String productDocumentPath(String productId, String kind, String fileName) =>
      'products/$productId/$kind/${_uuid.v4()}_$fileName';

  static Future<String> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final c = _client;
    if (c == null) throw StateError('Supabase not initialized');
    await c.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return c.storage.from(bucket).getPublicUrl(storagePath);
  }

  /// Main + thumb in parallel (faster product save on web).
  static Future<String> uploadMainAndThumb({
    required String mainPath,
    required Uint8List mainBytes,
    required String mainContentType,
    required String thumbPath,
    required Uint8List thumbBytes,
  }) async {
    await Future.wait([
      uploadBytes(storagePath: mainPath, bytes: mainBytes, contentType: mainContentType),
      uploadBytes(storagePath: thumbPath, bytes: thumbBytes, contentType: 'image/webp'),
    ]);
    final c = _client;
    if (c == null) throw StateError('Supabase not initialized');
    return c.storage.from(bucket).getPublicUrl(mainPath);
  }

  static Future<void> removePath(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    final c = _client;
    if (c == null) return;
    try {
      await c.storage.from(bucket).remove([storagePath]);
    } catch (_) {}
  }

  static Future<ProcessedShopImage> uploadCategoryImage({
    required String categoryId,
    required ProcessedShopImage processed,
  }) async {
    final mainPath = categoryImagePath(categoryId);
    final thumbPath = categoryThumbPath(categoryId);
    String? sourcePath;
    String? sourceUrl;
    final sourceBytes = processed.editorSourceBytes;
    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      sourcePath = categorySourcePath(categoryId);
      sourceUrl = await uploadBytes(
        storagePath: sourcePath,
        bytes: sourceBytes,
        contentType: 'image/webp',
      );
    }
    final url = await uploadBytes(
      storagePath: mainPath,
      bytes: processed.bytes,
      contentType: processed.mimeType,
    );
    await uploadBytes(
      storagePath: thumbPath,
      bytes: processed.thumbBytes,
      contentType: 'image/webp',
    );
    return ProcessedShopImage(
      bytes: processed.bytes,
      thumbBytes: processed.thumbBytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      altText: processed.altText,
      storagePath: mainPath,
      thumbPath: thumbPath,
      webpPath: mainPath,
      publicUrl: url,
      editorSourceBytes: sourceBytes,
      editorLayout: processed.editorLayout,
      editorPlacements: processed.editorPlacements,
      editorSourceStoragePath: sourcePath,
      editorSourcePublicUrl: sourceUrl,
    );
  }

  static Future<ProcessedShopImage> uploadBrandLogo({
    required String brandId,
    required ProcessedShopImage processed,
  }) async {
    final ext = ShopMediaProcessor.extensionForMime(processed.mimeType);
    final mainPath = brandLogoPath(brandId, ext);
    final thumbPath = brandLogoThumbPath(brandId, ext == 'svg' ? 'svg' : 'webp');
    final url = await uploadBytes(
      storagePath: mainPath,
      bytes: processed.bytes,
      contentType: processed.mimeType,
    );
    await uploadBytes(
      storagePath: thumbPath,
      bytes: processed.thumbBytes,
      contentType: 'image/webp',
    );
    return ProcessedShopImage(
      bytes: processed.bytes,
      thumbBytes: processed.thumbBytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      altText: processed.altText,
      storagePath: mainPath,
      thumbPath: thumbPath,
      webpPath: mainPath,
      publicUrl: url,
      sourceUrl: processed.sourceUrl,
      sourceProvider: processed.sourceProvider,
      attribution: processed.attribution,
    );
  }

  static Future<ProcessedShopImage> uploadSubCategoryImage({
    required String subCategoryId,
    required ProcessedShopImage processed,
  }) async {
    final mainPath = subCategoryImagePath(subCategoryId);
    final thumbPath = subCategoryThumbPath(subCategoryId);
    final url = await uploadBytes(
      storagePath: mainPath,
      bytes: processed.bytes,
      contentType: processed.mimeType,
    );
    await uploadBytes(
      storagePath: thumbPath,
      bytes: processed.thumbBytes,
      contentType: 'image/webp',
    );
    return ProcessedShopImage(
      bytes: processed.bytes,
      thumbBytes: processed.thumbBytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      altText: processed.altText,
      storagePath: mainPath,
      thumbPath: thumbPath,
      webpPath: mainPath,
      publicUrl: url,
    );
  }

  static Future<ProcessedShopImage> uploadProductMain({
    required String productId,
    required ProcessedShopImage processed,
  }) async {
    final mainPath = productMainPath(productId);
    final thumbPath = productMainThumbPath(productId);
    String? sourcePath;
    String? sourceUrl;
    final sourceBytes = processed.editorSourceBytes;
    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      sourcePath = productMainSourcePath(productId);
      sourceUrl = await uploadBytes(
        storagePath: sourcePath,
        bytes: sourceBytes,
        contentType: 'image/webp',
      );
    }
    final url = await uploadMainAndThumb(
      mainPath: mainPath,
      mainBytes: processed.bytes,
      mainContentType: processed.mimeType,
      thumbPath: thumbPath,
      thumbBytes: processed.thumbBytes,
    );
    return ProcessedShopImage(
      bytes: processed.bytes,
      thumbBytes: processed.thumbBytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      altText: processed.altText,
      storagePath: mainPath,
      thumbPath: thumbPath,
      webpPath: mainPath,
      publicUrl: url,
      sourceUrl: processed.sourceUrl,
      sourceProvider: processed.sourceProvider,
      attribution: processed.attribution,
      editorSourceBytes: sourceBytes,
      editorLayout: processed.editorLayout,
      editorPlacements: processed.editorPlacements,
      editorSourceStoragePath: sourcePath,
      editorSourcePublicUrl: sourceUrl,
    );
  }

  static Future<ShopProductMediaItem> uploadProductGalleryItem({
    required String productId,
    required ProcessedShopImage processed,
    required int sortOrder,
    bool isPrimary = false,
  }) async {
    final path = productGalleryPath(productId, sortOrder);
    final thumbPath = '${path.replaceAll('.webp', '')}_thumb.webp';
    final url = await uploadMainAndThumb(
      mainPath: path,
      mainBytes: processed.bytes,
      mainContentType: processed.mimeType,
      thumbPath: thumbPath,
      thumbBytes: processed.thumbBytes,
    );
    return ShopProductMediaItem(
      kind: ShopProductMediaKind.gallery,
      publicUrl: url,
      storagePath: path,
      thumbPath: thumbPath,
      webpPath: path,
      altText: processed.altText,
      mimeType: processed.mimeType,
      sortOrder: sortOrder,
      isPrimary: isPrimary,
    );
  }

  static Future<ShopProductMediaItem> uploadProductDocument({
    required String productId,
    required ShopProductMediaKind kind,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required int sortOrder,
    String? altText,
  }) async {
    final folder = kind == ShopProductMediaKind.datasheet ? 'datasheets' : 'brochures';
    final path = productDocumentPath(productId, folder, fileName);
    final url = await uploadBytes(storagePath: path, bytes: bytes, contentType: mimeType);
    return ShopProductMediaItem(
      kind: kind,
      publicUrl: url,
      storagePath: path,
      fileName: fileName,
      mimeType: mimeType,
      sortOrder: sortOrder,
      altText: altText ?? fileName,
    );
  }
}

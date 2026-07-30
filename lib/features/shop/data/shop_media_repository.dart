import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../domain/entity_image_placements.dart';
import '../domain/shop_media_models.dart';
import 'supabase_repository_base.dart';

int? _decodeWidth(Uint8List bytes) => img.decodeImage(bytes)?.width;
int? _decodeHeight(Uint8List bytes) => img.decodeImage(bytes)?.height;

class ShopMediaRepository {
  Future<List<ShopProductMediaItem>> listProductMedia(String productId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('product_media_assets')
        .select()
        .eq('product_id', productId)
        .order('sort_order');
    return (rows as List)
        .map((e) => ShopProductMediaItem.fromRow(SupabaseRepositoryBase.rowToMap(e)))
        .toList();
  }

  Future<void> upsertProductMediaRow({
    required String productId,
    required ShopProductMediaItem item,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('product_media_assets').insert({
      'product_id': productId,
      'media_type': item.kind.name,
      'storage_path': item.storagePath,
      'public_url': item.publicUrl,
      'webp_path': item.webpPath,
      'thumb_path': item.thumbPath,
      'alt_text': item.altText,
      'file_name': item.fileName,
      'mime_type': item.mimeType,
      'sort_order': item.sortOrder,
      'is_primary': item.isPrimary,
      'source_url': item.sourceUrl,
      'source_provider': item.sourceProvider,
      'attribution': item.attribution,
    });
  }

  Future<void> deleteProductMediaRow(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('product_media_assets').delete().eq('id', id);
  }

  Future<void> syncProductImagesTable({
    required String productId,
    required String? mainUrl,
    required List<String> galleryUrls,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('product_images').delete().eq('product_id', productId);
    final urls = <String>[];
    if (mainUrl != null && mainUrl.isNotEmpty) urls.add(mainUrl);
    for (final u in galleryUrls) {
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }
    for (var i = 0; i < urls.length; i++) {
      await c.from('product_images').insert({
        'product_id': productId,
        'url': urls[i],
        'sort_order': i,
      });
    }
  }

  Future<void> applyCategoryMedia(
    String categoryId, {
    required ProcessedShopImage? uploaded,
    bool clear = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    if (clear) {
      await c.from('categories').update({
        'image_storage_path': null,
        'image_thumb_path': null,
        'image_webp_path': null,
        'image_alt_text': null,
        'image_url': null,
        'og_image': null,
        'image_editor_source_url': null,
        'image_editor_source_storage_path': null,
        'image_source_width': null,
        'image_source_height': null,
        'image_placements': {},
      }).eq('id', categoryId);
      return;
    }
    if (uploaded == null) return;
    final src = uploaded.editorSourceBytes;
    await c.from('categories').update({
      'image_storage_path': uploaded.storagePath,
      'image_thumb_path': uploaded.thumbPath,
      'image_webp_path': uploaded.webpPath,
      'image_alt_text': uploaded.altText,
      'image_url': uploaded.publicUrl,
      'og_image': uploaded.publicUrl,
      'image_source_url': uploaded.sourceUrl,
      'image_source_provider': uploaded.sourceProvider,
      'image_attribution': uploaded.attribution,
      'image_editor_source_url': uploaded.editorSourcePublicUrl,
      'image_editor_source_storage_path': uploaded.editorSourceStoragePath,
      'image_source_width': src != null ? _decodeWidth(src) : null,
      'image_source_height': src != null ? _decodeHeight(src) : null,
      'image_placements': uploaded.editorPlacements?.toJson() ?? {},
    }).eq('id', categoryId);
  }

  Future<void> applyBrandMedia(
    String brandId, {
    required ProcessedShopImage? uploaded,
    bool clear = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    if (clear) {
      await c.from('brands').update({
        'logo_storage_path': null,
        'logo_thumb_path': null,
        'logo_alt_text': null,
        'logo_url': null,
        'logo_mime_type': null,
        'image_source_url': null,
        'image_source_provider': null,
        'image_attribution': null,
      }).eq('id', brandId);
      return;
    }
    if (uploaded == null) return;
    await c.from('brands').update({
      'logo_storage_path': uploaded.storagePath,
      'logo_thumb_path': uploaded.thumbPath,
      'logo_alt_text': uploaded.altText,
      'logo_url': uploaded.publicUrl,
      'logo_mime_type': uploaded.mimeType,
      'image_source_url': uploaded.sourceUrl,
      'image_source_provider': uploaded.sourceProvider,
      'image_attribution': uploaded.attribution,
    }).eq('id', brandId);
  }

  Future<void> applySubCategoryMedia(
    String subCategoryId, {
    required ProcessedShopImage? uploaded,
    bool clear = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    if (clear) {
      await c.from('sub_categories').update({
        'image_storage_path': null,
        'image_thumb_path': null,
        'image_webp_path': null,
        'image_alt_text': null,
        'image_url': null,
        'og_image': null,
        'image_editor_source_url': null,
        'image_editor_source_storage_path': null,
        'image_source_width': null,
        'image_source_height': null,
        'image_placements': {},
      }).eq('id', subCategoryId);
      return;
    }
    if (uploaded == null) return;
    final src = uploaded.editorSourceBytes;
    await c.from('sub_categories').update({
      'image_storage_path': uploaded.storagePath,
      'image_thumb_path': uploaded.thumbPath,
      'image_webp_path': uploaded.webpPath,
      'image_alt_text': uploaded.altText,
      'image_url': uploaded.publicUrl,
      'og_image': uploaded.publicUrl,
      'image_source_url': uploaded.sourceUrl,
      'image_source_provider': uploaded.sourceProvider,
      'image_attribution': uploaded.attribution,
      'image_editor_source_url': uploaded.editorSourcePublicUrl,
      'image_editor_source_storage_path': uploaded.editorSourceStoragePath,
      'image_source_width': src != null ? _decodeWidth(src) : null,
      'image_source_height': src != null ? _decodeHeight(src) : null,
      'image_placements': uploaded.editorPlacements?.toJson() ?? {},
    }).eq('id', subCategoryId);
  }

  Future<void> applyProductMainMedia(
    String productId, {
    required ProcessedShopImage? uploaded,
    bool clear = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    if (clear) {
      await c.from('products').update({
        'main_image_storage_path': null,
        'main_image_thumb_path': null,
        'main_image_alt_text': null,
        'og_image': null,
        'og_image_override': null,
        'main_image_source_url': null,
        'main_image_source_provider': null,
        'main_image_attribution': null,
        'main_image_editor_source_url': null,
        'main_image_editor_source_storage_path': null,
        'main_image_source_width': null,
        'main_image_source_height': null,
        'main_image_placements': {},
      }).eq('id', productId);
      return;
    }
    if (uploaded == null) return;
    final src = uploaded.editorSourceBytes;
    await c.from('products').update({
      'main_image_storage_path': uploaded.storagePath,
      'main_image_thumb_path': uploaded.thumbPath,
      'main_image_alt_text': uploaded.altText,
      'og_image': uploaded.publicUrl,
      'og_image_override': null,
      'main_image_source_url': uploaded.sourceUrl,
      'main_image_source_provider': uploaded.sourceProvider,
      'main_image_attribution': uploaded.attribution,
      'main_image_editor_source_url': uploaded.editorSourcePublicUrl,
      'main_image_editor_source_storage_path': uploaded.editorSourceStoragePath,
      'main_image_source_width': src != null ? _decodeWidth(src) : null,
      'main_image_source_height': src != null ? _decodeHeight(src) : null,
      'main_image_placements': uploaded.editorPlacements?.toJson() ??
          const EntityImagePlacements({}).toJson(),
    }).eq('id', productId);
  }

  Future<void> syncProductDocumentMetadata(
    String productId,
    List<ShopProductMediaItem> items,
  ) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final row = await c.from('products').select('metadata').eq('id', productId).maybeSingle();
    if (row == null) return;
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    List<String> urlsFor(ShopProductMediaKind kind) {
      final list = items
          .where((i) => i.kind == kind && !i.markedForDelete && i.publicUrl.isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list.map((i) => i.publicUrl).toList();
    }
    meta['datasheet_urls'] = urlsFor(ShopProductMediaKind.datasheet);
    meta['brochure_urls'] = urlsFor(ShopProductMediaKind.brochure);
    meta['gallery_urls'] = urlsFor(ShopProductMediaKind.gallery);
    await c.from('products').update({'metadata': meta}).eq('id', productId);
  }
}

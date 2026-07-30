import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/editing/dg_google_image_pick_sheet.dart';
import '../../../../core/editing/dg_image_search_context.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/entity_image_placements.dart';
import '../../domain/shop_media_models.dart';
import 'entity_image_editor_screen.dart';
import 'shop_device_image_pick.dart';

/// Upload or Google Images → popup placement editor (with contextual previews) → WebP.
abstract final class ShopImageSourceFlow {
  static Future<ProcessedShopImage?> pickProcessedImage(
    BuildContext context, {
    required ShopImagePreset preset,
    required String altTextHint,
    DgImageSearchContext? searchContext,
  }) async {
    final choice = await showModalBottomSheet<_ImagePickChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Upload image'),
              subtitle: const Text('Gallery or camera → adjust & preview'),
              onTap: () => Navigator.pop(ctx, _ImagePickChoice.upload),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Search on Google'),
              subtitle: const Text('Google Images → pick file → editor'),
              onTap: () => Navigator.pop(ctx, _ImagePickChoice.google),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return null;

    if (choice == _ImagePickChoice.upload) {
      final source = await ShopDeviceImagePick.askSource(context);
      if (source == null || !context.mounted) return null;
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 100);
      if (file == null || !context.mounted) return null;
      final bytes = await file.readAsBytes();
      return _openEditor(context, bytes: bytes, preset: preset, altTextHint: altTextHint);
    }

    final ctx = searchContext ?? DgImageSearchContext(productName: altTextHint);
    if (!context.mounted) return null;
    final picked = await DgGoogleImagePickSheet.show(context, searchContext: ctx);
    if (picked == null || !context.mounted) return null;

    return _openEditor(
      context,
      bytes: picked.bytes,
      preset: preset,
      altTextHint: altTextHint,
      searchQuery: picked.searchQuery,
      searchUri: picked.searchUri,
    );
  }

  static Future<ProcessedShopImage?> adjustExisting(
    BuildContext context, {
    required Uint8List sourceBytes,
    required ShopImagePreset preset,
    required String altTextHint,
    BrandLogoLayout initialLayout = const BrandLogoLayout(),
    EntityImagePlacements? initialPlacements,
    String? sourceProvider,
    String? attribution,
  }) {
    return EntityImageEditorScreen.show(
      context,
      imageBytes: sourceBytes,
      preset: preset,
      entityName: altTextHint,
      initialLayout: initialLayout,
      initialPlacements: initialPlacements,
      sourceProvider: sourceProvider,
      attribution: attribution,
    );
  }

  static Future<ProcessedShopImage?> _openEditor(
    BuildContext context, {
    required Uint8List bytes,
    required ShopImagePreset preset,
    required String altTextHint,
    String? searchQuery,
    Uri? searchUri,
  }) async {
    final edited = await EntityImageEditorScreen.show(
      context,
      imageBytes: bytes,
      preset: preset,
      entityName: altTextHint,
      sourceProvider: searchUri != null ? 'google_images' : null,
      attribution: searchUri != null ? 'Image via Google Images: $searchQuery' : null,
    );
    if (edited == null) return null;
    if (searchUri == null) return edited;
    return edited.copyWith(
      sourceUrl: searchUri.toString(),
      sourceProvider: 'google_images',
      attribution: 'Image via Google Images: $searchQuery',
    );
  }
}

enum _ImagePickChoice { upload, google }

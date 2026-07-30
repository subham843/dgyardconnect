import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/editing/dg_google_image_pick_sheet.dart';
import '../../../../core/editing/dg_image_search_context.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/entity_image_placements.dart';
import '../../domain/shop_media_models.dart';
import 'entity_image_ai_service.dart';
import 'entity_image_editor_screen.dart';
import 'shop_device_image_pick.dart';

/// Category / sub-category image: upload, Google, Gemini AI → popup editor → WebP.
abstract final class EntityImageSourceFlow {
  static Future<ProcessedShopImage?> pickProcessedImage(
    BuildContext context, {
    required ShopImagePreset preset,
    required String entityName,
    DgImageSearchContext? searchContext,
  }) async {
    final choice = await showModalBottomSheet<_EntityImagePickChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Upload image'),
              subtitle: const Text('Gallery or camera → image editor'),
              onTap: () => Navigator.pop(ctx, _EntityImagePickChoice.upload),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Search on Google'),
              subtitle: const Text('Google Images → pick file → editor'),
              onTap: () => Navigator.pop(ctx, _EntityImagePickChoice.google),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Generate with Gemini AI'),
              subtitle: Text('Create banner from "$entityName"'),
              onTap: () => Navigator.pop(ctx, _EntityImagePickChoice.gemini),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return null;

    Uint8List? bytes;
    String? provider;
    String? attribution;

    switch (choice) {
      case _EntityImagePickChoice.upload:
        final source = await ShopDeviceImagePick.askSource(context);
        if (source == null || !context.mounted) return null;
        final file = await ImagePicker().pickImage(source: source, imageQuality: 100);
        if (file == null || !context.mounted) return null;
        bytes = await file.readAsBytes();
      case _EntityImagePickChoice.google:
        final ctx = searchContext ?? DgImageSearchContext(categoryName: entityName);
        if (!context.mounted) return null;
        final picked = await DgGoogleImagePickSheet.show(context, searchContext: ctx);
        if (picked == null || !context.mounted) return null;
        bytes = picked.bytes;
        provider = 'google_images';
        attribution = 'Image via Google Images: ${picked.searchQuery}';
      case _EntityImagePickChoice.gemini:
        if (!context.mounted) return null;
        bytes = await _generateGeminiImage(context, entityName);
        if (bytes == null) return null;
        provider = 'gemini';
        attribution = 'AI-generated category banner (Gemini)';
    }

    if (bytes.isEmpty || !context.mounted) return null;
    return _openEditor(
      context,
      bytes: bytes,
      preset: preset,
      entityName: entityName,
      sourceProvider: provider,
      attribution: attribution,
    );
  }

  static Future<ProcessedShopImage?> adjustExisting(
    BuildContext context, {
    required ShopImagePreset preset,
    required String entityName,
    required Uint8List sourceBytes,
    BrandLogoLayout initialLayout = const BrandLogoLayout(),
    EntityImagePlacements? initialPlacements,
  }) {
    return _openEditor(
      context,
      bytes: sourceBytes,
      preset: preset,
      entityName: entityName,
      initialLayout: initialLayout,
      initialPlacements: initialPlacements,
    );
  }

  static Future<Uint8List?> _generateGeminiImage(BuildContext context, String entityName) async {
    try {
      return await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => _GeminiLoadingDialog(categoryName: entityName),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return null;
    }
  }

  static Future<ProcessedShopImage?> _openEditor(
    BuildContext context, {
    required Uint8List bytes,
    required ShopImagePreset preset,
    required String entityName,
    BrandLogoLayout initialLayout = const BrandLogoLayout(),
    EntityImagePlacements? initialPlacements,
    String? sourceProvider,
    String? attribution,
  }) {
    return EntityImageEditorScreen.show(
      context,
      imageBytes: bytes,
      preset: preset,
      entityName: entityName,
      initialLayout: initialLayout,
      initialPlacements: initialPlacements,
      sourceProvider: sourceProvider,
      attribution: attribution,
    );
  }
}

class _GeminiLoadingDialog extends StatefulWidget {
  const _GeminiLoadingDialog({required this.categoryName});

  final String categoryName;

  @override
  State<_GeminiLoadingDialog> createState() => _GeminiLoadingDialogState();
}

class _GeminiLoadingDialogState extends State<_GeminiLoadingDialog> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final bytes = await EntityImageAiService.generateCategoryBanner(categoryName: widget.categoryName);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(bytes);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Gemini is creating your category image…')),
        ],
      ),
    );
  }
}

enum _EntityImagePickChoice { upload, google, gemini }

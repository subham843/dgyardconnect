import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/shop_media_processor.dart';
import '../../domain/brand_logo_layout.dart';
import '../../domain/shop_media_models.dart';
import 'brand_logo_editor_screen.dart';

/// Pick brand logo (PNG/SVG/WebP/JPG) → position editor → result.
abstract final class BrandLogoSourceFlow {
  static const uploadGuidance = '''
Recommended: transparent PNG or SVG
Minimum width: 500px
Preferred: 2000px+ width
Keep original aspect ratio — logos are never cropped to square.''';

  static Future<BrandLogoEditorResult?> pickAndEdit(
    BuildContext context, {
    required String brandName,
    BrandLogoLayout initialLayout = const BrandLogoLayout(),
    String? existingLogoUrl,
    String? existingMimeType,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'svg', 'webp', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final mime = ShopMediaProcessor.mimeFromFileName(file.name);
    return BrandLogoEditorScreen.show(
      context,
      imageBytes: bytes,
      mimeType: mime,
      brandName: brandName,
      initialLayout: initialLayout,
      existingLogoUrl: existingLogoUrl,
      existingMimeType: existingMimeType,
    );
  }

  static Future<BrandLogoEditorResult?> editExisting(
    BuildContext context, {
    required String brandName,
    required String logoUrl,
    String? mimeType,
    BrandLogoLayout initialLayout = const BrandLogoLayout(),
  }) {
    return BrandLogoEditorScreen.show(
      context,
      brandName: brandName,
      initialLayout: initialLayout,
      existingLogoUrl: logoUrl,
      existingMimeType: mimeType,
    );
  }
}

class BrandLogoEditorResult {
  const BrandLogoEditorResult({
    this.processed,
    required this.layout,
    this.clearLogo = false,
  });

  final ProcessedShopImage? processed;
  final BrandLogoLayout layout;
  final bool clearLogo;
}

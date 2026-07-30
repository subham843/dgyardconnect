import '../../domain/shop_media_models.dart';

/// Validation for shop media uploads (admin forms).
abstract final class ShopMediaValidation {
  static const maxImageBytes = 12 * 1024 * 1024;
  static const maxPdfBytes = 25 * 1024 * 1024;

  static String? imageBytes(int? length) {
    if (length == null || length == 0) return 'Image file is empty';
    if (length > maxImageBytes) return 'Image must be under 12 MB';
    return null;
  }

  static String? pdfBytes(int? length) {
    if (length == null || length == 0) return 'PDF file is empty';
    if (length > maxPdfBytes) return 'PDF must be under 25 MB';
    return null;
  }

  static String? productGalleryCount(List<ShopProductMediaItem> items) {
    final n = items
        .where((i) => i.kind == ShopProductMediaKind.gallery && !i.markedForDelete)
        .length;
    if (n > 24) return 'Gallery supports at most 24 images';
    return null;
  }
}

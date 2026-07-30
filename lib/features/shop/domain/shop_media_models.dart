import 'dart:typed_data';

import 'brand_logo_layout.dart';
import 'entity_image_placements.dart';

/// Target dimensions for shop image presets.
enum ShopImagePreset {
  category(1200, 630),
  subCategory(1200, 630),
  productMain(1000, 1000),
  productGallery(1000, 1000),
  brandLogo(400, 200);

  const ShopImagePreset(this.width, this.height);

  final int width;
  final int height;

  double get aspectRatio => width / height;

  String get label => switch (this) {
        ShopImagePreset.category => 'Category (1200×630)',
        ShopImagePreset.subCategory => 'Sub-category (1200×630)',
        ShopImagePreset.productMain => 'Product main (1000×1000)',
        ShopImagePreset.productGallery => 'Gallery (1000×1000)',
        ShopImagePreset.brandLogo => 'Brand logo canvas (400×200 display)',
      };
}

enum ShopProductMediaKind { main, gallery, datasheet, brochure }

/// Result after user confirms the image editor (held in memory until entity save).
class ProcessedShopImage {
  const ProcessedShopImage({
    required this.bytes,
    required this.thumbBytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.altText,
    this.storagePath,
    this.thumbPath,
    this.webpPath,
    this.publicUrl,
    this.sourceUrl,
    this.sourceProvider,
    this.attribution,
    this.editorSourceBytes,
    this.editorLayout,
    this.editorPlacements,
    this.editorSourceStoragePath,
    this.editorSourcePublicUrl,
  });

  final Uint8List bytes;
  final Uint8List thumbBytes;
  final String mimeType;
  final int width;
  final int height;
  final String altText;
  final String? storagePath;
  final String? thumbPath;
  final String? webpPath;
  final String? publicUrl;
  final String? sourceUrl;
  final String? sourceProvider;
  final String? attribution;

  /// Original bytes + layout for re-opening zoom/position editor (not stored in DB).
  final Uint8List? editorSourceBytes;
  final BrandLogoLayout? editorLayout;
  final EntityImagePlacements? editorPlacements;
  final String? editorSourceStoragePath;
  final String? editorSourcePublicUrl;

  ProcessedShopImage copyWith({
    Uint8List? bytes,
    Uint8List? thumbBytes,
    String? mimeType,
    int? width,
    int? height,
    String? altText,
    String? storagePath,
    String? thumbPath,
    String? webpPath,
    String? publicUrl,
    String? sourceUrl,
    String? sourceProvider,
    String? attribution,
    Uint8List? editorSourceBytes,
    BrandLogoLayout? editorLayout,
    EntityImagePlacements? editorPlacements,
    String? editorSourceStoragePath,
    String? editorSourcePublicUrl,
  }) {
    return ProcessedShopImage(
      bytes: bytes ?? this.bytes,
      thumbBytes: thumbBytes ?? this.thumbBytes,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      altText: altText ?? this.altText,
      storagePath: storagePath ?? this.storagePath,
      thumbPath: thumbPath ?? this.thumbPath,
      webpPath: webpPath ?? this.webpPath,
      publicUrl: publicUrl ?? this.publicUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceProvider: sourceProvider ?? this.sourceProvider,
      attribution: attribution ?? this.attribution,
      editorSourceBytes: editorSourceBytes ?? this.editorSourceBytes,
      editorLayout: editorLayout ?? this.editorLayout,
      editorPlacements: editorPlacements ?? this.editorPlacements,
      editorSourceStoragePath: editorSourceStoragePath ?? this.editorSourceStoragePath,
      editorSourcePublicUrl: editorSourcePublicUrl ?? this.editorSourcePublicUrl,
    );
  }
}

/// Local pending image (not uploaded until save).
class PendingShopImage {
  const PendingShopImage({
    required this.processed,
    required this.preset,
  });

  final ProcessedShopImage processed;
  final ShopImagePreset preset;
}

/// Product media row (DB or pending file).
class ShopProductMediaItem {
  const ShopProductMediaItem({
    this.id,
    required this.kind,
    required this.publicUrl,
    this.storagePath,
    this.thumbPath,
    this.webpPath,
    this.altText,
    this.fileName,
    this.mimeType,
    this.sortOrder = 0,
    this.isPrimary = false,
    this.pendingBytes,
    this.pendingThumbBytes,
    this.markedForDelete = false,
    this.sourceUrl,
    this.sourceProvider,
    this.attribution,
    this.editorSourceBytes,
    this.editorLayout,
    this.editorPlacements,
  });

  final String? id;
  final ShopProductMediaKind kind;
  final String publicUrl;
  final String? storagePath;
  final String? thumbPath;
  final String? webpPath;
  final String? altText;
  final String? fileName;
  final String? mimeType;
  final int sortOrder;
  final bool isPrimary;
  final Uint8List? pendingBytes;
  final Uint8List? pendingThumbBytes;
  final bool markedForDelete;
  final String? sourceUrl;
  final String? sourceProvider;
  final String? attribution;
  final Uint8List? editorSourceBytes;
  final BrandLogoLayout? editorLayout;
  final EntityImagePlacements? editorPlacements;

  bool get isPending => pendingBytes != null;

  ShopProductMediaItem copyWith({
    String? id,
    ShopProductMediaKind? kind,
    String? publicUrl,
    String? storagePath,
    int? sortOrder,
    bool? isPrimary,
    bool? markedForDelete,
    Uint8List? pendingBytes,
    Uint8List? pendingThumbBytes,
    String? altText,
    String? mimeType,
    Uint8List? editorSourceBytes,
    BrandLogoLayout? editorLayout,
    EntityImagePlacements? editorPlacements,
  }) {
    return ShopProductMediaItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      publicUrl: publicUrl ?? this.publicUrl,
      storagePath: storagePath ?? this.storagePath,
      thumbPath: thumbPath,
      webpPath: webpPath,
      altText: altText ?? this.altText,
      fileName: fileName,
      mimeType: mimeType ?? this.mimeType,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      pendingBytes: pendingBytes ?? this.pendingBytes,
      pendingThumbBytes: pendingThumbBytes ?? this.pendingThumbBytes,
      markedForDelete: markedForDelete ?? this.markedForDelete,
      sourceUrl: sourceUrl,
      sourceProvider: sourceProvider,
      attribution: attribution,
      editorSourceBytes: editorSourceBytes ?? this.editorSourceBytes,
      editorLayout: editorLayout ?? this.editorLayout,
      editorPlacements: editorPlacements ?? this.editorPlacements,
    );
  }

  factory ShopProductMediaItem.fromRow(Map<String, dynamic> row) {
    final type = row['media_type'] as String? ?? 'gallery';
    return ShopProductMediaItem(
      id: row['id'] as String,
      kind: ShopProductMediaKind.values.firstWhere(
        (e) => e.name == type,
        orElse: () => ShopProductMediaKind.gallery,
      ),
      publicUrl: row['public_url'] as String? ?? '',
      storagePath: row['storage_path'] as String?,
      thumbPath: row['thumb_path'] as String?,
      webpPath: row['webp_path'] as String?,
      altText: row['alt_text'] as String?,
      fileName: row['file_name'] as String?,
      mimeType: row['mime_type'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isPrimary: row['is_primary'] as bool? ?? false,
      sourceUrl: row['source_url'] as String?,
      sourceProvider: row['source_provider'] as String?,
      attribution: row['attribution'] as String?,
    );
  }
}

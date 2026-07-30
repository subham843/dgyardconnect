import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../domain/brand_logo_layout.dart';
import '../domain/shop_media_models.dart';

/// Resize, compress, WebP, thumbnail, watermark, background replace.
abstract final class ShopMediaProcessor {
  static const int thumbSize = 240;
  static const int defaultUploadQuality = 78;
  static const int defaultThumbQuality = 72;

  static String suggestAltText({
    required String entityName,
    String? contextLabel,
    ShopImagePreset? preset,
  }) {
    final base = entityName.trim();
    if (base.isEmpty) return 'Product image';
    final suffix = switch (preset) {
      ShopImagePreset.category => 'category',
      ShopImagePreset.subCategory => 'sub-category',
      ShopImagePreset.productMain => 'product',
      ShopImagePreset.productGallery => 'gallery',
      ShopImagePreset.brandLogo => 'brand logo',
      null => contextLabel ?? 'image',
    };
    return '$base — $suffix';
  }

  static Future<ProcessedShopImage> process({
    required Uint8List input,
    required ShopImagePreset preset,
    required String altText,
    int rotationQuarterTurns = 0,
    int quality = defaultUploadQuality,
    bool outputWebP = true,
    String? watermarkText,
    Color? backgroundColor,
    bool removeLightBackgroundFirst = false,
    int? customWidth,
    int? customHeight,
  }) async {
    final decoded0 = img.decodeImage(input);
    if (decoded0 == null) {
      throw StateError('Could not decode image');
    }
    img.Image decoded = decoded0;

    for (var i = 0; i < rotationQuarterTurns % 4; i++) {
      decoded = img.copyRotate(decoded, angle: 90);
    }

    if (removeLightBackgroundFirst) {
      decoded = removeLightBackground(decoded);
      if (backgroundColor != null) {
        decoded = compositeOnBackground(decoded, backgroundColor);
      }
    } else if (backgroundColor != null) {
      decoded = compositeOnBackground(decoded, backgroundColor);
    }

    final targetW = customWidth ?? preset.width;
    final targetH = customHeight ?? preset.height;
    final resized = img.copyResize(
      decoded,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.average,
    );

    if (watermarkText != null && watermarkText.trim().isNotEmpty) {
      try {
        img.drawString(
          resized,
          watermarkText.trim(),
          font: img.arial14,
          x: 12,
          y: resized.height - 28,
          color: img.ColorRgba8(255, 255, 255, 220),
        );
      } catch (_) {}
    }

    final jpgMain = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    final encoded = outputWebP ? await compressWebP(jpgMain, quality: quality) : jpgMain;

    final thumb = img.copyResize(resized, width: thumbSize, height: thumbSize);
    final thumbJpg = Uint8List.fromList(img.encodeJpg(thumb, quality: 85));
    final thumbEncoded = await compressWebP(thumbJpg, quality: defaultThumbQuality);

    return ProcessedShopImage(
      bytes: encoded,
      thumbBytes: thumbEncoded,
      mimeType: outputWebP ? 'image/webp' : 'image/jpeg',
      width: resized.width,
      height: resized.height,
      altText: altText,
    );
  }

  /// Makes near-white / light pixels transparent (simple product-photo BG remove).
  static img.Image removeLightBackground(img.Image source, {int threshold = 235}) {
    final out = img.Image(width: source.width, height: source.height, numChannels: 4);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final p = source.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
        final spread = (r - g).abs() + (g - b).abs() + (r - b).abs();
        final isBg = lum >= threshold && spread < 40;
        final alpha = isBg ? 0 : p.a.toInt();
        out.setPixelRgba(x, y, r, g, b, alpha);
      }
    }
    return out;
  }

  static img.Image compositeOnBackground(img.Image source, Color color) {
    final canvas = img.Image(width: source.width, height: source.height);
    img.fill(
      canvas,
      color: img.ColorRgba8(color.red, color.green, color.blue, 255),
    );
    img.compositeImage(canvas, source, dstX: 0, dstY: 0, blend: img.BlendMode.alpha);
    return canvas;
  }

  static String formatByteSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Extra pass via flutter_image_compress for smaller WebP on mobile/web.
  static const int brandLogoMaxWidth = 2000;
  static const int brandLogoMinRecommendedWidth = 500;

  /// Preserves aspect ratio — never forces square. SVG returned as-is.
  /// Category / sub-category banner — cover fit with zoom + pan, output preset size.
  static Future<ProcessedShopImage> processEntityImage({
    required Uint8List input,
    required ShopImagePreset preset,
    required String altText,
    BrandLogoLayout layout = const BrandLogoLayout(),
    int quality = defaultUploadQuality,
  }) async {
    final decoded = img.decodeImage(input);
    if (decoded == null) throw StateError('Could not decode image');

    final composed = _composeCover(
      source: decoded,
      canvasW: preset.width,
      canvasH: preset.height,
      layout: layout,
      background: layout.backgroundColor,
    );

    final jpgMain = Uint8List.fromList(img.encodeJpg(composed, quality: quality));
    final encoded = await compressWebP(jpgMain, quality: quality);
    final thumb = img.copyResize(composed, width: thumbSize);
    final thumbEncoded = await compressWebP(
      Uint8List.fromList(img.encodeJpg(thumb, quality: 85)),
      quality: defaultThumbQuality,
    );

    return ProcessedShopImage(
      bytes: encoded,
      thumbBytes: thumbEncoded,
      mimeType: 'image/webp',
      width: composed.width,
      height: composed.height,
      altText: altText,
      editorSourceBytes: input,
      editorLayout: layout,
    );
  }

  static img.Image _composeCover({
    required img.Image source,
    required int canvasW,
    required int canvasH,
    required BrandLogoLayout layout,
    Color? background,
  }) {
    final canvas = img.Image(width: canvasW, height: canvasH);
    final bg = background ?? const Color(0xFF0F172A);
    img.fill(canvas, color: img.ColorRgba8(bg.red, bg.green, bg.blue, 255));

    final frame = EntityImageFrameMath.frame(
      sourceW: source.width,
      sourceH: source.height,
      canvasW: canvasW.toDouble(),
      canvasH: canvasH.toDouble(),
      layout: layout,
    );
    final dw = frame.imageWidth.round().clamp(1, canvasW * 4);
    final dh = frame.imageHeight.round().clamp(1, canvasH * 4);
    final resized = img.copyResize(source, width: dw, height: dh);
    img.compositeImage(canvas, resized, dstX: frame.left.round(), dstY: frame.top.round());
    return canvas;
  }

  static Future<ProcessedShopImage> processBrandLogo({
    required Uint8List input,
    required String altText,
    required String mimeType,
    int quality = defaultUploadQuality,
  }) async {
    if (mimeType == 'image/svg+xml') {
      return ProcessedShopImage(
        bytes: input,
        thumbBytes: input,
        mimeType: mimeType,
        width: 0,
        height: 0,
        altText: altText,
      );
    }

    final decoded = img.decodeImage(input);
    if (decoded == null) {
      throw StateError('Could not decode image');
    }

    var working = decoded;
    if (working.width > brandLogoMaxWidth) {
      working = img.copyResize(working, width: brandLogoMaxWidth);
    }

    final encoded = mimeType == 'image/png'
        ? Uint8List.fromList(img.encodePng(working))
        : await compressWebP(
            Uint8List.fromList(img.encodeJpg(working, quality: quality)),
            quality: quality,
          );

    final thumbSide = working.width >= working.height ? thumbSize : null;
    final thumb = thumbSide != null
        ? img.copyResize(working, width: thumbSide)
        : img.copyResize(working, height: thumbSize);
    final thumbEncoded = await compressWebP(
      Uint8List.fromList(img.encodeJpg(thumb, quality: 85)),
      quality: defaultThumbQuality,
    );

    return ProcessedShopImage(
      bytes: encoded,
      thumbBytes: thumbEncoded,
      mimeType: mimeType == 'image/png' ? 'image/png' : 'image/webp',
      width: working.width,
      height: working.height,
      altText: altText,
    );
  }

  static String mimeFromFileName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/png';
  }

  static String extensionForMime(String mime) => switch (mime) {
        'image/svg+xml' => 'svg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/jpeg' => 'jpg',
        _ => 'webp',
      };

  static Future<Uint8List> compressWebP(Uint8List input, {int quality = 85}) async {
    final out = await FlutterImageCompress.compressWithList(
      input,
      quality: quality,
      format: CompressFormat.webp,
    );
    return out;
  }
}

/// Shared cover-fit math for category banner editor preview and final WebP output.
/// [BrandLogoLayout.offsetX/Y] are stored in output canvas pixels (e.g. 1200×630).
class EntityImageFrame {
  const EntityImageFrame({
    required this.imageWidth,
    required this.imageHeight,
    required this.left,
    required this.top,
  });

  final double imageWidth;
  final double imageHeight;
  final double left;
  final double top;
}

abstract final class EntityImageFrameMath {
  static double coverBaseScale(int sourceW, int sourceH, int canvasW, int canvasH) {
    if (sourceW <= 0 || sourceH <= 0) return 1;
    return (canvasW / sourceW) > (canvasH / sourceH) ? canvasW / sourceW : canvasH / sourceH;
  }

  static double containBaseScale(int sourceW, int sourceH, int canvasW, int canvasH) {
    if (sourceW <= 0 || sourceH <= 0) return 1;
    return (canvasW / sourceW) < (canvasH / sourceH) ? canvasW / sourceW : canvasH / sourceH;
  }

  /// [layout.scale] = 1 → cover fill; lower values zoom out (contain at contain/cover ratio).
  static EntityImageFrame frame({
    required int sourceW,
    required int sourceH,
    required double canvasW,
    required double canvasH,
    required BrandLogoLayout layout,
  }) {
    final base = coverBaseScale(sourceW, sourceH, canvasW.round(), canvasH.round());
    final scale = base * layout.scale;
    final dw = sourceW * scale;
    final dh = sourceH * scale;
    return EntityImageFrame(
      imageWidth: dw,
      imageHeight: dh,
      left: (canvasW - dw) / 2 + layout.offsetX,
      top: (canvasH - dh) / 2 + layout.offsetY,
    );
  }

  /// Centers the full image inside the frame (no top/bottom crop).
  static BrandLogoLayout autoFitLayout({
    required int sourceW,
    required int sourceH,
    required int canvasW,
    required int canvasH,
  }) {
    final cover = coverBaseScale(sourceW, sourceH, canvasW, canvasH);
    final contain = containBaseScale(sourceW, sourceH, canvasW, canvasH);
    if (cover <= 0) return const BrandLogoLayout();
    return BrandLogoLayout(scale: (contain / cover).clamp(0.35, 4.0));
  }

  static BrandLogoLayout layoutForPreview({
    required BrandLogoLayout layout,
    required double previewW,
    required double previewH,
    required int outputW,
    required int outputH,
  }) {
    return BrandLogoLayout(
      scale: layout.scale,
      offsetX: layout.offsetX * (previewW / outputW),
      offsetY: layout.offsetY * (previewH / outputH),
      backgroundColorHex: layout.backgroundColorHex,
    );
  }

  static bool isDefaultLayout(BrandLogoLayout layout) {
    return layout.scale == 1.0 &&
        layout.offsetX == 0 &&
        layout.offsetY == 0 &&
        layout.backgroundColorHex == null;
  }
}

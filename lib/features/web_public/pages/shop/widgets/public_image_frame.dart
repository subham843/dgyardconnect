import '../../../data/models/public_image_placements.dart';

class PublicImageFrame {
  const PublicImageFrame({
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

abstract final class PublicImageFrameMath {
  static double coverBaseScale(int sourceW, int sourceH, int canvasW, int canvasH) {
    if (sourceW <= 0 || sourceH <= 0) return 1;
    return (canvasW / sourceW) > (canvasH / sourceH) ? canvasW / sourceW : canvasH / sourceH;
  }

  static PublicImageFrame frame({
    required int sourceW,
    required int sourceH,
    required double canvasW,
    required double canvasH,
    required PublicImageLayout layout,
  }) {
    final base = coverBaseScale(sourceW, sourceH, canvasW.round(), canvasH.round());
    final scale = base * layout.scale;
    final dw = sourceW * scale;
    final dh = sourceH * scale;
    return PublicImageFrame(
      imageWidth: dw,
      imageHeight: dh,
      left: (canvasW - dw) / 2 + layout.offsetX,
      top: (canvasH - dh) / 2 + layout.offsetY,
    );
  }

  static PublicImageLayout layoutForPreview({
    required PublicImageLayout layout,
    required double previewW,
    required double previewH,
    required int outputW,
    required int outputH,
  }) {
    return PublicImageLayout(
      scale: layout.scale,
      offsetX: layout.offsetX * (previewW / outputW),
      offsetY: layout.offsetY * (previewH / outputH),
      backgroundColorHex: layout.backgroundColorHex,
    );
  }
}
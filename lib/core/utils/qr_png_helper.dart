import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

/// Generates a QR code PNG image for the given [url]. Returns PNG bytes suitable for PDF.
Uint8List qrCodeToPngBytes(String url, {int modulePixelSize = 4}) {
  final qrCode = QrCode.fromData(
    data: url,
    errorCorrectLevel: QrErrorCorrectLevel.L,
  );
  final qrImage = QrImage(qrCode);
  final n = qrImage.moduleCount;
  final size = n * modulePixelSize;
  final image = img.Image(width: size, height: size);
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: size - 1,
    y2: size - 1,
    color: img.ColorRgb8(255, 255, 255),
  );
  for (var row = 0; row < n; row++) {
    for (var col = 0; col < n; col++) {
      if (qrImage.isDark(row, col)) {
        img.fillRect(
          image,
          x1: col * modulePixelSize,
          y1: row * modulePixelSize,
          x2: (col + 1) * modulePixelSize - 1,
          y2: (row + 1) * modulePixelSize - 1,
          color: img.ColorRgb8(0, 0, 0),
        );
      }
    }
  }
  return img.encodePng(image);
}

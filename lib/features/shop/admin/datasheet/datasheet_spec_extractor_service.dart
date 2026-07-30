import 'dart:convert';

import '../../../../core/editing/platform_edge_client.dart';
import 'datasheet_spec_models.dart';

class DatasheetSpecExtractorService {
  Future<DatasheetExtractedSpecs?> extractFromPdf({
    required List<int> pdfBytes,
    String? fileName,
    String? productName,
    String? brandName,
    String? categoryName,
  }) async {
    if (pdfBytes.isEmpty) return null;
    final json = await PlatformEdgeClient.post('platform-datasheet-extract', {
      'pdfBase64': base64Encode(pdfBytes),
      'fileName': ?fileName,
      'productName': ?productName,
      'brandName': ?brandName,
      'categoryName': ?categoryName,
    });
    if (json == null) return null;
    final err = json['error'];
    if (err != null) {
      final code = json['code'] as String?;
      if (code == 'quota_exceeded') {
        throw StateError('AI quota exceeded — add GROQ_API_KEY fallback or retry later.');
      }
      throw StateError(err.toString());
    }
    final data = json['data'];
    if (data is! Map) return null;
    return DatasheetExtractedSpecs.fromJson(Map<String, dynamic>.from(data));
  }
}

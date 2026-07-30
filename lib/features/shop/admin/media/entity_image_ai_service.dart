import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/editing/platform_edge_client.dart';

/// Gemini AI category banner generation via Supabase Edge Function.
abstract final class EntityImageAiService {
  static Future<Uint8List?> generateCategoryBanner({
    required String categoryName,
    String? description,
  }) async {
    final json = await PlatformEdgeClient.post('platform-image-generate', {
      'categoryName': categoryName.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      'preset': 'category',
    });
    if (json == null) throw StateError('AI image service unavailable — check Supabase login');
    final err = json['error'];
    if (err != null) {
      final msg = err.toString();
      if (msg.contains('404') || msg.contains('not found')) {
        throw StateError(
          'Gemini image model not available on your API key. '
          'Set GEMINI_IMAGE_MODEL=gemini-2.5-flash-image in Supabase secrets, or upload an image manually.',
        );
      }
      throw StateError(msg.length > 200 ? '${msg.substring(0, 200)}…' : msg);
    }

    final b64 = json['imageBase64'] as String?;
    if (b64 == null || b64.isEmpty) throw StateError('No image returned from AI');
    return base64Decode(b64);
  }
}

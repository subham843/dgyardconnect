import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pick image bytes from device (reliable on Flutter web after dialogs close).
abstract final class PickImageBytes {
  static Future<Uint8List?> fromDevice(BuildContext context) async {
    try {
      if (kIsWeb) {
        return _fromImagePicker();
      }
      return _fromFilePicker();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file chooser: $e')),
        );
      }
      return null;
    }
  }

  static Future<Uint8List?> _fromImagePicker() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  static Future<Uint8List?> _fromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;

    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }

    final stream = file.readStream;
    if (stream != null) {
      final chunks = <int>[];
      await for (final chunk in stream) {
        chunks.addAll(chunk);
      }
      if (chunks.isNotEmpty) return Uint8List.fromList(chunks);
    }

    return null;
  }
}

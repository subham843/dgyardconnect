import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> exportCsvFile(String filename, String content) async {
  await FilePicker.platform.saveFile(
    fileName: filename.endsWith('.csv') ? filename : '$filename.csv',
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
}

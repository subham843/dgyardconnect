// Stub for dart:io when building for web (dart:io not available).
// Only used in conditional import; real implementation uses dart:io on mobile/desktop.

class File {
  File(this.path);
  final String path;
  Future<void> writeAsBytes(List<int> bytes) async {}
}

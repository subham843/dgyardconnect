// ignore_for_file: avoid_print
/// Syncs app launcher icon from brand kit URL.
///
/// Usage (avoid shell escaping issues on Windows):
///   1. Paste your URL into scripts/app_icon_url.txt (one line, no quotes)
///   2. Run: dart run scripts/sync_app_icon.dart
///
/// Or with URL as argument (PowerShell, use single quotes):
///   dart run scripts/sync_app_icon.dart 'https://...'
///
/// Get the REAL URL from Admin > Brand Kit (App Icon 512) — not the example!
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

const _iconPath = 'assets/icons/app_icon.png';
const _urlFilePath = 'scripts/app_icon_url.txt';

Future<void> main(List<String> args) async {
  String? url = args.isNotEmpty ? args.first.trim() : null;
  if ((url == null || url.isEmpty) && File(_urlFilePath).existsSync()) {
    final lines = File(_urlFilePath).readAsStringSync().split('\n');
    url = lines
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('#'))
        .firstOrNull;
  }
  if (url != null &&
      url.isNotEmpty &&
      (url.startsWith('http://') || url.startsWith('https://'))) {
    if (url.contains('...') ||
        url.contains('your-project') ||
        url.contains('token=xxxxx')) {
      print(
        'Error: That is an example URL. Use the REAL URL from Admin > Brand Kit.',
      );
      print('Paste it into $_urlFilePath (one line) and run again.');
      exit(1);
    }
    print('Downloading app icon from brand kit...');
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      print('Download failed: HTTP ${resp.statusCode}');
      if (resp.statusCode == 404) {
        print('');
        print('404 = URL not found. Use the REAL URL from Admin > Brand Kit.');
        print('Tip: Paste URL into $_urlFilePath and run without arguments.');
      }
      exit(1);
    }
    final file = File(_iconPath);
    await file.parent.create(recursive: true);
    final bytes = resp.bodyBytes;
    final decoded = img.decodeImage(bytes);
    if (decoded != null && (decoded.width != 1024 || decoded.height != 1024)) {
      final resized = img.copyResize(decoded, width: 1024, height: 1024);
      await file.writeAsBytes(img.encodePng(resized));
      print('Resized to 1024x1024 and saved to $_iconPath');
    } else if (decoded != null) {
      await file.writeAsBytes(img.encodePng(decoded));
      print('Saved to $_iconPath');
    } else {
      await file.writeAsBytes(bytes);
      print('Saved to $_iconPath (could not decode, using raw bytes)');
    }
  }

  final iconFile = File(_iconPath);
  if (!iconFile.existsSync()) {
    print('');
    print('No app icon found. Either:');
    print(
      '  1. Paste URL into $_urlFilePath and run: dart run scripts/sync_app_icon.dart',
    );
    print('  2. Or add app_icon.png to assets/icons/ manually');
    print('');
    print(
      'Get the REAL URL from Admin > Brand Kit (App Icon 512) — not the example!',
    );
    exit(1);
  }

  print('Running flutter_launcher_icons...');
  final result = await Process.run(
    'dart',
    ['run', 'flutter_launcher_icons'],
    runInShell: true,
    workingDirectory: Directory.current.path,
  );

  if (result.exitCode != 0) {
    print('flutter_launcher_icons failed:');
    print(result.stderr);
    exit(1);
  }

  print('');
  print('Done! App icon updated.');
  print('Rebuild: flutter clean && flutter run');
}

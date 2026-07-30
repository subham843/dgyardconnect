import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'dg_image_search_context.dart';
import 'google_image_search_launcher.dart';
import 'pick_image_bytes.dart';

enum _GoogleImageDialogAction { cancel, pickFile }

/// Google Images in browser → user saves image → pick file → returns bytes.
class DgGoogleImagePickSheet extends StatefulWidget {
  const DgGoogleImagePickSheet({
    super.key,
    required this.searchContext,
  });

  final DgImageSearchContext searchContext;

  static Future<({Uint8List bytes, String searchQuery, Uri searchUri})?> show(
    BuildContext context, {
    required DgImageSearchContext searchContext,
  }) async {
    final query = GoogleImageSearchLauncher.queryFrom(searchContext);
    final searchUri = GoogleImageSearchLauncher.googleImagesUri(query);

    final action = await showDialog<_GoogleImageDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DgGoogleImagePickSheet(searchContext: searchContext),
    );

    if (action != _GoogleImageDialogAction.pickFile || !context.mounted) {
      return null;
    }

    // Pick after dialog closes — file chooser fails on web while AlertDialog is open.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!context.mounted) return null;

    final bytes = await PickImageBytes.fromDevice(context);
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No image selected. Choose a JPG, PNG, or WebP file from your Downloads folder.',
            ),
          ),
        );
      }
      return null;
    }

    return (bytes: bytes, searchQuery: query, searchUri: searchUri);
  }

  @override
  State<DgGoogleImagePickSheet> createState() => _DgGoogleImagePickSheetState();
}

class _DgGoogleImagePickSheetState extends State<DgGoogleImagePickSheet> {
  var _googleOpened = false;

  String get _query => GoogleImageSearchLauncher.queryFrom(widget.searchContext);

  Future<void> _openGoogle() async {
    final ok = await GoogleImageSearchLauncher.open(widget.searchContext);
    if (!mounted) return;
    setState(() => _googleOpened = true);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open browser. Allow pop-ups for this site.')),
      );
    }
  }

  void _requestPickFile() {
    Navigator.pop(context, _GoogleImageDialogAction.pickFile);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search image on Google'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search: "$_query"',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Tap Open Google Images (new window).\n'
              '2. Open an image → Save image to your PC.\n'
              '3. Return here and tap Use saved image — choose the file you saved.\n\n'
              'The editor opens after you select the file.',
              style: TextStyle(height: 1.4),
            ),
            if (_googleOpened) ...[
              const SizedBox(height: 12),
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Google is open. After saving the image, use the button below.'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openGoogle,
              icon: const Icon(Icons.open_in_browser),
              label: Text(_googleOpened ? 'Open Google again' : 'Open Google Images'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _requestPickFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Use saved image'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _GoogleImageDialogAction.cancel),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

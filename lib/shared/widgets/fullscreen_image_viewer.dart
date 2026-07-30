import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a fullscreen image viewer when the child is tapped.
/// Shows geo-tag overlay when latitude/longitude are provided.
class TappableImage extends StatelessWidget {
  const TappableImage({
    super.key,
    this.imageUrl = '',
    this.filePath,
    required this.child,
    this.latitude,
    this.longitude,
  });

  final String imageUrl;
  final String? filePath;
  final Widget child;
  final double? latitude;
  final double? longitude;

  /// Opens fullscreen image viewer. Pass [url] or [filePath] for image source.
  /// Pass [latitude] and [longitude] to show geo-tag.
  static void show(
    BuildContext context, {
    String? url,
    String? filePath,
    double? latitude,
    double? longitude,
  }) {
    assert(url != null || filePath != null, 'Provide url or filePath');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _FullscreenImageView(
          url: url,
          filePath: filePath,
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => show(
        context,
        url: imageUrl.isEmpty ? null : imageUrl,
        filePath: filePath,
        latitude: latitude,
        longitude: longitude,
      ),
      child: child,
    );
  }
}

class _FullscreenImageView extends StatelessWidget {
  const _FullscreenImageView({
    this.url,
    this.filePath,
    this.latitude,
    this.longitude,
  });

  final String? url;
  final String? filePath;
  final double? latitude;
  final double? longitude;

  bool get _hasGeo => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context) {
    final imageWidget = filePath != null
        ? Image.file(
            File(filePath!),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 64),
          )
        : Image.network(
            url!,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 64),
          );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(child: imageWidget),
          ),
          if (_hasGeo)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.greenAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Geo-tagged',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${latitude!.toStringAsFixed(6)}°, ${longitude!.toStringAsFixed(6)}°',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final uri = Uri.parse(
                          'https://www.google.com/maps?q=${latitude!},${longitude!}',
                        );
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.map, size: 18, color: Colors.greenAccent),
                      label: const Text('Open in Maps', style: TextStyle(color: Colors.greenAccent)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

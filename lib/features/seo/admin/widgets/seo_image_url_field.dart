import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Hero / OG image URL field with live preview.
class SeoImageUrlField extends StatelessWidget {
  const SeoImageUrlField({
    super.key,
    required this.label,
    required this.controller,
    this.helperText,
  });

  final String label;
  final TextEditingController controller;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            helperText: helperText ?? 'Paste a public image URL (shop-media or CDN)',
          ),
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final url = controller.text.trim();
            if (url.isEmpty) return const SizedBox.shrink();
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Text('Invalid image URL'),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

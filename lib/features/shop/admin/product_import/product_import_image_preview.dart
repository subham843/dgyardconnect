import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Horizontal strip of remote image thumbnails for import preview.
class ProductImportImagePreview extends StatelessWidget {
  const ProductImportImagePreview({
    super.key,
    required this.urls,
    required this.onRemove,
    this.mainIndex = 0,
    this.onSetMain,
  });

  final List<String> urls;
  final ValueChanged<int> onRemove;
  final int mainIndex;
  final ValueChanged<int>? onSetMain;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images (${urls.length}) — first is main',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _Thumb(
              url: urls[index],
              isMain: index == mainIndex,
              onRemove: () => onRemove(index),
              onSetMain: onSetMain == null ? null : () => onSetMain!(index),
            ),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.url,
    required this.isMain,
    required this.onRemove,
    this.onSetMain,
  });

  final String url;
  final bool isMain;
  final VoidCallback onRemove;
  final VoidCallback? onSetMain;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: onSetMain,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMain ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                width: isMain ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, _, _) => ColoredBox(
                color: Colors.grey.shade100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Preview blocked',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isMain)
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact row for PDF/document links in preview.
class ProductImportDocumentPreview extends StatelessWidget {
  const ProductImportDocumentPreview({
    super.key,
    required this.title,
    required this.urls,
    required this.icon,
    required this.onRemove,
  });

  final String title;
  final List<String> urls;
  final IconData icon;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ...urls.asMap().entries.map(
              (e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, size: 20),
                title: Text(
                  _label(e.value),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove',
                  onPressed: () => onRemove(e.key),
                ),
              ),
            ),
      ],
    );
  }

  static String _label(String url) {
    try {
      final seg = Uri.parse(url).pathSegments.last;
      if (seg.isNotEmpty) return seg;
    } catch (_) {}
    return url;
  }
}

// Public CMS rows from Supabase `public_cms_content`.

class PublicCmsItem {
  const PublicCmsItem({
    required this.id,
    required this.contentType,
    this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
    this.metadata = const {},
  });

  final String id;
  final String contentType;
  final String? title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final Map<String, dynamic> metadata;

  String? metaString(String key) {
    final v = metadata[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int get rating {
    final v = metadata['rating'] ?? metadata['stars'];
    if (v is num) return v.round().clamp(1, 5);
    final parsed = int.tryParse(v?.toString() ?? '');
    if (parsed == null) return 5;
    return parsed.clamp(1, 5);
  }

  factory PublicCmsItem.fromRow(Map<String, dynamic> row) {
    final meta = row['metadata'];
    return PublicCmsItem(
      id: row['id'].toString(),
      contentType: (row['content_type'] ?? '').toString(),
      title: row['title'] as String?,
      subtitle: row['subtitle'] as String?,
      description: row['description'] as String?,
      imageUrl: row['image_url'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      metadata: meta is Map ? Map<String, dynamic>.from(meta) : const {},
    );
  }
}

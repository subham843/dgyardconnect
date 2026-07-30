class SeoBlogPost {
  const SeoBlogPost({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.body,
    this.heroImageUrl,
    this.authorName = 'D.G.Yard',
    this.citySlugs = const [],
    this.serviceSlugs = const [],
    this.seoTitle,
    this.metaDescription,
    this.sortOrder = 0,
    this.isActive = true,
    this.publishedAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? body;
  final String? heroImageUrl;
  final String authorName;
  final List<String> citySlugs;
  final List<String> serviceSlugs;
  final String? seoTitle;
  final String? metaDescription;
  final int sortOrder;
  final bool isActive;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  factory SeoBlogPost.fromMap(Map<String, dynamic> map) => SeoBlogPost(
        id: map['id'] as String,
        title: (map['title'] ?? '').toString(),
        slug: (map['slug'] ?? '').toString(),
        excerpt: map['excerpt'] as String?,
        body: map['body'] as String?,
        heroImageUrl: map['hero_image_url'] as String?,
        authorName: (map['author_name'] ?? 'D.G.Yard').toString(),
        citySlugs: _stringList(map['city_slugs']),
        serviceSlugs: _stringList(map['service_slugs']),
        seoTitle: map['seo_title'] as String?,
        metaDescription: map['meta_description'] as String?,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        isActive: map['is_active'] as bool? ?? true,
        publishedAt: map['published_at'] != null ? DateTime.tryParse(map['published_at'].toString()) : null,
        updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'title': title,
        'slug': slug,
        'excerpt': excerpt,
        'body': body,
        'hero_image_url': heroImageUrl,
        'author_name': authorName,
        'city_slugs': citySlugs,
        'service_slugs': serviceSlugs,
        'seo_title': seoTitle,
        'meta_description': metaDescription,
        'sort_order': sortOrder,
        'is_active': isActive,
        'published_at': publishedAt?.toIso8601String(),
      };

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

import 'seo_service.dart';

class SeoCity {
  const SeoCity({
    required this.id,
    required this.name,
    required this.state,
    required this.slug,
    this.latitude,
    this.longitude,
    this.priority = 0,
    this.description,
    this.serviceAvailable = true,
    this.isActive = true,
    this.nearbyDistricts = const [],
    this.businessDescription,
    this.heroImageUrl,
    this.imageUrl,
    this.faq = const [],
    this.seoTitle,
    this.metaDescription,
    this.metaKeywords,
    this.ogTitle,
    this.ogDescription,
    this.canonicalUrl,
    this.robots = 'index, follow',
    this.schemaOverride,
    this.nearbyCities = const [],
    this.updatedAt,
  });

  final String id;
  final String name;
  final String state;
  final String slug;
  final double? latitude;
  final double? longitude;
  final int priority;
  final String? description;
  final bool serviceAvailable;
  final bool isActive;
  final List<String> nearbyDistricts;
  final String? businessDescription;
  final String? heroImageUrl;
  final String? imageUrl;
  final List<SeoFaqItem> faq;
  final String? seoTitle;
  final String? metaDescription;
  final String? metaKeywords;
  final String? ogTitle;
  final String? ogDescription;
  final String? canonicalUrl;
  final String robots;
  final Map<String, dynamic>? schemaOverride;
  final List<SeoNearbyCity> nearbyCities;
  final DateTime? updatedAt;

  factory SeoCity.fromMap(Map<String, dynamic> map, {List<SeoNearbyCity> nearby = const []}) {
    return SeoCity(
      id: map['id'] as String,
      name: (map['name'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      slug: (map['slug'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      description: map['description'] as String?,
      serviceAvailable: map['service_available'] as bool? ?? true,
      isActive: map['is_active'] as bool? ?? true,
      nearbyDistricts: _stringList(map['nearby_districts']),
      businessDescription: map['business_description'] as String?,
      heroImageUrl: map['hero_image_url'] as String?,
      imageUrl: map['image_url'] as String?,
      faq: _faqList(map['faq']),
      seoTitle: map['seo_title'] as String?,
      metaDescription: map['meta_description'] as String?,
      metaKeywords: map['meta_keywords'] as String?,
      ogTitle: map['og_title'] as String?,
      ogDescription: map['og_description'] as String?,
      canonicalUrl: map['canonical_url'] as String?,
      robots: (map['robots'] ?? 'index, follow').toString(),
      schemaOverride: map['schema_override'] is Map
          ? Map<String, dynamic>.from(map['schema_override'] as Map)
          : null,
      nearbyCities: nearby,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'state': state,
        'slug': slug,
        'latitude': latitude,
        'longitude': longitude,
        'priority': priority,
        'description': description,
        'service_available': serviceAvailable,
        'is_active': isActive,
        'nearby_districts': nearbyDistricts,
        'business_description': businessDescription,
        'hero_image_url': heroImageUrl,
        'image_url': imageUrl,
        'faq': faq.map((e) => e.toMap()).toList(),
        'seo_title': seoTitle,
        'meta_description': metaDescription,
        'meta_keywords': metaKeywords,
        'og_title': ogTitle,
        'og_description': ogDescription,
        'canonical_url': canonicalUrl,
        'robots': robots,
        'schema_override': schemaOverride,
      };

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static List<SeoFaqItem> _faqList(dynamic value) {
    if (value is! List) return [];
    return value
        .map((e) => SeoFaqItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class SeoNearbyCity {
  const SeoNearbyCity({
    required this.id,
    required this.name,
    required this.state,
    required this.slug,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String state;
  final String slug;
  final int sortOrder;

  factory SeoNearbyCity.fromMap(Map<String, dynamic> map) => SeoNearbyCity(
        id: (map['nearby_city_id'] ?? map['id'] ?? '').toString(),
        name: (map['nearby_city_name'] ?? map['name'] ?? '').toString(),
        state: (map['nearby_city_state'] ?? map['state'] ?? '').toString(),
        slug: (map['nearby_city_slug'] ?? map['slug'] ?? '').toString(),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class SeoService {
  const SeoService({
    required this.id,
    required this.name,
    required this.slug,
    this.shortDescription,
    this.description,
    this.heroImageUrl,
    this.iconName = 'build_rounded',
    this.features = const [],
    this.processSteps = const [],
    this.whyChoose = const [],
    this.areasCoveredTemplate,
    this.pricingCtaText = 'Get a free quote',
    this.relatedProductCategorySlugs = const [],
    this.sortOrder = 0,
    this.isActive = true,
    this.seoTitleTemplate,
    this.metaDescriptionTemplate,
    this.h1Template,
    this.h2FeaturesTemplate,
    this.faqTemplate = const [],
    this.schemaServiceType,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final String? description;
  final String? heroImageUrl;
  final String iconName;
  final List<String> features;
  final List<SeoProcessStep> processSteps;
  final List<String> whyChoose;
  final String? areasCoveredTemplate;
  final String pricingCtaText;
  final List<String> relatedProductCategorySlugs;
  final int sortOrder;
  final bool isActive;
  final String? seoTitleTemplate;
  final String? metaDescriptionTemplate;
  final String? h1Template;
  final String? h2FeaturesTemplate;
  final List<SeoFaqItem> faqTemplate;
  final String? schemaServiceType;
  final DateTime? updatedAt;

  factory SeoService.fromMap(Map<String, dynamic> map) {
    return SeoService(
      id: map['id'] as String,
      name: (map['name'] ?? '').toString(),
      slug: (map['slug'] ?? '').toString(),
      shortDescription: map['short_description'] as String?,
      description: map['description'] as String?,
      heroImageUrl: map['hero_image_url'] as String?,
      iconName: (map['icon_name'] ?? 'build_rounded').toString(),
      features: _stringList(map['features']),
      processSteps: _processSteps(map['process_steps']),
      whyChoose: _stringList(map['why_choose']),
      areasCoveredTemplate: map['areas_covered_template'] as String?,
      pricingCtaText: (map['pricing_cta_text'] ?? 'Get a free quote').toString(),
      relatedProductCategorySlugs: _stringList(map['related_product_category_slugs']),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      seoTitleTemplate: map['seo_title_template'] as String?,
      metaDescriptionTemplate: map['meta_description_template'] as String?,
      h1Template: map['h1_template'] as String?,
      h2FeaturesTemplate: map['h2_features_template'] as String?,
      faqTemplate: _faqList(map['faq_template']),
      schemaServiceType: map['schema_service_type'] as String?,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'slug': slug,
        'short_description': shortDescription,
        'description': description,
        'hero_image_url': heroImageUrl,
        'icon_name': iconName,
        'features': features,
        'process_steps': processSteps.map((e) => e.toMap()).toList(),
        'why_choose': whyChoose,
        'areas_covered_template': areasCoveredTemplate,
        'pricing_cta_text': pricingCtaText,
        'related_product_category_slugs': relatedProductCategorySlugs,
        'sort_order': sortOrder,
        'is_active': isActive,
        'seo_title_template': seoTitleTemplate,
        'meta_description_template': metaDescriptionTemplate,
        'h1_template': h1Template,
        'h2_features_template': h2FeaturesTemplate,
        'faq_template': faqTemplate.map((e) => e.toMap()).toList(),
        'schema_service_type': schemaServiceType,
      };

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static List<SeoProcessStep> _processSteps(dynamic value) {
    if (value is! List) return [];
    return value
        .map((e) => SeoProcessStep.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<SeoFaqItem> _faqList(dynamic value) {
    if (value is! List) return [];
    return value
        .map((e) => SeoFaqItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class SeoProcessStep {
  const SeoProcessStep({required this.title, required this.description});

  final String title;
  final String description;

  factory SeoProcessStep.fromMap(Map<String, dynamic> map) => SeoProcessStep(
        title: (map['title'] ?? '').toString(),
        description: (map['description'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {'title': title, 'description': description};
}

class SeoFaqItem {
  const SeoFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  factory SeoFaqItem.fromMap(Map<String, dynamic> map) => SeoFaqItem(
        question: (map['q'] ?? map['question'] ?? '').toString(),
        answer: (map['a'] ?? map['answer'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {'q': question, 'a': answer};
}

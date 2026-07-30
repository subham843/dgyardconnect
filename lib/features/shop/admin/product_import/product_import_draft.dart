/// AI-generated product draft before admin approval.
class ProductImportConfidence {
  const ProductImportConfidence({
    required this.overall,
    this.fields = const {},
  });

  final double overall;
  final Map<String, double> fields;

  factory ProductImportConfidence.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProductImportConfidence(overall: 0);
    final fieldsRaw = json['fields'];
    final fields = <String, double>{};
    if (fieldsRaw is Map) {
      fieldsRaw.forEach((k, v) {
        if (v is num) fields[k.toString()] = v.toDouble().clamp(0, 1);
      });
    }
    return ProductImportConfidence(
      overall: ((json['overall'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      fields: fields,
    );
  }
}

class ProductImportSpec {
  const ProductImportSpec({required this.label, required this.value});
  final String label;
  final String value;

  factory ProductImportSpec.fromJson(Map<String, dynamic> json) => ProductImportSpec(
        label: json['label'] as String? ?? json['key'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

class ProductImportAttributeDraft {
  const ProductImportAttributeDraft({
    required this.key,
    required this.label,
    required this.dataType,
    this.value,
    this.allowedValues = const [],
    this.isNew = false,
  });

  final String key;
  final String label;
  final String dataType;
  final String? value;
  final List<String> allowedValues;
  final bool isNew;

  factory ProductImportAttributeDraft.fromJson(Map<String, dynamic> json) {
    final av = json['allowed_values'] ?? json['allowedValues'];
    return ProductImportAttributeDraft(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? json['key'] as String? ?? '',
      dataType: json['data_type'] as String? ?? json['dataType'] as String? ?? 'text',
      value: json['value'] as String?,
      allowedValues: av is List ? av.map((e) => e.toString()).toList() : const [],
      isNew: json['is_new'] as bool? ?? json['isNew'] as bool? ?? false,
    );
  }
}

class ProductImportDraft {
  const ProductImportDraft({
    required this.name,
    this.brandName,
    this.modelName,
    this.categorySlug,
    this.categoryName,
    this.subCategorySlug,
    this.subCategoryName,
    this.attributeGroupNames = const [],
    this.description,
    this.shortDescription,
    this.technicalNotes,
    this.installationNotes,
    this.hsnCode,
    this.gstPercentage,
    this.costPrice,
    this.mrp,
    this.onlinePrice,
    this.dealerPrice,
    this.warranty,
    this.warrantyMonths,
    this.seoTitle,
    this.metaDescription,
    this.slug,
    this.keywords = const [],
    this.specifications = const [],
    this.attributes = const [],
    this.imageUrls = const [],
    this.datasheetUrls = const [],
    this.manualUrls = const [],
    this.sourceUrl,
    this.manufacturer,
    this.provider,
    this.confidence = const ProductImportConfidence(overall: 0),
  });

  final String name;
  final String? brandName;
  final String? modelName;
  final String? categorySlug;
  final String? categoryName;
  final String? subCategorySlug;
  final String? subCategoryName;
  final List<String> attributeGroupNames;
  final String? description;
  final String? shortDescription;
  final String? technicalNotes;
  final String? installationNotes;
  final String? hsnCode;
  final double? gstPercentage;
  final double? costPrice;
  final double? mrp;
  final double? onlinePrice;
  final double? dealerPrice;
  final String? warranty;
  final int? warrantyMonths;
  final String? seoTitle;
  final String? metaDescription;
  final String? slug;
  final List<String> keywords;
  final List<ProductImportSpec> specifications;
  final List<ProductImportAttributeDraft> attributes;
  final List<String> imageUrls;
  final List<String> datasheetUrls;
  final List<String> manualUrls;
  final String? sourceUrl;
  final String? manufacturer;
  final String? provider;
  final ProductImportConfidence confidence;

  ProductImportDraft copyWith({
    String? name,
    String? brandName,
    String? modelName,
    String? categorySlug,
    String? categoryName,
    String? subCategorySlug,
    String? subCategoryName,
    List<String>? attributeGroupNames,
    String? description,
    String? shortDescription,
    String? technicalNotes,
    String? installationNotes,
    String? hsnCode,
    double? gstPercentage,
    double? costPrice,
    double? mrp,
    double? onlinePrice,
    double? dealerPrice,
    String? warranty,
    int? warrantyMonths,
    String? seoTitle,
    String? metaDescription,
    String? slug,
    List<String>? keywords,
    List<ProductImportSpec>? specifications,
    List<ProductImportAttributeDraft>? attributes,
    List<String>? imageUrls,
    List<String>? datasheetUrls,
    List<String>? manualUrls,
  }) {
    return ProductImportDraft(
      name: name ?? this.name,
      brandName: brandName ?? this.brandName,
      modelName: modelName ?? this.modelName,
      categorySlug: categorySlug ?? this.categorySlug,
      categoryName: categoryName ?? this.categoryName,
      subCategorySlug: subCategorySlug ?? this.subCategorySlug,
      subCategoryName: subCategoryName ?? this.subCategoryName,
      attributeGroupNames: attributeGroupNames ?? this.attributeGroupNames,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      technicalNotes: technicalNotes ?? this.technicalNotes,
      installationNotes: installationNotes ?? this.installationNotes,
      hsnCode: hsnCode ?? this.hsnCode,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      costPrice: costPrice ?? this.costPrice,
      mrp: mrp ?? this.mrp,
      onlinePrice: onlinePrice ?? this.onlinePrice,
      dealerPrice: dealerPrice ?? this.dealerPrice,
      warranty: warranty ?? this.warranty,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      seoTitle: seoTitle ?? this.seoTitle,
      metaDescription: metaDescription ?? this.metaDescription,
      slug: slug ?? this.slug,
      keywords: keywords ?? this.keywords,
      specifications: specifications ?? this.specifications,
      attributes: attributes ?? this.attributes,
      imageUrls: imageUrls ?? this.imageUrls,
      datasheetUrls: datasheetUrls ?? this.datasheetUrls,
      manualUrls: manualUrls ?? this.manualUrls,
      sourceUrl: sourceUrl,
      manufacturer: manufacturer,
      provider: provider,
      confidence: confidence,
    );
  }

  factory ProductImportDraft.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : json;
    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) fn) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((e) => fn(Map<String, dynamic>.from(e))).toList();
    }

    return ProductImportDraft(
      name: product['name'] as String? ?? '',
      brandName: product['brand_name'] as String? ?? product['brandName'] as String?,
      modelName: product['model_name'] as String? ?? product['modelName'] as String?,
      categorySlug: product['category_slug'] as String? ?? product['categorySlug'] as String?,
      categoryName: product['category_name'] as String? ?? product['categoryName'] as String?,
      subCategorySlug: product['sub_category_slug'] as String? ?? product['subCategorySlug'] as String?,
      subCategoryName: product['sub_category_name'] as String? ?? product['subCategoryName'] as String?,
      attributeGroupNames: (product['attribute_group_names'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      description: product['description'] as String?,
      shortDescription: product['short_description'] as String? ?? product['shortDescription'] as String?,
      technicalNotes: product['technical_notes'] as String? ?? product['technicalNotes'] as String?,
      installationNotes: product['installation_notes'] as String? ?? product['installationNotes'] as String?,
      hsnCode: product['hsn_code'] as String? ?? product['hsnCode'] as String?,
      gstPercentage: (product['gst_percentage'] as num?)?.toDouble() ?? (product['gstPercentage'] as num?)?.toDouble(),
      costPrice: (product['cost_price'] as num?)?.toDouble() ?? (product['costPrice'] as num?)?.toDouble(),
      mrp: (product['mrp'] as num?)?.toDouble(),
      onlinePrice: (product['online_price'] as num?)?.toDouble() ?? (product['onlinePrice'] as num?)?.toDouble(),
      dealerPrice: (product['dealer_price'] as num?)?.toDouble() ?? (product['dealerPrice'] as num?)?.toDouble(),
      warranty: product['warranty'] as String?,
      warrantyMonths: (product['warranty_months'] as num?)?.toInt() ?? (product['warrantyMonths'] as num?)?.toInt(),
      seoTitle: product['seo_title'] as String? ?? product['seoTitle'] as String?,
      metaDescription: product['meta_description'] as String? ?? product['metaDescription'] as String?,
      slug: product['slug'] as String? ?? product['url_slug'] as String?,
      keywords: (product['keywords'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      specifications: list(product['specifications'], ProductImportSpec.fromJson),
      attributes: list(product['attributes'], ProductImportAttributeDraft.fromJson),
      imageUrls: (product['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
          (product['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      datasheetUrls: (product['datasheet_urls'] as List?)?.map((e) => e.toString()).toList() ??
          (product['datasheetUrls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      manualUrls: (product['manual_urls'] as List?)?.map((e) => e.toString()).toList() ??
          (product['manualUrls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      sourceUrl: json['source_url'] as String? ?? json['sourceUrl'] as String? ?? product['source_url'] as String?,
      manufacturer: json['manufacturer'] as String? ?? product['manufacturer'] as String?,
      provider: json['provider'] as String?,
      confidence: ProductImportConfidence.fromJson(
        json['confidence'] is Map ? Map<String, dynamic>.from(json['confidence'] as Map) : null,
      ),
    );
  }
}

enum ProductImportSourceType {
  url,
  modelNumber,
  datasheetPdf,
  manufacturerPage,
}

extension ProductImportSourceTypeX on ProductImportSourceType {
  String get apiValue => switch (this) {
        ProductImportSourceType.url => 'url',
        ProductImportSourceType.modelNumber => 'model_number',
        ProductImportSourceType.datasheetPdf => 'datasheet_pdf',
        ProductImportSourceType.manufacturerPage => 'manufacturer_page',
      };

  String get label => switch (this) {
        ProductImportSourceType.url => 'Product URL',
        ProductImportSourceType.modelNumber => 'Model number',
        ProductImportSourceType.datasheetPdf => 'Datasheet PDF',
        ProductImportSourceType.manufacturerPage => 'Manufacturer page',
      };
}

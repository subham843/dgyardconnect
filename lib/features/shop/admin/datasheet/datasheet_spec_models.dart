class DatasheetSpecPair {
  const DatasheetSpecPair({required this.label, required this.value});

  final String label;
  final String value;

  factory DatasheetSpecPair.fromJson(Map<String, dynamic> json) => DatasheetSpecPair(
        label: json['label'] as String? ?? json['key'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

class DatasheetExtractedSpecs {
  const DatasheetExtractedSpecs({
    this.modelName,
    this.hsnCode,
    this.warranty,
    this.warrantyMonths,
    this.shortDescription,
    this.description,
    this.technicalNotes,
    this.installationNotes,
    this.specifications = const [],
    this.attributeHints = const [],
  });

  final String? modelName;
  final String? hsnCode;
  final String? warranty;
  final int? warrantyMonths;
  final String? shortDescription;
  final String? description;
  final String? technicalNotes;
  final String? installationNotes;
  final List<DatasheetSpecPair> specifications;
  final List<DatasheetSpecPair> attributeHints;

  factory DatasheetExtractedSpecs.fromJson(Map<String, dynamic> json) {
    List<DatasheetSpecPair> pairs(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => DatasheetSpecPair.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.label.isNotEmpty || p.value.isNotEmpty)
          .toList();
    }

    return DatasheetExtractedSpecs(
      modelName: json['modelName'] as String?,
      hsnCode: json['hsnCode'] as String?,
      warranty: json['warranty'] as String?,
      warrantyMonths: (json['warrantyMonths'] as num?)?.toInt(),
      shortDescription: json['shortDescription'] as String?,
      description: json['description'] as String?,
      technicalNotes: json['technicalNotes'] as String?,
      installationNotes: json['installationNotes'] as String?,
      specifications: pairs(json['specifications']),
      attributeHints: pairs(json['attributeHints']),
    );
  }
}

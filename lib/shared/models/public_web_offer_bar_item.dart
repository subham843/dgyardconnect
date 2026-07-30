/// Admin-managed promo line shown below the public website navbar (Apple-style).
class PublicWebOfferBarItem {
  const PublicWebOfferBarItem({
    required this.text,
    this.linkUrl,
    this.linkLabel,
  });

  final String text;
  final String? linkUrl;
  final String? linkLabel;

  bool get isEmpty => text.trim().isEmpty;

  factory PublicWebOfferBarItem.fromMap(Map<String, dynamic> map) {
    return PublicWebOfferBarItem(
      text: (map['text'] ?? '').toString(),
      linkUrl: _optional(map['linkUrl']),
      linkLabel: _optional(map['linkLabel']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text.trim(),
      if (linkUrl != null && linkUrl!.trim().isNotEmpty) 'linkUrl': linkUrl!.trim(),
      if (linkLabel != null && linkLabel!.trim().isNotEmpty) 'linkLabel': linkLabel!.trim(),
    };
  }

  static String? _optional(dynamic value) {
    final v = value?.toString().trim() ?? '';
    return v.isEmpty ? null : v;
  }

  static List<PublicWebOfferBarItem> parseList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => PublicWebOfferBarItem.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => !e.isEmpty)
        .toList();
  }
}

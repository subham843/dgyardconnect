/// Normalizes Firestore map payloads (web often returns `Map<Object?, Object?>`).
Map<String, dynamic>? firestoreStringMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return null;
}

List<String> firestoreStringList(dynamic value) {
  if (value is! List) return const [];
  final urls = <String>[];
  for (final item in value) {
    if (item is String) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) urls.add(trimmed);
    } else if (item != null) {
      final trimmed = item.toString().trim();
      if (trimmed.startsWith('http')) urls.add(trimmed);
    }
  }
  return urls;
}

String? firestoreStringField(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

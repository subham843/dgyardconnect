/// Lightweight RFC-style CSV parser (quoted fields, commas).
abstract final class ShopCsvParser {
  static List<Map<String, String>> parseRows(String raw) {
    final text = raw.replaceFirst('\uFEFF', '').trim();
    if (text.isEmpty) return [];

    final lines = _splitLines(text);
    if (lines.isEmpty) return [];

    final headers = _parseLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
    final rows = <Map<String, String>>[];

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = _parseLine(line);
      final map = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        final key = headers[j];
        if (key.isEmpty) continue;
        map[key] = j < cells.length ? cells[j].trim() : '';
      }
      rows.add(map);
    }
    return rows;
  }

  static List<String> _splitLines(String text) {
    final lines = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (!inQuotes && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        lines.add(buf.toString());
        buf.clear();
        continue;
      }
      buf.write(ch);
    }
    if (buf.isNotEmpty) lines.add(buf.toString());
    return lines;
  }

  static List<String> _parseLine(String line) {
    final cells = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch == ',' && !inQuotes) {
        cells.add(buf.toString());
        buf.clear();
        continue;
      }
      buf.write(ch);
    }
    cells.add(buf.toString());
    return cells;
  }
}

bool shopCsvBool(String? value, {bool defaultValue = true}) {
  if (value == null || value.trim().isEmpty) return defaultValue;
  final s = value.trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes' || s == 'y';
}

int shopCsvInt(String? value, {int defaultValue = 0}) {
  if (value == null || value.trim().isEmpty) return defaultValue;
  return int.tryParse(value.trim()) ?? defaultValue;
}

double shopCsvDouble(String? value, {double defaultValue = 0}) {
  if (value == null || value.trim().isEmpty) return defaultValue;
  return double.tryParse(value.trim()) ?? defaultValue;
}

List<String> shopCsvPipeList(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  return value.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

String? shopCsvOptional(String? value) {
  final t = value?.trim();
  if (t == null || t.isEmpty) return null;
  return t;
}

/// First non-empty value among column aliases (headers are lowercased).
String? shopCsvField(Map<String, String> row, List<String> keys) {
  for (final k in keys) {
    final v = shopCsvOptional(row[k]);
    if (v != null) return v;
  }
  return null;
}

double shopCsvGstField(Map<String, String> row, {double? defaultValue}) {
  final raw = shopCsvField(row, [
    'gst_percentage',
    'gst_percent',
    'tax_percentage',
    'default_gst_percentage',
    'default_gst',
    'gst',
  ]);
  if (raw == null) return defaultValue ?? 18;
  return shopCsvDouble(raw, defaultValue: defaultValue ?? 18);
}

String? shopCsvHsnField(Map<String, String> row) =>
    shopCsvField(row, ['hsn_code', 'default_hsn_code', 'hsn', 'sac_code']);

int? shopCsvOptionalInt(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return int.tryParse(value.trim());
}

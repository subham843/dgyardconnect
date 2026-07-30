abstract final class ShopCsvWriter {
  static String escape(String? value) {
    final v = value ?? '';
    if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String row(List<String?> cells) => cells.map(escape).join(',');

  static String boolStr(bool v) => v ? 'true' : 'false';

  static String pipeJoin(Iterable<String> values) => values.join('|');

  static String buildCsv({required List<String> headers, required List<List<String?>> rows}) {
    final buf = StringBuffer();
    buf.writeln(row(headers));
    for (final r in rows) {
      buf.writeln(row(r));
    }
    return buf.toString().trim();
  }
}

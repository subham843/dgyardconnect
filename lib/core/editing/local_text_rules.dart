/// Client-side quick checks (no overwrite — suggestions only).
abstract final class LocalTextRules {
  static List<String> quickIssues(String text, {bool hindiExpected = false}) {
    final issues = <String>[];
    if (text.contains('  ')) issues.add('Extra spaces detected');
    if (text.isNotEmpty && !hindiExpected && text[0] == text[0].toLowerCase()) {
      issues.add('First letter could be capitalized');
    }
    if (RegExp(r'\bi\b').hasMatch(text)) {
      issues.add('Use "I" instead of "i" where appropriate');
    }
    return issues;
  }

  static bool looksHindi(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }
}

import 'package:flutter/foundation.dart';

/// Minimal semantic version for comparing app versions (ignores build metadata).
///
/// Accepts: "1.2.3", "1.2", "1", "1.2.3+45" (build ignored), "v1.2.3".
@immutable
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static SemanticVersion? tryParse(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final plus = s.indexOf('+');
    if (plus != -1) s = s.substring(0, plus);
    final parts = s.split('.');
    if (parts.isEmpty) return null;

    int parsePart(int idx) {
      if (idx >= parts.length) return 0;
      return int.tryParse(parts[idx].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    return SemanticVersion(parsePart(0), parsePart(1), parsePart(2));
  }

  @override
  int compareTo(SemanticVersion other) {
    final m = major.compareTo(other.major);
    if (m != 0) return m;
    final n = minor.compareTo(other.minor);
    if (n != 0) return n;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}


import 'semantic_version.dart';
import 'update_decision.dart';

class UpdateChecker {
  UpdateChecker._();

  /// Decide whether update is required/optional based on versions.
  ///
  /// - Force update if `current < minSupported`
  /// - Optional update if `current < latest`
  static UpdateDecision decide({
    required String currentVersion,
    required String latestVersion,
    required String minSupportedVersion,
  }) {
    final current = SemanticVersion.tryParse(currentVersion);
    final latest = SemanticVersion.tryParse(latestVersion);
    final minSupported = SemanticVersion.tryParse(minSupportedVersion);

    if (current == null || latest == null || minSupported == null) {
      return UpdateDecision.none;
    }

    if (current.compareTo(minSupported) < 0) {
      return UpdateDecision.force(
        currentVersion: current.toString(),
        latestVersion: latest.toString(),
        minSupportedVersion: minSupported.toString(),
      );
    }

    if (current.compareTo(latest) < 0) {
      return UpdateDecision.optional(
        currentVersion: current.toString(),
        latestVersion: latest.toString(),
        minSupportedVersion: minSupported.toString(),
      );
    }

    return UpdateDecision.none;
  }
}


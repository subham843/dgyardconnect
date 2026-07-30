import 'package:flutter/foundation.dart';

enum UpdateType { none, optional, force }

@immutable
class UpdateDecision {
  const UpdateDecision._(this.type, {this.currentVersion = '', this.latestVersion = '', this.minSupportedVersion = ''});

  final UpdateType type;
  final String currentVersion;
  final String latestVersion;
  final String minSupportedVersion;

  static const none = UpdateDecision._(UpdateType.none);

  static UpdateDecision optional({
    required String currentVersion,
    required String latestVersion,
    required String minSupportedVersion,
  }) {
    return UpdateDecision._(
      UpdateType.optional,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      minSupportedVersion: minSupportedVersion,
    );
  }

  static UpdateDecision force({
    required String currentVersion,
    required String latestVersion,
    required String minSupportedVersion,
  }) {
    return UpdateDecision._(
      UpdateType.force,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      minSupportedVersion: minSupportedVersion,
    );
  }

  bool get isUpdateAvailable => type != UpdateType.none;
  bool get isForce => type == UpdateType.force;
}


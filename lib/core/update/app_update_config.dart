import 'package:flutter/foundation.dart';

enum AppUpdateSource { apk, playstore, unknown }

@immutable
class AppUpdateConfig {
  const AppUpdateConfig({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.source,
    required this.releaseId,
    required this.title,
    required this.message,
    required this.changelog,
    required this.updateUrl,
    required this.apkUrl,
  });

  final String latestVersion;
  final String minSupportedVersion;
  final AppUpdateSource source;
  final String releaseId;
  final String title;
  final String message;
  final String changelog;
  final String updateUrl;
  final String apkUrl;
}


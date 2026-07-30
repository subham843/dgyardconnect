import 'package:flutter/foundation.dart';

import '../update/app_update_config.dart';
import 'app_remote_config.dart';

/// Web stub — remote config / force-update is mobile-only.
class AppRemoteConfigController extends ChangeNotifier {
  AppRemoteConfig get config => AppRemoteConfig(
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  AppUpdateConfig get updateConfig => const AppUpdateConfig(
        latestVersion: '',
        minSupportedVersion: '',
        source: AppUpdateSource.unknown,
        releaseId: '',
        title: '',
        message: '',
        changelog: '',
        updateUrl: '',
        apkUrl: '',
      );

  Future<void> initAndFetch() async {}
  Future<void> refresh() async {}

}

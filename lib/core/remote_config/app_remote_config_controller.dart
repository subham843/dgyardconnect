import 'package:flutter/foundation.dart';

import '../update/app_update_config.dart';
import 'app_remote_config.dart';
import 'firebase_remote_config_service.dart';

/// Holds current Remote Config values in memory and notifies listeners.
class AppRemoteConfigController extends ChangeNotifier {
  AppRemoteConfigController({FirebaseRemoteConfigService? service})
      : _service = service ?? FirebaseRemoteConfigService.instance;

  final FirebaseRemoteConfigService _service;

  AppRemoteConfig _config = AppRemoteConfig(fetchedAt: DateTime.fromMillisecondsSinceEpoch(0));
  AppUpdateConfig _update = const AppUpdateConfig(
    latestVersion: '',
    minSupportedVersion: '',
    source: AppUpdateSource.unknown,
    releaseId: '',
    title: 'Update available',
    message: '',
    changelog: '',
    updateUrl: '',
    apkUrl: '',
  );

  bool _initialized = false;
  bool get isInitialized => _initialized;

  AppRemoteConfig get config => _config;
  AppUpdateConfig get updateConfig => _update;

  Future<void> initAndFetch() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (!_service.isAvailable) return;
    await _service.init();
    await _service.fetchAndActivate();
    _config = _service.readAppConfig();
    _update = _service.readUpdateConfig();
    notifyListeners();
  }
}


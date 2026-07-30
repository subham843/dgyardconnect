import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../update/app_update_config.dart';
import 'app_remote_config.dart';
import 'remote_config_keys.dart';

/// Thin wrapper around `firebase_remote_config` with safe parsing and defaults.
class FirebaseRemoteConfigService {
  FirebaseRemoteConfigService._();

  static final FirebaseRemoteConfigService instance = FirebaseRemoteConfigService._();

  FirebaseRemoteConfig? _rc;

  bool get isAvailable => Firebase.apps.isNotEmpty;

  Future<void> init() async {
    if (!isAvailable) return;
    _rc ??= FirebaseRemoteConfig.instance;

    await _rc!.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 8),
      // For app-updates we want reasonably fast propagation in release too.
      // Remote Config still applies server-side throttling, so this is safe.
      minimumFetchInterval:
          kDebugMode ? const Duration(seconds: 0) : const Duration(minutes: 1),
    ));

    await _rc!.setDefaults(<String, Object>{
      RemoteConfigKeys.uiPrimaryColorHex: '',
      RemoteConfigKeys.appTextsJson: '{}',
      RemoteConfigKeys.featureFlagsJson: '{}',
      RemoteConfigKeys.latestVersion: '',
      RemoteConfigKeys.minSupportedVersion: '',
      RemoteConfigKeys.updateSource: 'playstore',
      RemoteConfigKeys.updateTitle: 'Update available',
      RemoteConfigKeys.updateMessage: '',
      RemoteConfigKeys.updateChangelog: '',
      RemoteConfigKeys.updateUrl: '',
      RemoteConfigKeys.apkUrl: '',
      RemoteConfigKeys.updateReleaseId: '',
    });
  }

  Future<bool> fetchAndActivate() async {
    if (!isAvailable) return false;
    await init();
    try {
      return await _rc!.fetchAndActivate();
    } catch (_) {
      // Network / throttling errors should never crash app.
      return false;
    }
  }

  AppRemoteConfig readAppConfig() {
    final now = DateTime.now();
    if (!isAvailable || _rc == null) {
      return AppRemoteConfig(fetchedAt: now);
    }

    final primaryHex = _rc!.getString(RemoteConfigKeys.uiPrimaryColorHex).trim();

    return AppRemoteConfig(
      fetchedAt: now,
      primaryColorHex: primaryHex.isEmpty ? null : primaryHex,
      texts: _readStringMap(RemoteConfigKeys.appTextsJson),
      featureFlags: _readBoolMap(RemoteConfigKeys.featureFlagsJson),
    );
  }

  AppUpdateConfig readUpdateConfig() {
    if (!isAvailable || _rc == null) {
      return const AppUpdateConfig(
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
    }
    final rawSource = _rc!.getString(RemoteConfigKeys.updateSource).trim().toLowerCase();
    final source = switch (rawSource) {
      'apk' => AppUpdateSource.apk,
      'playstore' => AppUpdateSource.playstore,
      _ => AppUpdateSource.unknown,
    };
    return AppUpdateConfig(
      latestVersion: _rc!.getString(RemoteConfigKeys.latestVersion).trim(),
      minSupportedVersion: _rc!.getString(RemoteConfigKeys.minSupportedVersion).trim(),
      source: source,
      releaseId: _rc!.getString(RemoteConfigKeys.updateReleaseId).trim(),
      title: _rc!.getString(RemoteConfigKeys.updateTitle).trim().isEmpty ? 'Update available' : _rc!.getString(RemoteConfigKeys.updateTitle).trim(),
      message: _rc!.getString(RemoteConfigKeys.updateMessage).trim(),
      changelog: _rc!.getString(RemoteConfigKeys.updateChangelog).trim(),
      updateUrl: _rc!.getString(RemoteConfigKeys.updateUrl).trim(),
      apkUrl: _rc!.getString(RemoteConfigKeys.apkUrl).trim(),
    );
  }

  Map<String, String> _readStringMap(String key) {
    final raw = _rc!.getString(key).trim();
    if (raw.isEmpty) return const <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, String>{};
      return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } catch (_) {
      return const <String, String>{};
    }
  }

  Map<String, bool> _readBoolMap(String key) {
    final raw = _rc!.getString(key).trim();
    if (raw.isEmpty) return const <String, bool>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, bool>{};
      return decoded.map((k, v) => MapEntry(k.toString(), v is bool ? v : (v.toString().toLowerCase() == 'true')));
    } catch (_) {
      return const <String, bool>{};
    }
  }
}


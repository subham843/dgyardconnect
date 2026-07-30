import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../remote_config/app_remote_config_controller_export.dart';
import 'app_update_config.dart';

enum UpdateFlowStage {
  idle,
  launchingStore,
  downloading,
  requestingInstallPermission,
  installing,
  done,
  error,
}

@immutable
class UpdateFlowState {
  const UpdateFlowState({
    required this.stage,
    this.progress = 0,
    this.message = '',
  });

  final UpdateFlowStage stage;
  final int progress; // 0..100
  final String message;

  bool get isBusy =>
      stage == UpdateFlowStage.launchingStore ||
      stage == UpdateFlowStage.downloading ||
      stage == UpdateFlowStage.requestingInstallPermission ||
      stage == UpdateFlowStage.installing;
}

class UpdateService {
  UpdateService({required this.controller});

  final AppRemoteConfigController controller;

  final ValueNotifier<UpdateFlowState> state = ValueNotifier(
    const UpdateFlowState(stage: UpdateFlowStage.idle),
  );

  static const String _installedVersionKey = 'app_update_installed_version';
  static const String _completedVersionKey = 'app_update_completed_version';
  static const String _installedReleaseKey = 'app_update_installed_release_id';
  static const String _completedReleaseKey = 'app_update_completed_release_id';

  Future<void> start() async {
    final cfg = controller.updateConfig;
    if (cfg.source == AppUpdateSource.playstore) {
      await _openPlayStore(cfg.updateUrl);
      return;
    }
    if (cfg.source == AppUpdateSource.apk) {
      await _downloadAndInstallApk(cfg.apkUrl);
      return;
    }

    state.value = const UpdateFlowState(
      stage: UpdateFlowStage.error,
      message: 'Update source not configured.',
    );
  }

  Future<void> _openPlayStore(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      state.value = const UpdateFlowState(
        stage: UpdateFlowStage.error,
        message: 'Play Store URL is missing.',
      );
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      state.value = const UpdateFlowState(
        stage: UpdateFlowStage.error,
        message: 'Invalid Play Store URL.',
      );
      return;
    }
    state.value = const UpdateFlowState(
      stage: UpdateFlowStage.launchingStore,
      message: 'Opening store…',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        state.value = const UpdateFlowState(
          stage: UpdateFlowStage.error,
          message: 'Could not open the store.',
        );
        return;
      }
      // Persist completion immediately; app may restart/background without returning to the dialog.
      try {
        final prefs = await SharedPreferences.getInstance();
        final cfg = controller.updateConfig;
        final latest = cfg.latestVersion;
        if (latest.isNotEmpty) {
          await prefs.setString(_completedVersionKey, latest);
          await prefs.setString(_installedVersionKey, latest);
        }
        final releaseId = cfg.releaseId;
        if (releaseId.isNotEmpty) {
          await prefs.setString(_completedReleaseKey, releaseId);
          await prefs.setString(_installedReleaseKey, releaseId);
        }
      } catch (_) {}
      state.value = const UpdateFlowState(stage: UpdateFlowStage.done);
    } catch (_) {
      state.value = const UpdateFlowState(
        stage: UpdateFlowStage.error,
        message: 'Could not open the store.',
      );
    }
  }

  Future<void> _downloadAndInstallApk(String _) async {
    if (kIsWeb || !Platform.isAndroid) {
      state.value = const UpdateFlowState(
        stage: UpdateFlowStage.error,
        message: 'APK updates are supported on Android only.',
      );
      return;
    }
    state.value = const UpdateFlowState(
      stage: UpdateFlowStage.error,
      message:
          'Direct APK installs are disabled in Play builds. Please update from the Play Store.',
    );
  }

  void dispose() {
    state.dispose();
  }
}

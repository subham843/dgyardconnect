import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote_config/app_remote_config_controller_export.dart';
import '../remote_config/firebase_remote_config_service.dart';
import '../constants/route_names.dart';
import '../../shared/router/app_router.dart';
import 'semantic_version.dart';
import 'update_checker.dart';
import 'update_dialog.dart';

/// Runs the update check once on startup and shows a dialog if needed.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child, required this.controller});

  final Widget child;
  final AppRemoteConfigController controller;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  bool _ran = false;
  DateTime? _lastAttemptAt;
  bool _dialogOpen = false;

  static const _resumeCooldown = Duration(minutes: 2);
  static const _snoozeVersionKey = 'app_update_snooze_version';
  static const _snoozeUntilKey = 'app_update_snooze_until_ms';
  static const _installedVersionKey = 'app_update_installed_version';
  static const _completedVersionKey = 'app_update_completed_version';
  static const _snoozeReleaseKey = 'app_update_snooze_release_id';
  static const _installedReleaseKey = 'app_update_installed_release_id';
  static const _completedReleaseKey = 'app_update_completed_release_id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Re-check when route changes so we don't show on splash/intro.
    appRouter.routeInformationProvider.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    appRouter.routeInformationProvider.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onRouteChanged() {
    // If we navigated (e.g. splash -> home), allow re-run.
    _ran = false;
    _runOnce();
  }

  bool _isEligibleRouteForUpdateUi(String path) {
    // Only show update UI on main app areas (not intro/auth flows).
    if (path == RouteNames.dealerHome ||
        path.startsWith('${RouteNames.dealerHome}/')) {
      return true;
    }
    if (path == RouteNames.technicianHome ||
        path.startsWith('${RouteNames.technicianHome}/')) {
      return true;
    }
    if (path == RouteNames.adminHome ||
        path.startsWith('${RouteNames.adminHome}/')) {
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final last = _lastAttemptAt;
      if (last != null && now.difference(last) < _resumeCooldown) return;
      _ran = false;
      _runOnce();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _runOnce();
  }

  Future<void> _runOnce() async {
    if (_ran) return;
    _ran = true;
    _lastAttemptAt = DateTime.now();

    // Never show update popup on web.
    if (kIsWeb) return;

    if (!FirebaseRemoteConfigService.instance.isAvailable) return;

    // Refresh Remote Config (even if already initialized).
    try {
      await widget.controller.refresh();
    } catch (_) {}

    final info = await _safePackageInfo();
    if (!mounted) return;

    final updateCfg = widget.controller.updateConfig;
    if (updateCfg.latestVersion.isEmpty ||
        updateCfg.minSupportedVersion.isEmpty) {
      return;
    }

    // If current build already matches latest, mark it installed (can happen if app was updated outside the flow).
    await _markInstalledIfNeeded(
      currentVersion: info.version,
      latestVersion: updateCfg.latestVersion,
    );

    final decision = UpdateChecker.decide(
      currentVersion: info.version,
      latestVersion: updateCfg.latestVersion,
      minSupportedVersion: updateCfg.minSupportedVersion,
    );
    if (!decision.isUpdateAvailable) return;

    // If user already completed the update flow for this release/version, don't show again.
    final completed = await _isCompleted(
      releaseId: updateCfg.releaseId,
      latestVersion: updateCfg.latestVersion,
    );
    if (completed) return;

    // If this exact release/version was already installed/completed, don't nag again.
    final alreadyInstalled = await _isInstalled(
      releaseId: updateCfg.releaseId,
      latestVersion: updateCfg.latestVersion,
      currentVersion: info.version,
    );
    if (alreadyInstalled) return;

    // Respect "remind me later" for this release/version.
    final snoozed = await _isSnoozed(
      releaseId: updateCfg.releaseId,
      latestVersion: updateCfg.latestVersion,
    );
    if (snoozed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final nav = rootNavigatorKey.currentState;
      final dialogContext = nav?.overlay?.context ?? nav?.context;
      if (dialogContext == null) return;

      final uri = appRouter.routeInformationProvider.value.uri;
      final path = uri.path;
      if (!_isEligibleRouteForUpdateUi(path)) {
        // We're on splash/intro/auth screens. Wait until user lands on home.
        _ran = false;
        return;
      }

      if (_dialogOpen) return;
      _dialogOpen = true;
      final result = await showDialog<bool>(
        context: dialogContext,
        // Keep the overlay until user updates (as requested).
        barrierDismissible: false,
        builder: (ctx) =>
            UpdateDialog(decision: decision, controller: widget.controller),
      );
      _dialogOpen = false;
      if (!mounted) return;

      // If user chose "Later" (optional update), remember for some time.
      if (result == false && !decision.isForce) {
        final prefs = await SharedPreferences.getInstance();
        final until = DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch;
        await prefs.setString(_snoozeVersionKey, updateCfg.latestVersion);
        await prefs.setInt(_snoozeUntilKey, until);
        if (updateCfg.releaseId.isNotEmpty) {
          await prefs.setString(_snoozeReleaseKey, updateCfg.releaseId);
        }
        return;
      }

      // If update flow completed (store opened or APK installed), mark this release as completed so it won't nag again.
      if (result == true) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_completedVersionKey, updateCfg.latestVersion);
          await prefs.setString(_installedVersionKey, updateCfg.latestVersion);
          if (updateCfg.releaseId.isNotEmpty) {
            await prefs.setString(_completedReleaseKey, updateCfg.releaseId);
            await prefs.setString(_installedReleaseKey, updateCfg.releaseId);
          }
        } catch (_) {}
      }

      // Re-open until the user updates to latest.
      _ran = false;
      _runOnce();
    });
  }

  Future<bool> _isSnoozed({
    required String releaseId,
    required String latestVersion,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_snoozeVersionKey);
      final rid = prefs.getString(_snoozeReleaseKey);
      final untilMs = prefs.getInt(_snoozeUntilKey);
      if (v == null || untilMs == null) return false;
      if (v != latestVersion) return false;
      if (releaseId.isNotEmpty && rid != null && rid != releaseId) return false;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      return nowMs < untilMs;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isInstalled({
    required String releaseId,
    required String latestVersion,
    required String currentVersion,
  }) async {
    if (latestVersion.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (releaseId.isNotEmpty && prefs.getString(_installedReleaseKey) == releaseId) {
        return true;
      }
      final v = prefs.getString(_installedVersionKey);
      if (v != latestVersion) return false;
      return _isCurrentAtLeastLatest(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isCompleted({
    required String releaseId,
    required String latestVersion,
  }) async {
    if (latestVersion.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (releaseId.isNotEmpty && prefs.getString(_completedReleaseKey) == releaseId) {
        return true;
      }
      return prefs.getString(_completedVersionKey) == latestVersion;
    } catch (_) {
      return false;
    }
  }

  bool _isCurrentAtLeastLatest({
    required String currentVersion,
    required String latestVersion,
  }) {
    final currentSem = SemanticVersion.tryParse(currentVersion);
    final latestSem = SemanticVersion.tryParse(latestVersion);
    if (currentSem != null && latestSem != null) {
      return currentSem.compareTo(latestSem) >= 0;
    }
    return currentVersion.trim() == latestVersion.trim();
  }

  Future<void> _markInstalledIfNeeded({
    required String currentVersion,
    required String latestVersion,
  }) async {
    if (latestVersion.isEmpty) return;
    if (!_isCurrentAtLeastLatest(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
    )) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_installedVersionKey, latestVersion);
    } catch (_) {
      // ignore
    }
  }

  Future<PackageInfo> _safePackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return PackageInfo(
        appName: '',
        packageName: '',
        version: '0.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: null,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

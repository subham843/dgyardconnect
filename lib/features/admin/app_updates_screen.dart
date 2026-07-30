import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

class AdminAppUpdatesScreen extends StatefulWidget {
  const AdminAppUpdatesScreen({super.key});

  @override
  State<AdminAppUpdatesScreen> createState() => _AdminAppUpdatesScreenState();
}

class _AdminAppUpdatesScreenState extends State<AdminAppUpdatesScreen> {
  final _latest = TextEditingController();
  final _min = TextEditingController();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _changelog = TextEditingController();
  final _playUrl = TextEditingController();
  final _apkUrl = TextEditingController();

  // Runtime config (Remote Config)
  final _uiPrimaryHex = TextEditingController();
  final _textsJson = TextEditingController(text: '{}');
  final _flagsJson = TextEditingController(text: '{}');

  String _source = 'apk'; // apk | playstore
  bool _saving = false;
  bool _savingRuntime = false;
  bool _prefilledRuntime = false;
  late final Future<PackageInfo> _pkgFuture;
  bool _autoFillVersionFromApkUrl = true;
  bool _latestTouched = false;
  bool _minTouched = false;

  @override
  void initState() {
    super.initState();
    _pkgFuture = _safePackageInfo();
    _latest.addListener(() {
      // If user types, don't override from auto-fill.
      if (_latest.text.trim().isNotEmpty) _latestTouched = true;
    });
    _min.addListener(() {
      if (_min.text.trim().isNotEmpty) _minTouched = true;
    });
    _apkUrl.addListener(_maybeAutoFillFromUrl);
    _playUrl.addListener(_maybeAutoFillFromUrl);
  }

  @override
  void dispose() {
    _apkUrl.removeListener(_maybeAutoFillFromUrl);
    _playUrl.removeListener(_maybeAutoFillFromUrl);
    _latest.dispose();
    _min.dispose();
    _title.dispose();
    _message.dispose();
    _changelog.dispose();
    _playUrl.dispose();
    _apkUrl.dispose();
    _uiPrimaryHex.dispose();
    _textsJson.dispose();
    _flagsJson.dispose();
    super.dispose();
  }

  void _maybeAutoFillFromUrl() {
    if (!_autoFillVersionFromApkUrl) return;
    final rawSources = <String>[if (_apkUrl.text.trim().isNotEmpty) _apkUrl.text.trim(), if (_playUrl.text.trim().isNotEmpty) _playUrl.text.trim()];
    if (rawSources.isEmpty) return;

    for (final raw in rawSources) {
      final v = _tryExtractVersionFromUrl(raw);
      if (v == null || v.isEmpty) continue;
      if (!_latestTouched && _latest.text.trim().isEmpty) {
        _latest.text = v;
      }
      if (!_minTouched && _min.text.trim().isEmpty) {
        _min.text = v;
      }
      return;
    }
  }

  String? _tryExtractVersionFromUrl(String raw) {
    // Accept common version patterns from query params, path, filename, or plain text.
    try {
      final uri = Uri.tryParse(raw);
      final qp = uri?.queryParameters;
      final candidates = <String?>[
        qp?['version'],
        qp?['v'],
        qp?['ver'],
        qp?['versionName'],
      ];
      for (final candidate in candidates) {
        final qv = candidate?.trim();
        if (qv != null && qv.isNotEmpty) {
          final m = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(qv);
          if (m != null) return m.group(1);
          final m2 = RegExp(r'v?(\d+\.\d+)').firstMatch(qv);
          if (m2 != null) return '${m2.group(1)}.0';
        }
      }
    } catch (_) {}

    final decoded = Uri.decodeFull(raw);
    final patterns = [
      RegExp(r'v?(\d+\.\d+\.\d+)'),
      RegExp(r'v?(\d+\.\d+\.\d+\.\d+)'),
      RegExp(r'v?(\d+\.\d+)'),
      // Common filename patterns: 1_2_3, 1-2-3, v1_2, v1-2
      RegExp(r'v?(\d+[_-]\d+[_-]\d+)'),
      RegExp(r'v?(\d+[_-]\d+)'),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(decoded);
      if (m != null && m.groupCount >= 1) {
        final value = m.group(1);
        if (value != null && value.isNotEmpty) {
          final normalized = value.replaceAll('_', '.').replaceAll('-', '.');
          final parts = normalized.split('.');
          if (parts.length == 1) return '${parts[0]}.0.0';
          if (parts.length == 2) return '${parts[0]}.${parts[1]}.0';
          if (parts.length >= 3) return '${parts[0]}.${parts[1]}.${parts[2]}';
          return normalized;
        }
      }
    }
    return null;
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

  void _applyFromDoc(Map<String, dynamic>? d) {
    if (d == null) return;
    _latest.text = (d['latestVersion'] as String?) ?? _latest.text;
    _min.text = (d['minSupportedVersion'] as String?) ?? _min.text;
    _source = ((d['source'] as String?) ?? _source).toLowerCase() == 'playstore' ? 'playstore' : 'apk';
    _title.text = (d['title'] as String?) ?? _title.text;
    _message.text = (d['message'] as String?) ?? _message.text;
    _changelog.text = (d['changelog'] as String?) ?? _changelog.text;
    _playUrl.text = (d['updateUrl'] as String?) ?? _playUrl.text;
    _apkUrl.text = (d['apkUrl'] as String?) ?? _apkUrl.text;
    // If we prefill from server, consider these "touched" so auto-fill doesn't overwrite.
    if (_latest.text.trim().isNotEmpty) _latestTouched = true;
    if (_min.text.trim().isNotEmpty) _minTouched = true;
  }

  void _applyRuntimeFromDoc(Map<String, dynamic>? d) {
    if (d == null) return;
    _uiPrimaryHex.text = (d['uiPrimaryColorHex'] as String?) ?? _uiPrimaryHex.text;
    _textsJson.text = (d['appTextsJson'] as String?) ?? _textsJson.text;
    _flagsJson.text = (d['featureFlagsJson'] as String?) ?? _flagsJson.text;
  }

  Future<void> _save() async {
    final latest = _latest.text.trim();
    final min = _min.text.trim();
    final title = _title.text.trim();
    final message = _message.text.trim();
    final changelog = _changelog.text.trim();
    final updateUrl = _playUrl.text.trim();
    final apkUrl = _apkUrl.text.trim();

    if (_source == 'apk' && apkUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('APK source selected: please enter APK URL.')));
      return;
    }
    if (_source == 'playstore' && updateUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Play Store source selected: please enter Play Store URL.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('setAppUpdateConfig').call({
        // Versions are optional now: Cloud Function auto-extracts from URL if empty.
        'app_latest_version': latest,
        'app_min_supported_version': min,
        'app_update_source': _source,
        'app_update_title': title,
        'app_update_message': message,
        'app_update_changelog': changelog,
        'app_update_url': updateUrl,
        'app_update_apk_url': apkUrl,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update config published.')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRuntime() async {
    final primary = _uiPrimaryHex.text.trim();
    final texts = _textsJson.text.trim().isEmpty ? '{}' : _textsJson.text.trim();
    final flags = _flagsJson.text.trim().isEmpty ? '{}' : _flagsJson.text.trim();

    try {
      jsonDecode(texts);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texts JSON is invalid.')));
      return;
    }
    try {
      jsonDecode(flags);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature flags JSON is invalid.')));
      return;
    }

    setState(() => _savingRuntime = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('setAppRuntimeConfig').call({
        'ui_primary_color_hex': primary,
        'app_texts_json': texts,
        'feature_flags_json': flags,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Runtime config published.')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _savingRuntime = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App updates'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(RouteNames.adminHome);
          },
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Publish'),
          ),
        ],
      ),
      body: !FirestoreService.isAvailable
          ? const Center(child: Text('Firebase is not configured.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.appUpdateConfig().snapshots(),
              builder: (context, updateSnap) {
                final updateData = updateSnap.data?.data();
                if (updateData != null && _latest.text.isEmpty && _min.text.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _applyFromDoc(updateData));
                  });
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.appRuntimeConfig().snapshots(),
                  builder: (context, runtimeSnap) {
                    final runtimeData = runtimeSnap.data?.data();
                    if (runtimeData != null && !_prefilledRuntime) {
                      _prefilledRuntime = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _applyRuntimeFromDoc(runtimeData));
                      });
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        FutureBuilder<PackageInfo>(
                          future: _pkgFuture,
                          builder: (context, snap) {
                            final info = snap.data;
                            final version = info?.version ?? '—';
                            final build = info?.buildNumber ?? '—';
                            final publishedLatest = (updateData?['latestVersion'] as String?)?.trim().isEmpty == true
                                ? '—'
                                : ((updateData?['latestVersion'] as String?) ?? '—');
                            final publishedMin = (updateData?['minSupportedVersion'] as String?)?.trim().isEmpty == true
                                ? '—'
                                : ((updateData?['minSupportedVersion'] as String?) ?? '—');
                            final publishedApk = (updateData?['apkUrl'] as String?)?.trim().isEmpty == true
                                ? '—'
                                : ((updateData?['apkUrl'] as String?) ?? '—');
                            return _Section(
                              title: 'Version info',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('This app build: $version ($build)'),
                                  const SizedBox(height: 6),
                                  Text('Published latest: $publishedLatest   Min: $publishedMin'),
                                  const SizedBox(height: 6),
                                  Text('Published APK URL: $publishedApk'),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _Section(
                          title: 'Version rules',
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Auto-fill version from APK URL'),
                                subtitle: const Text('Works when the URL/filename contains version like v1.2.0'),
                                value: _autoFillVersionFromApkUrl,
                                onChanged: (v) => setState(() {
                                  _autoFillVersionFromApkUrl = v;
                                  if (v) _maybeAutoFillFromUrl();
                                }),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _latest,
                                      decoration: const InputDecoration(
                                        labelText: 'Latest version',
                                        hintText: 'e.g. 1.3.0',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _min,
                                      decoration: const InputDecoration(
                                        labelText: 'Minimum supported',
                                        hintText: 'e.g. 1.2.0',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _source,
                                items: const [
                                  DropdownMenuItem(value: 'apk', child: Text('APK (Firebase Storage / direct link)')),
                                  DropdownMenuItem(value: 'playstore', child: Text('Play Store')),
                                ],
                                onChanged: _saving ? null : (v) => setState(() => _source = v ?? 'apk'),
                                decoration: const InputDecoration(labelText: 'Update source'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Section(
                          title: 'Update content',
                          child: Column(
                            children: [
                              TextField(
                                controller: _title,
                                decoration: const InputDecoration(labelText: 'Title'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _message,
                                decoration: const InputDecoration(labelText: 'Message'),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _changelog,
                                decoration: const InputDecoration(labelText: 'Changelog'),
                                maxLines: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Section(
                          title: 'Links',
                          child: Column(
                            children: [
                              TextField(
                                controller: _playUrl,
                                decoration: const InputDecoration(
                                  labelText: 'Play Store URL',
                                  hintText: 'Used when source = playstore',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _apkUrl,
                                decoration: const InputDecoration(
                                  labelText: 'APK URL',
                                  hintText: 'Used when source = apk (Firebase Storage download URL)',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (updateData != null) _CurrentStateCard(data: updateData),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.system_update_alt_rounded),
                          label: const Text('Publish update config'),
                        ),
                        const SizedBox(height: 24),

                        _Section(
                          title: 'Runtime config (no app update needed)',
                          child: Column(
                            children: [
                              TextField(
                                controller: _uiPrimaryHex,
                                decoration: const InputDecoration(
                                  labelText: 'Primary color hex (ui_primary_color_hex)',
                                  hintText: '#1E88E5 (empty to disable override)',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _textsJson,
                                decoration: const InputDecoration(
                                  labelText: 'Texts JSON (app_texts_json)',
                                  hintText: '{"home_banner":"Hello"}',
                                ),
                                maxLines: 6,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _flagsJson,
                                decoration: const InputDecoration(
                                  labelText: 'Feature flags JSON (feature_flags_json)',
                                  hintText: '{"enableChat":true}',
                                ),
                                maxLines: 6,
                              ),
                            ],
                          ),
                        ),
                        if (runtimeData != null) _RuntimeStateCard(data: runtimeData),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _savingRuntime ? null : _saveRuntime,
                          icon: _savingRuntime
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.tune_rounded),
                          label: const Text('Publish runtime config'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'These values update via Remote Config (colors/text/flags) without forcing an app update.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CurrentStateCard extends StatelessWidget {
  const _CurrentStateCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ts = data['updatedAt'];
    final updatedAt = ts is Timestamp ? ts.toDate() : null;
    final by = (data['updatedBy'] as String?) ?? '—';
    final source = (data['source'] as String?) ?? '—';
    final latest = (data['latestVersion'] as String?) ?? '—';
    final min = (data['minSupportedVersion'] as String?) ?? '—';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current published', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Source: $source'),
            Text('Latest: $latest'),
            Text('Min supported: $min'),
            Text('Updated by: ${by.length > 12 ? '${by.substring(0, 12)}…' : by}'),
            if (updatedAt != null) Text('Updated at: ${updatedAt.toLocal()}'),
          ],
        ),
      ),
    );
  }
}

class _RuntimeStateCard extends StatelessWidget {
  const _RuntimeStateCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ts = data['updatedAt'];
    final updatedAt = ts is Timestamp ? ts.toDate() : null;
    final by = (data['updatedBy'] as String?) ?? '—';
    final primary = (data['uiPrimaryColorHex'] as String?) ?? '';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current runtime config', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Primary override: ${primary.isEmpty ? '—' : primary}'),
            Text('Updated by: ${by.length > 12 ? '${by.substring(0, 12)}…' : by}'),
            if (updatedAt != null) Text('Updated at: ${updatedAt.toLocal()}'),
          ],
        ),
      ),
    );
  }
}


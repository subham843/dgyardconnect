import 'dart:ui';
import 'package:flutter/material.dart';

import '../remote_config/app_remote_config_controller_export.dart';
import 'update_service.dart';
import 'update_decision.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.decision,
    required this.controller,
  });

  final UpdateDecision decision;
  final AppRemoteConfigController controller;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  late final UpdateService _service;
  bool _autoClosed = false;

  @override
  void initState() {
    super.initState();
    _service = UpdateService(controller: widget.controller);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    final update = widget.controller.updateConfig;
    // Optional updates can be snoozed via "Remind me later".
    final canSkip = !decision.isForce;

    return PopScope(
      canPop: canSkip,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: ValueListenableBuilder<UpdateFlowState>(
                  valueListenable: _service.state,
                  builder: (context, flow, _) {
                    final isBusy = flow.isBusy;

                    if (!_autoClosed && flow.stage == UpdateFlowStage.done) {
                      _autoClosed = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Navigator.of(context).pop(true);
                      });
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Header(isForce: decision.isForce),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            update.title.isEmpty ? (decision.isForce ? 'Update required' : 'Update available') : update.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (update.message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(update.message, style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _VersionRow(
                          current: decision.currentVersion,
                          latest: decision.latestVersion,
                          minSupported: decision.minSupportedVersion,
                          showMin: decision.isForce,
                        ),
                        if (update.changelog.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _ChangelogBox(text: update.changelog),
                        ],
                        if (flow.stage == UpdateFlowStage.downloading) ...[
                          const SizedBox(height: 14),
                          LinearProgressIndicator(value: flow.progress / 100),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(flow.message, style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ] else if (flow.stage == UpdateFlowStage.launchingStore ||
                            flow.stage == UpdateFlowStage.requestingInstallPermission ||
                            flow.stage == UpdateFlowStage.installing) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(flow.message, style: Theme.of(context).textTheme.bodySmall)),
                            ],
                          ),
                        ] else if (flow.stage == UpdateFlowStage.error) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.errorContainer,
                            ),
                            child: Text(
                              flow.message.isEmpty ? 'Something went wrong.' : flow.message,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (canSkip) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isBusy
                                      ? null
                                      : () {
                                          Navigator.of(context).pop(false);
                                        },
                                  child: const Text('Remind me later'),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        await _service.start();
                                        if (!mounted) return;
                                      },
                                child: Text(decision.isForce ? 'Update now' : 'Update'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Please update to continue.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isForce});
  final bool isForce;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isForce ? cs.errorContainer : cs.primaryContainer;
    final fg = isForce ? cs.onErrorContainer : cs.onPrimaryContainer;
    final icon = isForce ? Icons.system_update_alt : Icons.update;
    final label = isForce ? 'Required' : 'Recommended';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
          const Spacer(),
          Text(
            isForce ? 'Force update' : 'Optional update',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.current,
    required this.latest,
    required this.minSupported,
    required this.showMin,
  });

  final String current;
  final String latest;
  final String minSupported;
  final bool showMin;

  @override
  Widget build(BuildContext context) {
    final styleKey = Theme.of(context).textTheme.bodySmall;
    final styleVal = Theme.of(context).textTheme.labelLarge;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Current', style: styleKey)),
              Text(current, style: styleVal),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Latest', style: styleKey)),
              Text(latest, style: styleVal),
            ],
          ),
          if (showMin) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('Minimum supported', style: styleKey)),
                Text(minSupported, style: styleVal),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangelogBox extends StatelessWidget {
  const _ChangelogBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}


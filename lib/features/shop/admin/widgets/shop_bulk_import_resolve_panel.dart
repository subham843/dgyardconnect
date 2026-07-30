import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../bulk/shop_bulk_import_issue.dart';
import '../bulk/shop_bulk_import_resolver.dart';
import '../bulk/shop_bulk_import_service.dart';
import '../bulk/shop_bulk_import_type.dart';

enum ShopBulkImportResolveMode { bulk, single }

class ShopBulkImportResolvePanel extends StatefulWidget {
  const ShopBulkImportResolvePanel({
    super.key,
    required this.importType,
    required this.result,
    required this.parsedRows,
    required this.resolver,
    required this.onRetryComplete,
    this.onRetryStart,
    this.onRetryFailed,
    this.retrying = false,
  });

  final ShopBulkImportType importType;
  final ShopBulkImportResult result;
  final List<Map<String, String>> parsedRows;
  final ShopBulkImportResolver resolver;
  final ValueChanged<ShopBulkImportRetryOutcome> onRetryComplete;
  final VoidCallback? onRetryStart;
  final VoidCallback? onRetryFailed;
  final bool retrying;

  @override
  State<ShopBulkImportResolvePanel> createState() => _ShopBulkImportResolvePanelState();
}

class _ShopBulkImportResolvePanelState extends State<ShopBulkImportResolvePanel> {
  ShopBulkImportResolveMode _mode = ShopBulkImportResolveMode.bulk;
  Map<ShopBulkImportIssueKind, List<ShopBulkImportReferenceOption>> _options = {};
  bool _loadingOptions = true;

  /// Bulk fixes keyed by issue.key
  final Map<String, ShopBulkImportFixAction> _bulkFixes = {};

  /// Single-row fixes keyed by "rowNumber|issueKey"
  final Map<String, ShopBulkImportFixAction> _singleFixes = {};

  String _singleFixKey(int rowNumber, ShopBulkImportIssue issue) => '$rowNumber|${issue.key}';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    try {
      final opts = await widget.resolver.loadAllReferenceOptions();
      if (mounted) {
        setState(() {
          _options = opts;
          _loadingOptions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  List<ShopBulkImportServiceGroup> get _groups => widget.resolver.groupResolvableIssues(widget.result);

  bool get _canRetry {
    if (_mode == ShopBulkImportResolveMode.bulk) {
      return _groups.isNotEmpty && _groups.every((g) => (_bulkFixes[g.issue.key]?.isReady ?? false));
    }
    final required = <String>[];
    for (final r in widget.result.resolvableFailures) {
      final issues = ShopBulkImportIssue.parseAll(r.message ?? '');
      for (final issue in issues) {
        required.add(_singleFixKey(r.rowNumber, issue));
      }
    }
    return required.isNotEmpty && required.every((k) => (_singleFixes[k]?.isReady ?? false));
  }

  List<ShopBulkImportFixAction> _collectFixes() {
    if (_mode == ShopBulkImportResolveMode.bulk) {
      return _bulkFixes.values.where((f) => f.isReady).toList();
    }
    return _singleFixes.values.where((f) => f.isReady).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.hasResolvableIssues) return const SizedBox.shrink();

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.link_off, color: Colors.orange.shade800, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.result.resolvableFailures.length} row(s) have missing references — fix and re-upload',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ShopBulkImportResolveMode>(
              segments: const [
                ButtonSegment(value: ShopBulkImportResolveMode.bulk, label: Text('Bulk fix'), icon: Icon(Icons.layers_outlined)),
                ButtonSegment(value: ShopBulkImportResolveMode.single, label: Text('Row by row'), icon: Icon(Icons.view_list_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: widget.retrying
                  ? null
                  : (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_loadingOptions)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_mode == ShopBulkImportResolveMode.bulk)
              ..._groups.map((g) => _BulkFixTile(
                    group: g,
                    options: _options[g.issue.kind] ?? const [],
                    action: _bulkFixes[g.issue.key],
                    onChanged: (a) => setState(() => _bulkFixes[g.issue.key] = a),
                  ))
            else
              ...widget.result.resolvableFailures.expand((r) {
                final issues = ShopBulkImportIssue.parseAll(r.message ?? '');
                return issues.map((issue) {
                  final key = _singleFixKey(r.rowNumber, issue);
                  return _SingleFixTile(
                    rowResult: r,
                    issue: issue,
                    options: _options[issue.kind] ?? const [],
                    action: _singleFixes[key],
                    onChanged: (a) => setState(() => _singleFixes[key] = a),
                  );
                });
              }),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: !_canRetry || widget.retrying
                  ? null
                  : () async {
                      widget.onRetryStart?.call();
                      try {
                        final fixes = _collectFixes();
                        final outcome = await widget.resolver.applyFixesAndRetry(
                          type: widget.importType,
                          rows: widget.parsedRows,
                          fixes: fixes,
                        );
                        widget.onRetryComplete(outcome);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Re-upload failed: $e')),
                          );
                        }
                        widget.onRetryFailed?.call();
                      }
                    },
              icon: widget.retrying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
              label: Text(widget.retrying ? 'Re-uploading…' : 'Apply fixes & re-upload'),
            ),
            if (!_canRetry)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Select an existing value or choose "Add new" for each missing reference above.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BulkFixTile extends StatelessWidget {
  const _BulkFixTile({
    required this.group,
    required this.options,
    required this.action,
    required this.onChanged,
  });

  final ShopBulkImportServiceGroup group;
  final List<ShopBulkImportReferenceOption> options;
  final ShopBulkImportFixAction? action;
  final ValueChanged<ShopBulkImportFixAction> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FixFields(
      title: '${group.issue.kind.label}: "${group.issue.missingValue}"',
      subtitle: 'Affects rows: ${group.rowNumbers.join(', ')}',
      issue: group.issue,
      options: options,
      action: action,
      onChanged: onChanged,
    );
  }
}

class _SingleFixTile extends StatelessWidget {
  const _SingleFixTile({
    required this.rowResult,
    required this.issue,
    required this.options,
    required this.action,
    required this.onChanged,
  });

  final ShopBulkImportRowResult rowResult;
  final ShopBulkImportIssue issue;
  final List<ShopBulkImportReferenceOption> options;
  final ShopBulkImportFixAction? action;
  final ValueChanged<ShopBulkImportFixAction> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FixFields(
      title: 'Row ${rowResult.rowNumber}: ${issue.kind.label} "${issue.missingValue}"',
      subtitle: rowResult.label,
      issue: issue,
      options: options,
      action: action,
      onChanged: onChanged,
    );
  }
}

class _FixFields extends StatefulWidget {
  const _FixFields({
    required this.title,
    required this.subtitle,
    required this.issue,
    required this.options,
    required this.action,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final ShopBulkImportIssue issue;
  final List<ShopBulkImportReferenceOption> options;
  final ShopBulkImportFixAction? action;
  final ValueChanged<ShopBulkImportFixAction> onChanged;

  @override
  State<_FixFields> createState() => _FixFieldsState();
}

class _FixFieldsState extends State<_FixFields> {
  ShopBulkImportFixMode _mode = ShopBulkImportFixMode.mapExisting;
  String? _selectedCsvValue;
  final _newNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newNameCtrl.text = widget.issue.missingValue;
    _syncFromAction();
    if (widget.action == null) {
      final match = widget.options.where((o) {
        final missing = widget.issue.missingValue.toLowerCase();
        return o.csvValue.toLowerCase() == missing || o.label.toLowerCase() == missing;
      }).firstOrNull;
      if (match != null) {
        _selectedCsvValue = match.csvValue;
        WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
      }
    }
  }

  @override
  void didUpdateWidget(covariant _FixFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action) _syncFromAction();
  }

  void _syncFromAction() {
    final a = widget.action;
    if (a == null) return;
    _mode = a.mode;
    _selectedCsvValue = a.existingCsvValue;
    _newNameCtrl.text = a.newName ?? widget.issue.missingValue;
  }

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final typed = _newNameCtrl.text.trim();
    widget.onChanged(ShopBulkImportFixAction(
      issue: widget.issue,
      mode: _mode,
      existingCsvValue: _selectedCsvValue,
      newName: typed.isEmpty ? null : typed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = widget.issue.kind.supportsCreateNew;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Use existing'),
                selected: _mode == ShopBulkImportFixMode.mapExisting,
                onSelected: (_) {
                  setState(() => _mode = ShopBulkImportFixMode.mapExisting);
                  _emit();
                },
              ),
              if (canCreate)
                ChoiceChip(
                  label: const Text('Add new'),
                  selected: _mode == ShopBulkImportFixMode.createNew,
                  onSelected: (_) {
                    setState(() {
                      _mode = ShopBulkImportFixMode.createNew;
                      if (_newNameCtrl.text.trim().isEmpty) {
                        _newNameCtrl.text = widget.issue.missingValue;
                      }
                    });
                    _emit();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_mode == ShopBulkImportFixMode.mapExisting)
            DropdownButtonFormField<String>(
              initialValue: _selectedCsvValue,
              decoration: InputDecoration(
                labelText: 'Select ${widget.issue.kind.label}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final o in widget.options)
                  DropdownMenuItem(value: o.csvValue, child: Text(o.label, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                setState(() => _selectedCsvValue = v);
                _emit();
              },
            )
          else if (canCreate)
            TextField(
              controller: _newNameCtrl,
              decoration: InputDecoration(
                labelText: 'New ${widget.issue.kind.label} name',
                border: const OutlineInputBorder(),
                isDense: true,
                helperText: 'Will be created before re-upload',
              ),
              onChanged: (_) => _emit(),
            )
          else
            Text(
              'Import the product first, or map to an existing SKU.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

extension _ResolvePanelFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

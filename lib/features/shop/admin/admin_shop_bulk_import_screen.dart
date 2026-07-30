import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import 'bulk/csv_file_export.dart';
import 'bulk/shop_bulk_delete_service.dart';
import 'bulk/shop_bulk_export_service.dart';
import 'bulk/shop_bulk_import_resolver.dart';
import 'bulk/shop_bulk_import_service.dart';
import 'bulk/shop_bulk_import_type.dart';
import 'bulk/shop_bulk_list_item.dart';
import 'bulk/shop_csv_parser.dart';
import 'bulk/shop_csv_templates.dart';
import 'widgets/shop_bulk_import_resolve_panel.dart';

class AdminShopBulkImportScreen extends StatefulWidget {
  const AdminShopBulkImportScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopBulkImportScreen> createState() => _AdminShopBulkImportScreenState();
}

class _AdminShopBulkImportScreenState extends State<AdminShopBulkImportScreen>
    with SingleTickerProviderStateMixin {
  final _importService = ShopBulkImportService();
  final _importResolver = ShopBulkImportResolver();
  final _deleteService = ShopBulkDeleteService();
  final _exportService = ShopBulkExportService();
  late final TabController _tabs;

  ShopBulkImportType _type = ShopBulkImportType.categories;
  bool _importing = false;
  bool _retryingImport = false;
  ShopBulkImportResult? _lastImportResult;
  List<Map<String, String>> _lastParsedRows = [];
  String? _pickedFileName;

  List<ShopBulkListItem> _deleteItems = [];
  final Set<String> _selectedIds = {};
  bool _loadingDeleteList = false;
  bool _deleting = false;
  ShopBulkImportResult? _lastDeleteResult;
  String _searchQuery = '';
  bool _exporting = false;
  int? _lastExportRowCount;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.index == 2 && !_tabs.indexIsChanging) {
      if (!_type.supportsBulkDelete) {
        setState(() => _type = ShopBulkImportType.categories);
      }
      _loadDeleteList();
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  List<ShopBulkImportType> get _orderedTypes => ShopBulkImportType.values.toList()
    ..sort((a, b) => a.recommendedOrder.compareTo(b.recommendedOrder));

  Future<void> _downloadData() async {
    setState(() {
      _exporting = true;
      _lastExportRowCount = null;
    });
    try {
      final result = await _exportService.export(_type);
      await exportCsvFile(result.filename, result.csv);
      if (mounted) {
        setState(() {
          _exporting = false;
          _lastExportRowCount = result.rowCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${result.rowCount} rows → ${result.filename}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _downloadSample() async {
    try {
      final content = ShopCsvTemplates.sampleFor(_type).trim();
      await exportCsvFile(_type.sampleFilename, content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sample CSV downloaded: ${_type.sampleFilename}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String? text;
    if (file.bytes != null) {
      text = utf8.decode(file.bytes!);
    } else if (file.readStream != null) {
      final chunks = <int>[];
      await for (final chunk in file.readStream!) {
        chunks.addAll(chunk);
      }
      if (chunks.isNotEmpty) text = utf8.decode(chunks);
    }
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read CSV file')));
      }
      return;
    }

    setState(() {
      _importing = true;
      _lastImportResult = null;
      _lastParsedRows = [];
      _pickedFileName = file.name;
    });

    try {
      final parsedRows = ShopCsvParser.parseRows(text);
      final importResult = await _importService.importParsedRows(type: _type, rows: parsedRows);
      if (mounted) {
        setState(() {
          _lastImportResult = importResult;
          _lastParsedRows = parsedRows;
          _importing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _loadDeleteList() async {
    if (!_type.supportsBulkDelete) {
      setState(() {
        _deleteItems = [];
        _selectedIds.clear();
        _loadingDeleteList = false;
      });
      return;
    }
    setState(() {
      _loadingDeleteList = true;
      _lastDeleteResult = null;
    });
    try {
      final items = await _deleteService.listItems(_type);
      if (mounted) {
        setState(() {
          _deleteItems = items;
          _selectedIds.removeWhere((id) => !items.any((e) => e.id == id));
          _loadingDeleteList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDeleteList = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load list: $e')));
      }
    }
  }

  List<ShopBulkListItem> get _filteredDeleteItems {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _deleteItems;
    return _deleteItems
        .where((e) =>
            e.label.toLowerCase().contains(q) ||
            (e.subtitle?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      if (select) {
        _selectedIds.addAll(_filteredDeleteItems.map((e) => e.id));
      } else {
        for (final e in _filteredDeleteItems) {
          _selectedIds.remove(e.id);
        }
      }
    });
  }

  Future<void> _confirmBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final selected = _deleteItems.where((e) => _selectedIds.contains(e.id)).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected permanently?'),
        content: Text(
          'Delete ${selected.length} ${_type.label.toLowerCase()} record(s)? '
          'This cannot be undone. Linked data may block some deletes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete ${selected.length}'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _deleting = true;
      _lastDeleteResult = null;
    });

    try {
      final result = await _deleteService.deleteItems(type: _type, items: selected);
      if (mounted) {
        setState(() {
          _lastDeleteResult = result;
          _deleting = false;
          _selectedIds.clear();
        });
        await _loadDeleteList();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _onRetryImportComplete(ShopBulkImportRetryOutcome outcome) async {
    if (!mounted) return;
    setState(() {
      _retryingImport = false;
      _lastImportResult = outcome.result;
      _lastParsedRows = outcome.patchedRows;
    });
    final r = outcome.result;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.failed == 0
              ? 'Re-upload done — created ${r.created}, skipped ${r.skipped}'
              : 'Re-upload finished — created ${r.created}, failed ${r.failed} (see details below)',
        ),
      ),
    );
  }

  void _onTypeChanged(ShopBulkImportType? v) {
    if (v == null) return;
    setState(() {
      _type = v;
      _selectedIds.clear();
      _lastDeleteResult = null;
      _lastImportResult = null;
      _lastParsedRows = [];
    });
    if (_tabs.index == 2) _loadDeleteList();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Bulk import, export & delete',
      embedded: widget.embedded,
      body: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.upload_file_outlined), text: 'Import'),
                Tab(icon: Icon(Icons.download_outlined), text: 'Download'),
                Tab(icon: Icon(Icons.delete_outline), text: 'Delete'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ImportTab(
                  type: _type,
                  orderedTypes: _orderedTypes,
                  importing: _importing,
                  retrying: _retryingImport,
                  pickedFileName: _pickedFileName,
                  lastResult: _lastImportResult,
                  parsedRows: _lastParsedRows,
                  resolver: _importResolver,
                  onTypeChanged: _onTypeChanged,
                  onDownloadSample: _downloadSample,
                  onUpload: _pickAndImport,
                  onRetryComplete: _onRetryImportComplete,
                  onRetryStart: () => setState(() => _retryingImport = true),
                  onRetryFailed: () => setState(() => _retryingImport = false),
                ),
                _ExportTab(
                  type: _type,
                  orderedTypes: _orderedTypes,
                  exporting: _exporting,
                  lastRowCount: _lastExportRowCount,
                  onTypeChanged: _onTypeChanged,
                  onDownloadData: _downloadData,
                  onDownloadSample: _downloadSample,
                ),
                _DeleteTab(
                  type: _type,
                  orderedTypes: _orderedTypes,
                  items: _filteredDeleteItems,
                  selectedIds: _selectedIds,
                  loading: _loadingDeleteList,
                  deleting: _deleting,
                  searchQuery: _searchQuery,
                  lastResult: _lastDeleteResult,
                  onTypeChanged: _onTypeChanged,
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                  onToggle: (id, on) => setState(() {
                    if (on) {
                      _selectedIds.add(id);
                    } else {
                      _selectedIds.remove(id);
                    }
                  }),
                  onSelectAll: _toggleSelectAll,
                  onRefresh: _loadDeleteList,
                  onDelete: _confirmBulkDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportTab extends StatelessWidget {
  const _ImportTab({
    required this.type,
    required this.orderedTypes,
    required this.importing,
    required this.retrying,
    required this.pickedFileName,
    required this.lastResult,
    required this.parsedRows,
    required this.resolver,
    required this.onTypeChanged,
    required this.onDownloadSample,
    required this.onUpload,
    required this.onRetryComplete,
    this.onRetryStart,
    this.onRetryFailed,
  });

  final ShopBulkImportType type;
  final List<ShopBulkImportType> orderedTypes;
  final bool importing;
  final bool retrying;
  final String? pickedFileName;
  final ShopBulkImportResult? lastResult;
  final List<Map<String, String>> parsedRows;
  final ShopBulkImportResolver resolver;
  final ValueChanged<ShopBulkImportType?> onTypeChanged;
  final VoidCallback onDownloadSample;
  final VoidCallback onUpload;
  final ValueChanged<ShopBulkImportRetryOutcome> onRetryComplete;
  final VoidCallback? onRetryStart;
  final VoidCallback? onRetryFailed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload shop master data from CSV',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Images are not imported. GST/HSN, pricing, warranty, stock, attributes, suppliers & customers supported.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TypeDropdown(type: type, orderedTypes: orderedTypes, enabled: !importing, onChanged: onTypeChanged),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: importing ? null : onDownloadSample,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download sample CSV'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: importing ? null : onUpload,
                icon: importing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_outlined),
                label: Text(importing ? 'Importing…' : 'Upload CSV'),
              ),
            ),
          ],
        ),
        if (pickedFileName != null) ...[
          const SizedBox(height: 8),
          Text('Last file: $pickedFileName', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
        if (lastResult != null) ...[
          const SizedBox(height: 24),
          _ResultSummary(result: lastResult!, deletedLabel: false),
          if (lastResult!.hasResolvableIssues && parsedRows.isNotEmpty)
            ShopBulkImportResolvePanel(
              importType: type,
              result: lastResult!,
              parsedRows: parsedRows,
              resolver: resolver,
              retrying: retrying,
              onRetryStart: onRetryStart,
              onRetryFailed: onRetryFailed,
              onRetryComplete: onRetryComplete,
            ),
        ],
      ],
    );
  }
}

class _ExportTab extends StatelessWidget {
  const _ExportTab({
    required this.type,
    required this.orderedTypes,
    required this.exporting,
    required this.lastRowCount,
    required this.onTypeChanged,
    required this.onDownloadData,
    required this.onDownloadSample,
  });

  final ShopBulkImportType type;
  final List<ShopBulkImportType> orderedTypes;
  final bool exporting;
  final int? lastRowCount;
  final ValueChanged<ShopBulkImportType?> onTypeChanged;
  final VoidCallback onDownloadData;
  final VoidCallback onDownloadSample;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Download live data as CSV',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Exports current database records in the same column format as import. '
                  'Edit in Excel/Sheets and re-upload via Import tab. Images are not included.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TypeDropdown(type: type, orderedTypes: orderedTypes, enabled: !exporting, onChanged: onTypeChanged),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: exporting ? null : onDownloadData,
          icon: exporting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.table_view_outlined),
          label: Text(exporting ? 'Preparing CSV…' : 'Download data CSV'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: exporting ? null : onDownloadSample,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Download empty sample template'),
        ),
        if (lastRowCount != null) ...[
          const SizedBox(height: 16),
          Text(
            'Last export: $lastRowCount data row(s)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _DeleteTab extends StatelessWidget {
  const _DeleteTab({
    required this.type,
    required this.orderedTypes,
    required this.items,
    required this.selectedIds,
    required this.loading,
    required this.deleting,
    required this.searchQuery,
    required this.lastResult,
    required this.onTypeChanged,
    required this.onSearchChanged,
    required this.onToggle,
    required this.onSelectAll,
    required this.onRefresh,
    required this.onDelete,
  });

  final ShopBulkImportType type;
  final List<ShopBulkImportType> orderedTypes;
  final List<ShopBulkListItem> items;
  final Set<String> selectedIds;
  final bool loading;
  final bool deleting;
  final String searchQuery;
  final ShopBulkImportResult? lastResult;
  final ValueChanged<ShopBulkImportType?> onTypeChanged;
  final ValueChanged<String> onSearchChanged;
  final void Function(String id, bool on) onToggle;
  final void Function(bool select) onSelectAll;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final deletableTypes = orderedTypes.where((t) => t.supportsBulkDelete).toList();
    final allFilteredSelected = items.isNotEmpty && items.every((e) => selectedIds.contains(e.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select records to delete permanently. Deleting a category may fail if sub-categories or products still exist.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _TypeDropdown(
                type: type,
                orderedTypes: deletableTypes,
                enabled: !deleting,
                onChanged: onTypeChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: loading || deleting ? null : () => onSelectAll(!allFilteredSelected),
                    icon: Icon(allFilteredSelected ? Icons.deselect : Icons.select_all),
                    label: Text(allFilteredSelected ? 'Clear selection' : 'Select all'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh list',
                    onPressed: loading || deleting ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                    onPressed: selectedIds.isEmpty || deleting ? null : onDelete,
                    icon: deleting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(deleting ? 'Deleting…' : 'Delete (${selectedIds.length})'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: !type.supportsBulkDelete
              ? const Center(child: Text('Bulk delete is not available for product attribute values.'))
              : loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? Center(child: Text(searchQuery.isEmpty ? 'No records found' : 'No matches for search'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final item = items[i];
                            final selected = selectedIds.contains(item.id);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: deleting ? null : (v) => onToggle(item.id, v == true),
                              title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                              secondary: const Icon(Icons.inventory_2_outlined, size: 20),
                            );
                          },
                        ),
        ),
        if (lastResult != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _ResultSummary(result: lastResult!, deletedLabel: true),
          ),
      ],
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({
    required this.type,
    required this.orderedTypes,
    required this.enabled,
    required this.onChanged,
  });

  final ShopBulkImportType type;
  final List<ShopBulkImportType> orderedTypes;
  final bool enabled;
  final ValueChanged<ShopBulkImportType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ShopBulkImportType>(
      initialValue: orderedTypes.contains(type) ? type : orderedTypes.first,
      decoration: const InputDecoration(
        labelText: 'Data type',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final t in orderedTypes)
          DropdownMenuItem(value: t, child: Text('${t.recommendedOrder}. ${t.label}')),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.result, required this.deletedLabel});

  final ShopBulkImportResult result;
  final bool deletedLabel;

  @override
  Widget build(BuildContext context) {
    final okLabel = deletedLabel ? 'Deleted' : 'Created';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$okLabel ${result.created} · Skipped ${result.skipped} · Failed ${result.failed}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...result.results.map((r) {
          final color = r.success
              ? (r.message?.startsWith('Skipped') == true ? Colors.orange : Colors.green)
              : Colors.red;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              r.success ? Icons.check_circle_outline : Icons.error_outline,
              color: color,
              size: 20,
            ),
            title: Text(
              deletedLabel ? r.label : 'Row ${r.rowNumber}: ${r.label}',
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: r.message != null ? Text(r.message!, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85))) : null,
          );
        }),
      ],
    );
  }
}

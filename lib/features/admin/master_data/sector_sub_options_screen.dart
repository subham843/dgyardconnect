import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class SectorSubOptionsScreen extends StatelessWidget {
  const SectorSubOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sector sub-options')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sector sub-options'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.sectorSubOptions().snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = List.from(snapshot.data!.docs)
            ..sort((a, b) {
              final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
              final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
              if (oa != ob) return oa.compareTo(ob);
              return (a.data()['name'] as String? ?? '').compareTo(b.data()['name'] as String? ?? '');
            });
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) => _reorderSubOptions(context, docs, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final id = docs[index].id;
              final name = d['name'] as String? ?? '—';
              final description = d['description'] as String? ?? '';
              final sectorId = d['sectorId'] as String? ?? '';
              final wiringEnabled = d['wiringEnabled'] == true;
              return KeyedSubtree(
                key: ValueKey(id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drag_handle, color: Colors.grey.shade500),
                      if (wiringEnabled) const SizedBox(width: 4),
                      if (wiringEnabled) const Icon(Icons.electrical_services, color: Colors.amber, size: 28),
                    ],
                  ),
                  title: Text(name),
                  subtitle: (description.isNotEmpty || sectorId.isNotEmpty)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (description.isNotEmpty) Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                            if (sectorId.isNotEmpty)
                              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirestoreService.sectors().doc(sectorId).get(),
                                builder: (_, s) {
                                  if (!s.hasData || !s.data!.exists) return Text('Sector', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600));
                                  return Text('Sector: ${s.data!.data()?['name'] ?? sectorId}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600));
                                },
                              ),
                          ],
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Move to position (currently ${index + 1})',
                        child: IconButton(
                          icon: const Icon(Icons.format_list_numbered, size: 20),
                          onPressed: () => _showMoveToPosition(context, docs, index, FirestoreService.sectorSubOptions()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        onPressed: index > 0 ? () => _moveSubOption(context, docs, index, -1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 20),
                        onPressed: index < docs.length - 1 ? () => _moveSubOption(context, docs, index, 1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showForm(context, id: id, initialName: name, initialDescription: description, sectorId: sectorId, initialWiringEnabled: wiringEnabled),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(context, id),
                      ),
                    ],
                  ),
                ),
                ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideX(begin: 0.02, end: 0),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showForm(BuildContext context, {String? id, String initialName = '', String initialDescription = '', String sectorId = '', bool initialWiringEnabled = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SubOptionFormSheet(
        id: id,
        initialName: initialName,
        initialDescription: initialDescription,
        initialSectorId: sectorId.isEmpty ? null : sectorId,
        initialWiringEnabled: initialWiringEnabled,
      ),
    );
  }

  Future<void> _reorderSubOptions(BuildContext context, List docs, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final item = docs.removeAt(oldIndex);
    docs.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < docs.length; i++) {
      batch.update(FirestoreService.sectorSubOptions().doc(docs[i].id), {'order': i});
    }
    await batch.commit();
  }

  Future<void> _showMoveToPosition(BuildContext context, List docs, int currentIndex, CollectionReference<Map<String, dynamic>> collection) async {
    final controller = TextEditingController(text: '${currentIndex + 1}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to position'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Position (1 to ${docs.length})',
            hintText: 'Enter position number',
          ),
          autofocus: true,
          onSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null && n >= 1 && n <= docs.length) Navigator.pop(ctx, n);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= 1 && n <= docs.length) Navigator.pop(ctx, n);
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (result == null || result == currentIndex + 1) return;
    final newIndex = (result - 1).clamp(0, docs.length - 1);
    final item = docs.removeAt(currentIndex);
    docs.insert(newIndex, item);
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < docs.length; i++) {
      batch.update(collection.doc(docs[i].id), {'order': i});
    }
    await batch.commit();
  }

  Future<void> _moveSubOption(BuildContext context, List docs, int index, int delta) async {
    final swapIndex = index + delta;
    if (swapIndex < 0 || swapIndex >= docs.length) return;
    final docA = docs[index];
    final docB = docs[swapIndex];
    final orderA = (docA.data()['order'] as num?)?.toInt() ?? index;
    final orderB = (docB.data()['order'] as num?)?.toInt() ?? swapIndex;
    await FirestoreService.sectorSubOptions().doc(docA.id).update({'order': orderB});
    await FirestoreService.sectorSubOptions().doc(docB.id).update({'order': orderA});
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sub-option?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await FirestoreService.sectorSubOptions().doc(id).delete();
  }
}

class _SubOptionEntry {
  _SubOptionEntry({String name = '', String description = '', this.wiringEnabled = false})
      : nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description);
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  bool wiringEnabled;
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
  }
}

class _SubOptionFormSheet extends StatefulWidget {
  const _SubOptionFormSheet({
    this.id,
    this.initialName = '',
    this.initialDescription = '',
    this.initialSectorId,
    this.initialWiringEnabled = false,
  });

  final String? id;
  final String initialName;
  final String initialDescription;
  final String? initialSectorId;
  final bool initialWiringEnabled;

  @override
  State<_SubOptionFormSheet> createState() => _SubOptionFormSheetState();
}

class _SubOptionFormSheetState extends State<_SubOptionFormSheet> {
  String? _sectorId;
  final List<_SubOptionEntry> _entries = [];

  bool get _isAddMode => widget.id == null;

  @override
  void initState() {
    super.initState();
    _entries.add(_SubOptionEntry(name: widget.initialName, description: widget.initialDescription, wiringEnabled: widget.initialWiringEnabled));
    if (widget.initialSectorId != null) _sectorId = widget.initialSectorId;
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _addEntry() => setState(() => _entries.add(_SubOptionEntry()));

  void _removeEntry(int index) {
    if (_entries.length <= 1) return;
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.sectors().snapshots(),
            builder: (context, sectorSnap) {
              final sectors = List.from(sectorSnap.data?.docs ?? [])
                ..sort((a, b) {
                  final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
                  final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
                  if (oa != ob) return oa.compareTo(ob);
                  return (a.data()['name'] as String? ?? '').compareTo(b.data()['name'] as String? ?? '');
                });
              var sectorValue = _sectorId;
              if (sectorValue != null && !sectors.any((d) => d.id == sectorValue)) sectorValue = null;
              if (sectorValue == null && sectors.isNotEmpty) {
                sectorValue = sectors.first.id;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _sectorId == null) setState(() => _sectorId = sectors.first.id);
                });
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_isAddMode ? 'Add sub-options' : 'Edit sub-option', style: Theme.of(context).textTheme.titleLarge),
                  if (_isAddMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Select sector, then add multiple sub-sectors',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: sectorValue,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sector'),
                    items: sectors
                        .map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.data()['name'] as String? ?? e.id)))
                        .toList(),
                    onChanged: (v) => setState(() => _sectorId = v),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_entries.length, (i) {
                    final e = _entries[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isAddMode && _entries.length > 1)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Sub-sector ${i + 1}', style: Theme.of(context).textTheme.titleSmall),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                      onPressed: () => _removeEntry(i),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              if (_isAddMode && _entries.length > 1) const SizedBox(height: 8),
                              TextField(
                                controller: e.nameController,
                                decoration: const InputDecoration(labelText: 'Name', isDense: true),
                                autofocus: _isAddMode && i == 0,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: e.descriptionController,
                                decoration: const InputDecoration(labelText: 'Description', isDense: true),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                title: const Text('Wiring add-on', style: TextStyle(fontSize: 14)),
                                value: e.wiringEnabled,
                                onChanged: (v) => setState(() => e.wiringEnabled = v),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_isAddMode) ...[
                    OutlinedButton.icon(
                      onPressed: _addEntry,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add another sub-sector'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      final sectorId = _sectorId;
                      if (sectorId == null || sectorId.isEmpty) return;
                      if (_isAddMode) {
                        final toAdd = <Map<String, dynamic>>[];
                        for (final e in _entries) {
                          final name = e.nameController.text.trim();
                          if (name.isEmpty) continue;
                          toAdd.add({
                            'name': name,
                            'description': e.descriptionController.text.trim(),
                            'sectorId': sectorId,
                            'wiringEnabled': e.wiringEnabled,
                          });
                        }
                        if (toAdd.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Add at least one sub-sector with a name.')),
                          );
                          return;
                        }
                        final batch = FirebaseFirestore.instance.batch();
                        final existing = await FirestoreService.sectorSubOptions().get();
                        final maxOrder = existing.docs.fold<int>(0, (m, d) {
                          final o = d.data()['order'];
                          if (o is num) return m > o.toInt() ? m : o.toInt();
                          return m;
                        });
                        for (var i = 0; i < toAdd.length; i++) {
                          toAdd[i]['order'] = maxOrder + 1 + i;
                        }
                        for (final data in toAdd) {
                          batch.set(FirestoreService.sectorSubOptions().doc(), data);
                        }
                        await batch.commit();
                      } else {
                        final name = _entries.first.nameController.text.trim();
                        if (name.isEmpty) return;
                        await FirestoreService.sectorSubOptions().doc(widget.id).update({
                          'name': name,
                          'description': _entries.first.descriptionController.text.trim(),
                          'sectorId': sectorId,
                          'wiringEnabled': _entries.first.wiringEnabled,
                        });
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text(_isAddMode ? 'Add all sub-sectors' : 'Save'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Skills')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.skills().snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = List.from(snapshot.data!.docs)
            ..sort((a, b) {
              final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
              final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
              if (oa != ob) return oa.compareTo(ob);
              return (a.data()['title'] as String? ?? '').compareTo(b.data()['title'] as String? ?? '');
            });
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) => _reorderSkills(context, docs, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final id = docs[index].id;
              final title = d['title'] as String? ?? '—';
              final description = d['description'] as String? ?? '';
              final sectorSubOptionId = d['sectorSubOptionId'] as String? ?? '';
              return KeyedSubtree(
                key: ValueKey(id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.drag_handle, color: Colors.grey.shade500),
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                      if (sectorSubOptionId.isNotEmpty)
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirestoreService.sectorSubOptions().doc(sectorSubOptionId).get(),
                          builder: (_, subSnap) {
                            if (!subSnap.hasData || !subSnap.data!.exists) return const SizedBox.shrink();
                            final subData = subSnap.data!.data();
                            final subName = subData?['name'] as String? ?? sectorSubOptionId;
                            final sectorId = subData?['sectorId'] as String? ?? '';
                            if (sectorId.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  subName,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                ),
                              );
                            }
                            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              future: FirestoreService.sectors().doc(sectorId).get(),
                              builder: (_, secSnap) {
                                final sectorName = (secSnap.hasData && secSnap.data!.exists)
                                    ? (secSnap.data!.data()?['name'] as String? ?? sectorId)
                                    : sectorId;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '$sectorName → $subName',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Move to position (currently ${index + 1})',
                        child: IconButton(
                          icon: const Icon(Icons.format_list_numbered, size: 20),
                          onPressed: () => _showMoveToPosition(context, docs, index, FirestoreService.skills()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        onPressed: index > 0 ? () => _moveSkill(context, docs, index, -1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 20),
                        onPressed: index < docs.length - 1 ? () => _moveSkill(context, docs, index, 1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showForm(
                          context,
                          id: id,
                          initialTitle: title,
                          initialDescription: description,
                          sectorSubOptionId: sectorSubOptionId,
                        ),
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

  void _showForm(
    BuildContext context, {
    String? id,
    String initialTitle = '',
    String initialDescription = '',
    String sectorSubOptionId = '',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SkillsFormSheet(
        id: id,
        initialTitle: initialTitle,
        initialDescription: initialDescription,
        initialSectorSubOptionId: sectorSubOptionId.isEmpty ? null : sectorSubOptionId,
      ),
    );
  }

  Future<void> _reorderSkills(BuildContext context, List docs, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final item = docs.removeAt(oldIndex);
    docs.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < docs.length; i++) {
      batch.update(FirestoreService.skills().doc(docs[i].id), {'order': i});
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

  Future<void> _moveSkill(BuildContext context, List docs, int index, int delta) async {
    final swapIndex = index + delta;
    if (swapIndex < 0 || swapIndex >= docs.length) return;
    final docA = docs[index];
    final docB = docs[swapIndex];
    final orderA = (docA.data()['order'] as num?)?.toInt() ?? index;
    final orderB = (docB.data()['order'] as num?)?.toInt() ?? swapIndex;
    await FirestoreService.skills().doc(docA.id).update({'order': orderB});
    await FirestoreService.skills().doc(docB.id).update({'order': orderA});
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete skill?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await FirestoreService.skills().doc(id).delete();
  }
}

class _SkillsFormSheet extends StatefulWidget {
  const _SkillsFormSheet({
    this.id,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialSectorSubOptionId,
  });

  final String? id;
  final String initialTitle;
  final String initialDescription;
  final String? initialSectorSubOptionId;

  @override
  State<_SkillsFormSheet> createState() => _SkillsFormSheetState();
}

class _SkillEntry {
  _SkillEntry({String title = '', String description = ''})
      : titleController = TextEditingController(text: title),
        descriptionController = TextEditingController(text: description);
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
  }
}

class _SkillsFormSheetState extends State<_SkillsFormSheet> {
  String? _sectorId;
  String? _sectorSubOptionId;
  bool _loaded = false;
  final List<_SkillEntry> _entries = [];

  bool get _isAddMode => widget.id == null;

  @override
  void initState() {
    super.initState();
    _entries.add(_SkillEntry(title: widget.initialTitle, description: widget.initialDescription));
    if (widget.initialSectorSubOptionId != null) {
      FirestoreService.sectorSubOptions().doc(widget.initialSectorSubOptionId).get().then((doc) {
        if (doc.exists && mounted) {
          final sid = doc.data()?['sectorId'] as String?;
          setState(() {
            _sectorId = sid;
            _sectorSubOptionId = widget.initialSectorSubOptionId;
            _loaded = true;
          });
        } else {
          setState(() => _loaded = true);
        }
      });
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _addSkillEntry() => setState(() => _entries.add(_SkillEntry()));

  void _removeSkillEntry(int index) {
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
              if (!_loaded && widget.initialSectorSubOptionId != null) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              final effectiveSectorId = _sectorId ?? (sectors.isNotEmpty ? sectors.first.id : null);
              if (_sectorId == null && sectors.isNotEmpty && widget.initialSectorSubOptionId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _sectorId == null) setState(() => _sectorId = sectors.first.id);
                });
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_isAddMode ? 'Add skills' : 'Edit skill', style: Theme.of(context).textTheme.titleLarge),
                  if (_isAddMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Select sector & sub-option, then add multiple skills',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: effectiveSectorId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sector'),
                    items: sectors
                        .map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.data()['name'] as String? ?? e.id)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _sectorId = v;
                      _sectorSubOptionId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (effectiveSectorId != null && effectiveSectorId.isNotEmpty)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.sectorSubOptions()
                          .where('sectorId', isEqualTo: effectiveSectorId)
                          .snapshots(),
                      builder: (context, subSnap) {
                        if (subSnap.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Error: ${subSnap.error}',
                              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                            ),
                          );
                        }
                        if (subSnap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final docs = subSnap.data?.docs ?? [];
                        final subs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
                          ..sort((a, b) => (a.data()['name'] as String? ?? '').compareTo(b.data()['name'] as String? ?? ''));
                        if (subs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No sub-options for this sector. Add sub-options in Sector sub-options first.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
                            ),
                          );
                        }
                        var subValue = _sectorSubOptionId;
                        if (subValue != null && !subs.any((d) => d.id == subValue)) subValue = null;
                        if (subValue == null && subs.isNotEmpty) {
                          subValue = subs.first.id;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _sectorSubOptionId == null) setState(() => _sectorSubOptionId = subs.first.id);
                          });
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: subValue,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Sector sub-option'),
                          items: subs
                              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.data()['name'] as String? ?? e.id)))
                              .toList(),
                          onChanged: (v) => setState(() => _sectorSubOptionId = v),
                        );
                      },
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
                                    Text('Skill ${i + 1}', style: Theme.of(context).textTheme.titleSmall),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                      onPressed: () => _removeSkillEntry(i),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              if (_isAddMode && _entries.length > 1) const SizedBox(height: 8),
                              TextField(
                                controller: e.titleController,
                                decoration: const InputDecoration(labelText: 'Skill title', isDense: true),
                                autofocus: _isAddMode && i == 0,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: e.descriptionController,
                                decoration: const InputDecoration(labelText: 'Description', isDense: true),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_isAddMode) ...[
                    OutlinedButton.icon(
                      onPressed: _addSkillEntry,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add another skill'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      final subId = _sectorSubOptionId;
                      if (subId == null || subId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Select sector and sub-option.')),
                        );
                        return;
                      }
                      if (_isAddMode) {
                        final toAdd = <Map<String, dynamic>>[];
                        for (final e in _entries) {
                          final title = e.titleController.text.trim();
                          if (title.isEmpty) continue;
                          toAdd.add({
                            'sectorSubOptionId': subId,
                            'title': title,
                            'description': e.descriptionController.text.trim(),
                          });
                        }
                        if (toAdd.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Add at least one skill with a title.')),
                          );
                          return;
                        }
                        final existing = await FirestoreService.skills().get();
                        final maxOrder = existing.docs.fold<int>(0, (m, d) {
                          final o = d.data()['order'];
                          if (o is num) return m > o.toInt() ? m : o.toInt();
                          return m;
                        });
                        for (var i = 0; i < toAdd.length; i++) {
                          toAdd[i]['order'] = maxOrder + 1 + i;
                        }
                        final batch = FirebaseFirestore.instance.batch();
                        for (final data in toAdd) {
                          batch.set(FirestoreService.skills().doc(), data);
                        }
                        await batch.commit();
                      } else {
                        final title = _entries.first.titleController.text.trim();
                        if (title.isEmpty) return;
                        await FirestoreService.skills().doc(widget.id).update({
                          'sectorSubOptionId': subId,
                          'title': title,
                          'description': _entries.first.descriptionController.text.trim(),
                        });
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text(_isAddMode ? 'Add all skills' : 'Save'),
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

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class SectorsScreen extends StatelessWidget {
  const SectorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sectors')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sectors'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.sectors().snapshots(),
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
            onReorder: (oldIndex, newIndex) => _reorderSectors(context, docs, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final id = docs[index].id;
              final name = d['name'] as String? ?? '—';
              final description = d['description'] as String? ?? '';
              return KeyedSubtree(
                key: ValueKey(id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.drag_handle, color: Colors.grey.shade500),
                  title: Text(name),
                  subtitle: description.isNotEmpty ? Text(description, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                  isThreeLine: description.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Move to position (currently ${index + 1})',
                        child: IconButton(
                          icon: const Icon(Icons.format_list_numbered, size: 20),
                          onPressed: () => _showMoveToPosition(context, docs, index, FirestoreService.sectors()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        onPressed: index > 0 ? () => _moveSector(context, docs, index, -1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 20),
                        onPressed: index < docs.length - 1 ? () => _moveSector(context, docs, index, 1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showForm(context, id: id, initialName: name, initialDescription: description),
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

  void _showForm(BuildContext context, {String? id, String initialName = '', String initialDescription = ''}) {
    final nameController = TextEditingController(text: initialName);
    final descriptionController = TextEditingController(text: initialDescription);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(id == null ? 'Add sector' : 'Edit sector', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final description = descriptionController.text.trim();
                    if (id == null) {
                      final existing = await FirestoreService.sectors().get();
                      final maxOrder = existing.docs.fold<int>(0, (m, d) {
                        final o = d.data()['order'];
                        if (o is num) return m > o.toInt() ? m : o.toInt();
                        return m;
                      });
                      await FirestoreService.sectors().add({'name': name, 'description': description, 'order': maxOrder + 1});
                    } else {
                      await FirestoreService.sectors().doc(id).update({'name': name, 'description': description});
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(id == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reorderSectors(BuildContext context, List docs, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final item = docs.removeAt(oldIndex);
    docs.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < docs.length; i++) {
      batch.update(FirestoreService.sectors().doc(docs[i].id), {'order': i});
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

  Future<void> _moveSector(BuildContext context, List docs, int index, int delta) async {
    final swapIndex = index + delta;
    if (swapIndex < 0 || swapIndex >= docs.length) return;
    final docA = docs[index];
    final docB = docs[swapIndex];
    final orderA = (docA.data()['order'] as num?)?.toInt() ?? index;
    final orderB = (docB.data()['order'] as num?)?.toInt() ?? swapIndex;
    await FirestoreService.sectors().doc(docA.id).update({'order': orderB});
    await FirestoreService.sectors().doc(docB.id).update({'order': orderA});
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sector?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await FirestoreService.sectors().doc(id).delete();
  }
}

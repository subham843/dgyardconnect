import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsKnowledgeScreen extends StatefulWidget {
  const AdminAiOsKnowledgeScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsKnowledgeScreen> createState() => _AdminAiOsKnowledgeScreenState();
}

class _AdminAiOsKnowledgeScreenState extends State<AdminAiOsKnowledgeScreen> {
  final _repo = BosRepository();
  List<BosKbDocument> _docs = [];
  bool _loading = true;
  bool _busy = false;
  String? _collection;

  static const _collections = [
    'cctv',
    'networking',
    'software',
    'website',
    'mobile_apps',
    'digital_marketing',
    'dgyard_services',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await _repo.listKbDocuments(collection: _collection);
    if (mounted) setState(() { _docs = docs; _loading = false; });
  }

  Future<void> _add() async {
    final title = TextEditingController();
    final body = TextEditingController();
    var collection = _collection ?? 'cctv';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('KB document'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: collection,
                  items: _collections
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setS(() => collection = v ?? 'general'),
                  decoration: const InputDecoration(labelText: 'Collection'),
                ),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                TextField(
                  controller: body,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Body',
                    hintText: 'Paste product / service knowledge…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      final id = await _repo.createKbDocument({
        'title': title.text.trim(),
        'body': body.text.trim(),
        'collection': collection,
        'is_active': true,
      });
      try {
        await _repo.reindexKb(documentId: id);
      } catch (_) {}
      _load();
    }
  }

  Future<void> _reindexAll() async {
    setState(() => _busy = true);
    try {
      final result = await _repo.reindexKb(all: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reindexed ${result['documents']} docs · ${result['chunks']} chunks',
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reindexOne(BosKbDocument doc) async {
    setState(() => _busy = true);
    try {
      await _repo.reindexKb(documentId: doc.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showChunks(BosKbDocument doc) async {
    final chunks = await _repo.listKbChunks(doc.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chunks · ${doc.title}'),
        content: SizedBox(
          width: 520,
          height: 400,
          child: chunks.isEmpty
              ? const Text('No chunks yet. Run Reindex.')
              : ListView.builder(
                  itemCount: chunks.length,
                  itemBuilder: (_, i) {
                    final c = chunks[i];
                    return ListTile(
                      dense: true,
                      title: Text('#${c['chunk_index']} · ${c['embedding_status']}'),
                      subtitle: Text(
                        '${c['content']}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Knowledge Base',
      embedded: widget.embedded,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'reindex',
            onPressed: _busy ? null : _reindexAll,
            icon: const Icon(Icons.sync),
            label: const Text('Reindex all'),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Document'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DropdownButton<String?>(
                  value: _collection,
                  hint: const Text('All collections'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._collections.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  ],
                  onChanged: (v) {
                    setState(() => _collection = v);
                    _load();
                  },
                ),
                const Spacer(),
                if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _docs.length,
                      itemBuilder: (_, i) {
                        final d = _docs[i];
                        return ListTile(
                          leading: const Icon(Icons.menu_book),
                          title: Text(d.title),
                          subtitle: Text(
                            '${d.collection} · ${d.reindexStatus} · ${d.chunkCount} chunks',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Chunks',
                                onPressed: () => _showChunks(d),
                                icon: const Icon(Icons.view_agenda_outlined),
                              ),
                              IconButton(
                                tooltip: 'Reindex',
                                onPressed: _busy ? null : () => _reindexOne(d),
                                icon: const Icon(Icons.sync),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () async {
                                  await _repo.softDeleteKbDocument(d.id);
                                  _load();
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          onTap: () => _showChunks(d),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsProjectsScreen extends StatefulWidget {
  const AdminAiOsProjectsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsProjectsScreen> createState() => _AdminAiOsProjectsScreenState();
}

class _AdminAiOsProjectsScreenState extends State<AdminAiOsProjectsScreen> {
  final _repo = BosRepository();
  List<BosProject> _items = [];
  List<BosDeal> _wonDeals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.listProjects();
    final deals = await _repo.listDeals();
    if (mounted) {
      setState(() {
        _items = items;
        _wonDeals = deals.where((d) => d.stage == 'won').toList();
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    String? dealId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('New project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              DropdownButtonFormField<String?>(
                initialValue: dealId,
                decoration: const InputDecoration(labelText: 'From won deal (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._wonDeals.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))),
                ],
                onChanged: (v) => setS(() => dealId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (dealId != null) {
        await _repo.createProjectFromDeal(dealId!);
      } else if (name.text.trim().isNotEmpty) {
        await _repo.createProject({'name': name.text.trim()});
      }
      _load();
    }
  }

  Future<void> _openDetail(BosProject p) async {
    final milestones = await _repo.listProjectMilestones(p.id);
    final tasks = await _repo.listProjectTasks(p.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(p.name),
          content: SizedBox(
            width: 520,
            height: 440,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Status: ${p.status}'),
                      const Spacer(),
                      DropdownButton<String>(
                        value: p.status ?? 'planning',
                        items: const [
                          DropdownMenuItem(value: 'planning', child: Text('Planning')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'on_hold', child: Text('On hold')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (s) async {
                          if (s == null) return;
                          await _repo.updateProjectStatus(p.id, s);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                      ),
                    ],
                  ),
                  const TabBar(tabs: [Tab(text: 'Milestones'), Tab(text: 'Tasks')]),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          children: [
                            ...milestones.map(
                              (m) => ListTile(
                                title: Text('${m['title']}'),
                                subtitle: Text('Due ${m['due_date'] ?? '—'}'),
                                trailing: m['completed_at'] != null
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : IconButton(
                                        icon: const Icon(Icons.check),
                                        onPressed: () async {
                                          await _repo.completeMilestone(m['id'] as String);
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          _openDetail(p);
                                        },
                                      ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _repo.addProjectMilestone(
                                  projectId: p.id,
                                  title: 'Milestone ${milestones.length + 1}',
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                _openDetail(p);
                              },
                              child: const Text('Add milestone'),
                            ),
                          ],
                        ),
                        ListView(
                          children: [
                            ...tasks.map(
                              (t) => ListTile(
                                title: Text('${t['title']}'),
                                subtitle: Text('${t['status']}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (s) async {
                                    await _repo.updateTaskStatus(t['id'] as String, s);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _openDetail(p);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'todo', child: Text('Todo')),
                                    PopupMenuItem(value: 'doing', child: Text('Doing')),
                                    PopupMenuItem(value: 'done', child: Text('Done')),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _repo.addProjectTask(
                                  projectId: p.id,
                                  title: 'Task ${tasks.length + 1}',
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                _openDetail(p);
                              },
                              child: const Text('Add task'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Projects',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Project'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final p = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.engineering),
                    title: Text(p.name),
                    subtitle: Text(p.status ?? 'planning'),
                    onTap: () => _openDetail(p),
                  );
                },
              ),
            ),
    );
  }
}

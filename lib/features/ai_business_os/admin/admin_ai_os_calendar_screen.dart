import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

/// CRM tasks / calendar agenda (due activities + lead follow-ups).
class AdminAiOsCalendarScreen extends StatefulWidget {
  const AdminAiOsCalendarScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsCalendarScreen> createState() => _AdminAiOsCalendarScreenState();
}

class _AdminAiOsCalendarScreenState extends State<AdminAiOsCalendarScreen> {
  final _repo = BosRepository();
  List<BosActivity> _tasks = [];
  List<BosLead> _overdue = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tasks = await _repo.listDueTasks();
    final overdue = await _repo.listLeadsOverdueFollowUp();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _overdue = overdue;
        _loading = false;
      });
    }
  }

  Future<void> _addTask() async {
    final subject = TextEditingController(text: 'Follow up');
    final days = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
            TextField(
              controller: days,
              decoration: const InputDecoration(labelText: 'Due in days'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true) {
      final d = int.tryParse(days.text.trim()) ?? 1;
      await _repo.addActivity(
        activityType: 'task',
        subject: subject.text.trim(),
        dueAt: DateTime.now().add(Duration(days: d)),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Tasks & Calendar',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add_task),
        label: const Text('Task'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Due tasks', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_tasks.isEmpty)
                    const Text('No scheduled tasks')
                  else
                    ..._tasks.map((t) {
                      final due = t.dueAt;
                      final overdue = due != null && due.isBefore(DateTime.now()) && t.completedAt == null;
                      return ListTile(
                        leading: Icon(
                          t.completedAt != null ? Icons.check_circle : Icons.event,
                          color: t.completedAt != null
                              ? Colors.green
                              : (overdue ? Colors.red : Colors.blueGrey),
                        ),
                        title: Text(t.subject ?? t.activityType),
                        subtitle: Text(
                          '${t.activityType} · due ${due?.toLocal().toString().substring(0, 16) ?? '-'}'
                          '${t.completedAt != null ? ' · done' : ''}',
                        ),
                        trailing: t.completedAt == null
                            ? IconButton(
                                tooltip: 'Complete',
                                icon: const Icon(Icons.done),
                                onPressed: () async {
                                  await _repo.completeActivity(t.id);
                                  _load();
                                },
                              )
                            : null,
                      );
                    }),
                  const SizedBox(height: 24),
                  Text('Overdue lead follow-ups', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_overdue.isEmpty)
                    const Text('None overdue')
                  else
                    ..._overdue.map(
                      (l) => ListTile(
                        leading: const Icon(Icons.warning_amber, color: Colors.orange),
                        title: Text(l.displayName),
                        subtitle: Text(
                          'Follow-up ${l.nextFollowUpAt?.toLocal().toString().substring(0, 16) ?? ''}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';

const _ticketStatuses = [
  ('open', 'Open'),
  ('in_progress', 'In progress'),
  ('waiting', 'Waiting'),
  ('resolved', 'Resolved'),
  ('closed', 'Closed'),
];

class AdminAiOsTicketsScreen extends StatefulWidget {
  const AdminAiOsTicketsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsTicketsScreen> createState() => _AdminAiOsTicketsScreenState();
}

class _AdminAiOsTicketsScreenState extends State<AdminAiOsTicketsScreen> {
  final _repo = BosRepository();
  List<BosTicket> _items = [];
  List<BosProject> _projects = [];
  List<BosTenantMember> _members = [];
  bool _loading = true;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tid = await _repo.activeTenantId;
    final items = await _repo.listTickets();
    final projects = await _repo.listProjects();
    final members = await _repo.listMembers(tid);
    if (mounted) {
      setState(() {
        _items = _filterStatus == null
            ? items
            : items.where((t) => t.status == _filterStatus).toList();
        _projects = projects;
        _members = members;
        _loading = false;
      });
    }
  }

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permission denied')),
    );
  }

  Future<void> _add() async {
    if (!BosPermissions.canCreate) return _denied();
    final subject = TextEditingController();
    final desc = TextEditingController();
    var priority = 'medium';
    var slaHours = 24;
    String? projectId;
    String? assignee;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('New ticket'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
                  TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (v) => setS(() => priority = v ?? 'medium'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: slaHours,
                    decoration: const InputDecoration(labelText: 'SLA hours'),
                    items: const [
                      DropdownMenuItem(value: 4, child: Text('4h')),
                      DropdownMenuItem(value: 24, child: Text('24h')),
                      DropdownMenuItem(value: 48, child: Text('48h')),
                      DropdownMenuItem(value: 72, child: Text('72h')),
                    ],
                    onChanged: (v) => setS(() => slaHours = v ?? 24),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: projectId,
                    decoration: const InputDecoration(labelText: 'Project'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (v) => setS(() => projectId = v),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: assignee,
                    decoration: const InputDecoration(labelText: 'Assignee'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Unassigned')),
                      ..._members.map(
                        (m) => DropdownMenuItem(
                          value: m.firebaseUid,
                          child: Text(m.displayName ?? m.firebaseUid),
                        ),
                      ),
                    ],
                    onChanged: (v) => setS(() => assignee = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok == true && subject.text.trim().isNotEmpty) {
      await _repo.createTicketFull(
        subject: subject.text.trim(),
        description: desc.text.trim(),
        priority: priority,
        projectId: projectId,
        assigneeFirebaseUid: assignee,
        slaHours: slaHours,
      );
      await _repo.writeAuditLog(action: 'ticket.create', entityType: 'bos_tickets');
      _load();
    }
  }

  Future<void> _open(BosTicket t) async {
    var ticket = t;
    var comments = await _repo.listTicketComments(ticket.id);
    final commentCtrl = TextEditingController();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(ticket.subject),
          content: SizedBox(
            width: 480,
            height: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ticket.priority} · ${ticket.status}'),
                if (ticket.description != null) Text(ticket.description!),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _ticketStatuses.map((s) {
                    final selected = ticket.status == s.$1;
                    return ChoiceChip(
                      label: Text(s.$2),
                      selected: selected,
                      onSelected: BosPermissions.canEdit
                          ? (_) async {
                              await _repo.updateTicketStatus(ticket.id, s.$1);
                              final refreshed = await _repo.listTickets();
                              final match = refreshed.where((x) => x.id == ticket.id);
                              if (match.isNotEmpty) {
                                ticket = match.first;
                              } else {
                                ticket = BosTicket(
                                  id: ticket.id,
                                  tenantId: ticket.tenantId,
                                  subject: ticket.subject,
                                  createdAt: ticket.createdAt,
                                  description: ticket.description,
                                  status: s.$1,
                                  priority: ticket.priority,
                                  projectId: ticket.projectId,
                                  contactId: ticket.contactId,
                                  assigneeFirebaseUid: ticket.assigneeFirebaseUid,
                                );
                              }
                              setS(() {});
                              _load();
                            }
                          : null,
                    );
                  }).toList(),
                ),
                const Divider(),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView(
                    children: comments.isEmpty
                        ? [const ListTile(dense: true, title: Text('No comments yet'))]
                        : comments
                            .map(
                              (cm) => ListTile(
                                dense: true,
                                title: Text('${cm['body']}'),
                                subtitle: Text('${cm['created_at'] ?? ''}'),
                              ),
                            )
                            .toList(),
                  ),
                ),
                if (BosPermissions.canEdit)
                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(hintText: 'Add comment'),
                  ),
              ],
            ),
          ),
          actions: [
            if (BosPermissions.canEdit)
              TextButton(
                onPressed: () async {
                  if (commentCtrl.text.trim().isEmpty) return;
                  await _repo.addTicketComment(ticket.id, commentCtrl.text.trim());
                  await _repo.writeAuditLog(
                    action: 'ticket.comment',
                    entityType: 'bos_tickets',
                    entityId: ticket.id,
                  );
                  comments = await _repo.listTicketComments(ticket.id);
                  commentCtrl.clear();
                  setS(() {});
                },
                child: const Text('Post'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Service & Tickets',
      embedded: widget.embedded,
      floatingActionButton: BosPermissions.canCreate
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Ticket'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButton<String?>(
              value: _filterStatus,
              hint: const Text('Filter status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ..._ticketStatuses.map(
                  (s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                ),
              ],
              onChanged: (v) {
                setState(() => _filterStatus = v);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final t = _items[i];
                        return ListTile(
                          leading: const Icon(Icons.confirmation_number),
                          title: Text(t.subject),
                          subtitle: Text('${t.priority} · ${t.status}'),
                          onTap: () => _open(t),
                          trailing: BosPermissions.canEdit
                              ? PopupMenuButton<String>(
                                  onSelected: (s) async {
                                    await _repo.updateTicketStatus(t.id, s);
                                    _load();
                                  },
                                  itemBuilder: (_) => _ticketStatuses
                                      .map(
                                        (s) => PopupMenuItem(value: s.$1, child: Text(s.$2)),
                                      )
                                      .toList(),
                                )
                              : Text(t.status ?? ''),
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

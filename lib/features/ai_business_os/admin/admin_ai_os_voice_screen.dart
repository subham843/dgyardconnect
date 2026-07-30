import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';

const _outcomes = [
  ('interested', 'Interested'),
  ('callback', 'Callback'),
  ('not_interested', 'Not interested'),
  ('no_answer', 'No answer'),
];

class AdminAiOsVoiceScreen extends StatefulWidget {
  const AdminAiOsVoiceScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsVoiceScreen> createState() => _AdminAiOsVoiceScreenState();
}

class _AdminAiOsVoiceScreenState extends State<AdminAiOsVoiceScreen> {
  final _repo = BosRepository();
  List<BosVoiceCall> _items = [];
  List<BosLead> _leads = [];
  bool _loading = true;
  bool _dueOnly = false;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.listVoiceCalls(
      status: _statusFilter,
      dueOnly: _dueOnly,
    );
    final leads = await _repo.listLeads();
    if (mounted) {
      setState(() {
        _items = items;
        _leads = leads;
        _loading = false;
      });
    }
  }

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permission denied')),
    );
  }

  Future<void> _queue() async {
    if (!BosPermissions.canCreate) return _denied();
    final phone = TextEditingController();
    final script = TextEditingController(
      text: 'Hi, this is DG.YARD. Calling regarding your enquiry. Are you available for a quick survey?',
    );
    String? leadId;
    var generating = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Queue AI voice call'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: script, maxLines: 4, decoration: const InputDecoration(labelText: 'Script')),
                DropdownButtonFormField<String?>(
                  initialValue: leadId,
                  decoration: const InputDecoration(labelText: 'Link lead'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._leads.map((l) => DropdownMenuItem(value: l.id, child: Text(l.displayName))),
                  ],
                  onChanged: (v) {
                    setS(() {
                      leadId = v;
                      if (v != null) {
                        final lead = _leads.firstWhere((e) => e.id == v);
                        if ((lead.phone ?? '').isNotEmpty) phone.text = lead.phone!;
                      }
                    });
                  },
                ),
                if (leadId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: generating
                          ? null
                          : () async {
                              setS(() => generating = true);
                              try {
                                script.text = await _repo.generateVoiceScript(leadId!);
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              } finally {
                                setS(() => generating = false);
                              }
                            },
                      icon: generating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome),
                      label: const Text('AI script'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Queue')),
          ],
        ),
      ),
    );
    if (ok == true && phone.text.trim().isNotEmpty) {
      try {
        if (leadId != null) {
          await _repo.queueFollowUpCall(
            leadId: leadId!,
            phone: phone.text.trim(),
            generateScript: false,
            scriptOverride: script.text.trim(),
            scheduledAt: DateTime.now(),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Call queued — dialing if due')),
            );
          }
        } else {
          final callId = await _repo.createVoiceCall({
            'phone': phone.text.trim(),
            'status': 'queued',
            'direction': 'outbound',
            'provider': 'exotel',
            'script': script.text.trim(),
            'scheduled_at': DateTime.now().toIso8601String(),
          });
          final dial = await _repo.dialVoiceCall(callId);
          if (mounted) {
            final sim = dial['sim'] == true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sim
                      ? 'Queued (stub dial — set Exotel secrets for live)'
                      : 'Dialing via ${dial['provider'] ?? 'exotel'}…',
                ),
              ),
            );
          }
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _dial(BosVoiceCall call) async {
    if (!BosPermissions.canEdit) return _denied();
    try {
      final dial = await _repo.dialVoiceCall(call.id);
      if (mounted) {
        final sim = dial['sim'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sim
                  ? 'Stub dial — set voice provider + Exotel secrets in Settings'
                  : 'Live dial started (${dial['provider'] ?? 'exotel'})',
            ),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _complete(BosVoiceCall call) async {
    if (!BosPermissions.canEdit) return _denied();
    var outcome = 'interested';
    DateTime? followUp = DateTime.now().add(const Duration(days: 1));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Complete call (simulate)'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (call.script != null && call.script!.isNotEmpty) ...[
                  const Text('Script', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(call.script!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  items: _outcomes
                      .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                      .toList(),
                  onChanged: (v) => setS(() => outcome = v ?? outcome),
                ),
                if (outcome == 'callback' || outcome == 'no_answer') ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: followUp ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (d != null) setS(() => followUp = d);
                    },
                    child: Text(
                      'Next follow-up: ${followUp?.toLocal().toString().substring(0, 10) ?? 'pick date'}',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final result = await _repo.completeVoiceCall(
        call.id,
        outcome: outcome,
        nextFollowUpAt: (outcome == 'callback' || outcome == 'no_answer') ? followUp : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Completed · ${result['outcome']}')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'AI Voice',
      embedded: widget.embedded,
      floatingActionButton: BosPermissions.canCreate
          ? FloatingActionButton.extended(
              onPressed: _queue,
              icon: const Icon(Icons.phone),
              label: const Text('Queue call'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Due / queued'),
                  selected: _dueOnly,
                  onSelected: (v) {
                    setState(() => _dueOnly = v);
                    _load();
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: _statusFilter,
                  hint: const Text('Status'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'queued', child: Text('Queued')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No voice calls yet')),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final c = _items[i];
                              final sched = c.scheduledAt != null
                                  ? c.scheduledAt!.toLocal().toString().substring(0, 16)
                                  : null;
                              return ListTile(
                                leading: const Icon(Icons.phone_in_talk),
                                title: Text(c.phone ?? 'Unknown'),
                                subtitle: Text(
                                  '${c.status}'
                                  '${c.outcome != null ? ' · ${c.outcome}' : ''}'
                                  '${sched != null ? ' · due $sched' : ''}'
                                  '${c.script != null ? ' · has script' : ''}',
                                ),
                                trailing: c.isOpen
                                    ? Wrap(
                                        spacing: 6,
                                        children: [
                                          if (c.status == 'queued')
                                            OutlinedButton(
                                              onPressed: () => _dial(c),
                                              child: const Text('Dial'),
                                            ),
                                          FilledButton.tonal(
                                            onPressed: () => _complete(c),
                                            child: const Text('Complete'),
                                          ),
                                        ],
                                      )
                                    : null,
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(c.phone ?? 'Call'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Status: ${c.status}'),
                                          if (c.outcome != null) Text('Outcome: ${c.outcome}'),
                                          if (sched != null) Text('Scheduled: $sched'),
                                          if (c.script != null) ...[
                                            const SizedBox(height: 8),
                                            const Text('Script', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text(c.script!),
                                          ],
                                          if (c.transcript != null) ...[
                                            const SizedBox(height: 8),
                                            const Text('Transcript', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text(c.transcript!),
                                          ],
                                          if (c.aiSummary != null) ...[
                                            const SizedBox(height: 8),
                                            const Text('AI summary', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text(c.aiSummary!),
                                          ],
                                          if (c.nextAction != null) Text('Next action: ${c.nextAction}'),
                                          Text(
                                            'Provider: ${c.meta?['voice_provider'] ?? c.meta?['provider_note'] ?? 'stub'}',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                                    ],
                                  ),
                                ),
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

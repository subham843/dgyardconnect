import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';
import 'bos_audio_play_stub.dart'
    if (dart.library.html) 'bos_audio_play_web.dart';

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
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _dueOnly = false;
  bool _hideStub = false;
  String? _statusFilter;
  String _activeProvider = 'stub';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _repo.reconcilePendingVoiceCompletions();
    } catch (_) {}
    final items = await _repo.listVoiceCalls(
      status: _statusFilter,
      dueOnly: _dueOnly,
      hideStub: _hideStub,
    );
    final leads = await _repo.listLeads();
    final events = await _repo.listVoiceEvents(limit: 80);
    String provider = 'stub';
    try {
      provider = await _repo.resolveActiveVoiceProvider();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _items = items;
        _leads = leads;
        _events = events;
        _activeProvider = provider;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _eventsFor(String callId) {
    final list = _events.where((e) => '${e['call_id']}' == callId).toList();
    list.sort((a, b) {
      final ta = DateTime.tryParse('${a['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse('${b['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return list;
  }

  String _eventStripFor(String callId) {
    final related = _eventsFor(callId).map((e) => '${e['event_type'] ?? '?'}').toList();
    if (related.isEmpty) return '';
    return related.join(' → ');
  }

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permission denied')),
    );
  }

  Future<void> _previewScript(String script) async {
    try {
      final r = await _repo.previewVoiceTts(text: script);
      if (!mounted) return;
      if (r['sim'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r['note'] ?? 'Set Sarvam key for live TTS'}')),
        );
        return;
      }
      final b64 = r['audio_base64']?.toString();
      if (b64 == null || b64.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No TTS audio')),
        );
        return;
      }
      playBase64Audio(b64, contentType: '${r['content_type'] ?? 'audio/wav'}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _softDelete(BosVoiceCall call) async {
    if (!BosPermissions.canEdit) return _denied();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hide call?'),
        content: Text('Soft-delete ${call.phone ?? call.id} from the list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hide')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.softDeleteVoiceCall(call.id);
    _load();
  }

  Future<void> _queue() async {
    if (!BosPermissions.canCreate) return _denied();
    final phone = TextEditingController();
    final script = TextEditingController(
      text: 'Hi, this is DG.YARD. Calling regarding your enquiry. Are you available for a quick survey?',
    );
    String? leadId;
    var generating = false;
    var previewing = false;

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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (leadId != null)
                        TextButton.icon(
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
                      TextButton.icon(
                        onPressed: previewing || script.text.trim().isEmpty
                            ? null
                            : () async {
                                setS(() => previewing = true);
                                try {
                                  await _previewScript(script.text.trim());
                                } finally {
                                  setS(() => previewing = false);
                                }
                              },
                        icon: previewing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.record_voice_over),
                        label: const Text('Preview TTS'),
                      ),
                    ],
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
          final voiceProvider = await _repo.resolveActiveVoiceProvider();
          final callId = await _repo.createVoiceCall({
            'phone': phone.text.trim(),
            'status': 'queued',
            'direction': 'outbound',
            'provider': voiceProvider,
            'script': script.text.trim(),
            'scheduled_at': DateTime.now().toIso8601String(),
            'meta': {'voice_provider': voiceProvider},
          });
          final dial = await _repo.dialVoiceCall(callId);
          if (mounted) {
            final sim = dial['sim'] == true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sim
                      ? 'Queued (stub — set $voiceProvider secrets in Settings)'
                      : 'Dialing via ${dial['provider'] ?? voiceProvider}…',
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
                  ? 'Stub dial — set ${call.voiceProviderLabel} secrets in Settings'
                  : 'Live dial started (${dial['provider'] ?? call.voiceProviderLabel})',
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
    final audioCtrl = TextEditingController(text: call.recordingUrl ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Complete call'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${call.voiceProviderLabel}${call.dialSim ? ' · stub' : ' · live'}'
                  '${call.sttProvider != null ? ' · STT ${call.sttProvider}' : ''}'
                  '${call.isInbound ? ' · inbound' : ''}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                if (call.script != null && call.script!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Script', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _previewScript(call.script!),
                        child: const Text('Preview TTS'),
                      ),
                    ],
                  ),
                  Text(call.script!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: audioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Recording / audio URL (Sarvam STT)',
                    hintText: 'https://…',
                  ),
                ),
                const SizedBox(height: 8),
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
        audioUrl: audioCtrl.text.trim().isEmpty ? null : audioCtrl.text.trim(),
        nextFollowUpAt: (outcome == 'callback' || outcome == 'no_answer') ? followUp : null,
      );
      if (mounted) {
        final stt = result['stt_sim'] == true ? 'STT sim' : 'STT live';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Completed · ${result['outcome']} · $stt')),
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
          Material(
            color: Colors.teal.shade50,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.settings_phone, size: 20),
              title: Text('Active provider: $_activeProvider'),
              subtitle: Text(
                _activeProvider == 'telnyx'
                    ? 'Telnyx: speak-on-answer + record → STT via webhook'
                    : _activeProvider == 'stub'
                        ? 'Stub mode — set live provider in Settings'
                        : 'Live dial when secrets are set in Settings',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: _load,
                child: const Text('Refresh'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Due / queued'),
                  selected: _dueOnly,
                  onSelected: (v) {
                    setState(() => _dueOnly = v);
                    _load();
                  },
                ),
                FilterChip(
                  label: const Text('Hide stub'),
                  selected: _hideStub,
                  onSelected: (v) {
                    setState(() => _hideStub = v);
                    _load();
                  },
                ),
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
          if (_events.isNotEmpty)
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _events.length.clamp(0, 12),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = _events[i];
                  final t = '${e['event_type'] ?? 'event'}';
                  final p = '${e['provider'] ?? ''}';
                  final at = e['created_at']?.toString();
                  final short = at != null && at.length >= 16 ? at.substring(11, 16) : '';
                  return Chip(
                    avatar: Icon(
                      t.contains('inbound') || t.contains('missed')
                          ? Icons.call_received
                          : Icons.webhook,
                      size: 16,
                    ),
                    label: Text('$t${p.isNotEmpty ? ' · $p' : ''}${' · $short'}'),
                  );
                },
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
                                leading: Icon(
                                  c.isInbound
                                      ? Icons.call_received
                                      : (c.dialSim ? Icons.phone_paused : Icons.phone_in_talk),
                                  color: c.isInbound
                                      ? Colors.indigo
                                      : (c.dialSim ? Colors.orange : Colors.teal),
                                ),
                                title: Text(c.phone ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${c.status}'
                                      '${c.isInbound ? ' · inbound' : ''}'
                                      ' · ${c.voiceProviderLabel}${c.dialSim ? ' (stub)' : ' (live)'}'
                                      '${c.sttProvider != null ? ' · ${c.sttProvider}' : ''}'
                                      '${c.durationSec != null ? ' · ${c.durationSec}s' : ''}'
                                      '${c.outcome != null ? ' · ${c.outcome}' : ''}'
                                      '${sched != null ? ' · due $sched' : ''}',
                                    ),
                                    if (_eventStripFor(c.id).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          _eventStripFor(c.id),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.teal.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: _eventStripFor(c.id).isNotEmpty,
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    if (c.isOpen) ...[
                                      if (c.status == 'queued' || c.status == 'ringing')
                                        OutlinedButton(
                                          onPressed: () => _dial(c),
                                          child: Text(c.status == 'queued' ? 'Dial' : 'Re-dial'),
                                        ),
                                      FilledButton.tonal(
                                        onPressed: () => _complete(c),
                                        child: const Text('Complete'),
                                      ),
                                    ],
                                    IconButton(
                                      tooltip: 'Hide',
                                      onPressed: () => _softDelete(c),
                                      icon: const Icon(Icons.visibility_off_outlined, size: 20),
                                    ),
                                  ],
                                ),
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(c.phone ?? 'Call'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Status: ${c.status}'),
                                          Text(
                                            'Provider: ${c.voiceProviderLabel}'
                                            '${c.dialSim ? ' · stub dial' : ' · live'}'
                                            '${c.isInbound ? ' · inbound' : ''}',
                                          ),
                                          if (c.sttProvider != null) Text('STT: ${c.sttProvider}'),
                                          if (c.providerCallId != null)
                                            Text('Provider call ID: ${c.providerCallId}'),
                                          if (c.recordingUrl != null) Text('Recording: ${c.recordingUrl}'),
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
                                          if (_eventsFor(c.id).isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            const Text('Event timeline', style: TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            ..._eventsFor(c.id).map((e) {
                                              final at = e['created_at']?.toString();
                                              final short = at != null && at.length >= 19
                                                  ? at.substring(0, 19).replaceFirst('T', ' ')
                                                  : (at ?? '');
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 4),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.circle,
                                                      size: 8,
                                                      color: Colors.teal.shade700,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${e['event_type'] ?? 'event'}'
                                                        '${e['provider'] != null ? ' · ${e['provider']}' : ''}'
                                                        '${short.isNotEmpty ? ' · $short' : ''}',
                                                        style: const TextStyle(fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      if (c.script != null && c.script!.isNotEmpty)
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _previewScript(c.script!);
                                          },
                                          child: const Text('Preview TTS'),
                                        ),
                                      if (c.isOpen)
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _dial(c);
                                          },
                                          child: const Text('Re-dial'),
                                        ),
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

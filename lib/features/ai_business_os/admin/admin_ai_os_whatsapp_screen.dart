import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';

class AdminAiOsWhatsappScreen extends StatefulWidget {
  const AdminAiOsWhatsappScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsWhatsappScreen> createState() => _AdminAiOsWhatsappScreenState();
}

class _AdminAiOsWhatsappScreenState extends State<AdminAiOsWhatsappScreen> {
  final _repo = BosRepository();
  List<BosConversation> _conversations = [];
  Map<String, BosLead> _leadsById = {};
  BosConversation? _selected;
  List<BosMessage> _messages = [];
  bool _loading = true;
  bool _busy = false;
  String _channelFilter = 'all';
  bool _hotOnly = false;
  final _composer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var conversations = await _repo.listConversations(
      channel: _channelFilter == 'all' ? null : _channelFilter,
    );
    final leads = await _repo.listLeads();
    final byId = <String, BosLead>{for (final l in leads) l.id: l};
    if (_hotOnly) {
      conversations = conversations.where((c) {
        final lead = c.leadId == null ? null : byId[c.leadId];
        return lead != null && (lead.score == 'hot' || lead.handoverReady);
      }).toList();
    }
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _leadsById = byId;
      _loading = false;
      if (_selected != null) {
        final match = conversations.where((c) => c.id == _selected!.id);
        _selected = match.isEmpty ? null : match.first;
      }
    });
    if (_selected != null) await _loadMessages(_selected!.id);
  }

  Future<void> _loadMessages(String conversationId) async {
    final messages = await _repo.listMessages(conversationId);
    if (mounted) setState(() => _messages = messages);
  }

  Future<void> _open(BosConversation conv) async {
    setState(() {
      _selected = conv;
      _messages = [];
    });
    await _loadMessages(conv.id);
  }

  Future<void> _addConversation() async {
    final phone = TextEditingController();
    var channel = 'whatsapp';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('New conversation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: channel,
                decoration: const InputDecoration(labelText: 'Channel'),
                items: const [
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  DropdownMenuItem(value: 'web', child: Text('Web')),
                  DropdownMenuItem(value: 'app', child: Text('App')),
                  DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                  DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
                ],
                onChanged: (v) => setS(() => channel = v ?? 'whatsapp'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone / visitor id'),
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
    if (ok == true && phone.text.trim().isNotEmpty) {
      final id = await _repo.createConversation({
        'phone': phone.text.trim(),
        'channel': channel,
        'status': 'open',
        'ai_enabled': true,
        if (channel != 'whatsapp') 'external_id': '${channel}:${phone.text.trim()}',
      });
      await _load();
      final created = _conversations.where((c) => c.id == id);
      if (created.isNotEmpty) await _open(created.first);
    }
  }

  Future<void> _simulateInbound() async {
    final phone = TextEditingController(text: _selected?.phone ?? '');
    final body = TextEditingController(text: 'Hi, I need CCTV quotation for my shop');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simulate inbound WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ingest')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.ingestTestWhatsapp(phone: phone.text.trim(), body: body.text.trim());
      await _load();
    }
  }

  Future<void> _simulateWebChat() async {
    final msg = TextEditingController(text: 'Price kitna hoga 8 camera ke liye?');
    final name = TextEditingController(text: 'Web Visitor');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simulate web chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: msg, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.ingestChatMessage(
        message: msg.text.trim(),
        channel: 'web',
        name: name.text.trim(),
        visitorId: 'admin-sim-${DateTime.now().millisecondsSinceEpoch}',
      );
      setState(() => _channelFilter = 'web');
      await _load();
    }
  }

  Future<void> _send() async {
    final conv = _selected;
    final text = _composer.text.trim();
    if (conv == null || text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _repo.sendMessage(conversationId: conv.id, body: text);
      _composer.clear();
      await _loadMessages(conv.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _aiReply() async {
    final conv = _selected;
    if (conv == null) return;
    setState(() => _busy = true);
    try {
      final result = await _repo.aiReplyConversation(conv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI · ${result['intent'] ?? '?'} · '
              '${result['sent'] == true ? 'sent' : result['status'] ?? 'saved'}'
              '${(result['citations'] is List && (result['citations'] as List).isNotEmpty) ? ' · ${(result['citations'] as List).length} sources' : ''}',
            ),
          ),
        );
      }
      await _loadMessages(conv.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _queueVoiceCall() async {
    final conv = _selected;
    if (conv == null) return;
    if (!BosPermissions.canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied')),
      );
      return;
    }
    var phone = (conv.phone ?? '').trim();
    var leadId = conv.leadId;
    if (leadId != null) {
      try {
        final leads = await _repo.listLeads();
        BosLead? lead;
        for (final l in leads) {
          if (l.id == leadId) {
            lead = l;
            break;
          }
        }
        if (lead != null) {
          if (lead.doNotCall) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lead is Do not call — clear it on the lead first'),
                ),
              );
            }
            return;
          }
          if (phone.isEmpty && (lead.phone ?? '').isNotEmpty) {
            phone = lead.phone!.trim();
          }
        }
      } catch (_) {}
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone on conversation — set phone or link a lead')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (leadId == null) {
        leadId = await _repo.createLead({
          'full_name': _titleFor(conv),
          'phone': phone,
          'source': 'inbox_${conv.channel ?? 'chat'}',
          'stage': 'new',
          'score': 'warm',
        });
        await _repo.linkConversationLead(conv.id, leadId);
      }
      await _repo.queueFollowUpCall(
        leadId: leadId,
        phone: phone,
        generateScript: true,
        scheduledAt: DateTime.now(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI call queued — open Voice or tap Run due')),
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

  String _titleFor(BosConversation c) {
    if (c.phone != null && c.phone!.isNotEmpty) return c.phone!;
    return c.channel ?? 'Chat';
  }

  BosLead? _leadFor(BosConversation c) {
    final id = c.leadId;
    if (id == null) return null;
    return _leadsById[id];
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Inbox (AI Chat)',
      embedded: widget.embedded,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'web',
            onPressed: _simulateWebChat,
            icon: const Icon(Icons.language),
            label: const Text('Web chat'),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.extended(
            heroTag: 'sim',
            onPressed: _simulateInbound,
            icon: const Icon(Icons.move_to_inbox),
            label: const Text('WA inbound'),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _addConversation,
            icon: const Icon(Icons.add),
            label: const Text('Conversation'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      for (final f in const [
                        ('all', 'All'),
                        ('whatsapp', 'WhatsApp'),
                        ('web', 'Web'),
                        ('app', 'App'),
                        ('social', 'Social'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.$2),
                            selected: _channelFilter == f.$1,
                            onSelected: (_) {
                              setState(() => _channelFilter = f.$1);
                              _load();
                            },
                          ),
                        ),
                      FilterChip(
                        label: const Text('Hot / handover'),
                        avatar: const Icon(Icons.local_fire_department, size: 18),
                        selected: _hotOnly,
                        onSelected: (v) {
                          setState(() => _hotOnly = v);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _conversations.length,
                            itemBuilder: (_, i) {
                              final c = _conversations[i];
                              final selected = _selected?.id == c.id;
                              final lead = _leadFor(c);
                              final hot = lead?.score == 'hot';
                              final handover = lead?.handoverReady == true;
                              return ListTile(
                                selected: selected,
                                leading: Badge(
                                  isLabelVisible: c.unreadCount > 0,
                                  label: Text('${c.unreadCount}'),
                                  child: Icon(_channelIcon(c.channel)),
                                ),
                                title: Text(_titleFor(c)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${c.channel ?? 'whatsapp'} · ${c.status ?? 'open'}'),
                                    if (hot || handover)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Wrap(
                                          spacing: 4,
                                          children: [
                                            if (hot)
                                              Chip(
                                                label: const Text('HOT'),
                                                visualDensity: VisualDensity.compact,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize.shrinkWrap,
                                                padding: EdgeInsets.zero,
                                                labelStyle: const TextStyle(fontSize: 10),
                                                backgroundColor: Colors.red.shade50,
                                              ),
                                            if (handover)
                                              Chip(
                                                label: const Text('Handover'),
                                                visualDensity: VisualDensity.compact,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize.shrinkWrap,
                                                padding: EdgeInsets.zero,
                                                labelStyle: const TextStyle(fontSize: 10),
                                                backgroundColor: Colors.amber.shade50,
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: hot || handover,
                                onTap: () => _open(c),
                              );
                            },
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _selected == null
                            ? const Center(child: Text('Select a conversation'))
                            : Column(
                                children: [
                                  ListTile(
                                    title: Text(_titleFor(_selected!)),
                                    subtitle: Text(
                                      '${_selected!.channel ?? 'whatsapp'} · AI ${_selected!.aiEnabled ? 'on' : 'off'}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _busy ? null : _queueVoiceCall,
                                          icon: const Icon(Icons.phone_forwarded, size: 18),
                                          label: const Text('Queue AI call'),
                                        ),
                                        FilledButton.tonalIcon(
                                          onPressed: _busy ? null : _aiReply,
                                          icon: const Icon(Icons.psychology),
                                          label: const Text('AI reply'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: _messages.length,
                                      itemBuilder: (_, i) {
                                        final m = _messages[i];
                                        final outbound = m.direction == 'outbound';
                                        final cites = m.citations;
                                        return Align(
                                          alignment: outbound
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            padding: const EdgeInsets.all(10),
                                            constraints: const BoxConstraints(maxWidth: 420),
                                            decoration: BoxDecoration(
                                              color: outbound
                                                  ? const Color(0xFFDCF8C6)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(m.body ?? ''),
                                                if (cites.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Sources',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  ...cites.take(3).map(
                                                    (c) => Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        '• ${c['title'] ?? 'KB'}: ${c['excerpt'] ?? ''}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _composer,
                                            decoration: const InputDecoration(
                                              hintText: 'Type a message…',
                                              border: OutlineInputBorder(),
                                            ),
                                            onSubmitted: (_) => _send(),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filled(
                                          onPressed: _busy ? null : _send,
                                          icon: const Icon(Icons.send),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  IconData _channelIcon(String? channel) {
    switch (channel) {
      case 'web':
        return Icons.language;
      case 'app':
        return Icons.phone_android;
      case 'facebook':
      case 'instagram':
        return Icons.share;
      default:
        return Icons.chat_bubble;
    }
  }
}

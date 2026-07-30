import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsCampaignsScreen extends StatefulWidget {
  const AdminAiOsCampaignsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsCampaignsScreen> createState() => _AdminAiOsCampaignsScreenState();
}

class _AdminAiOsCampaignsScreenState extends State<AdminAiOsCampaignsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = BosRepository();
  late TabController _tabs;
  List<BosCampaign> _campaigns = [];
  List<BosWaTemplate> _templates = [];
  List<Map<String, dynamic>> _optOuts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final campaigns = await _repo.listCampaigns();
    final templates = await _repo.listWaTemplates();
    final optOuts = await _repo.listOptOuts();
    if (mounted) {
      setState(() {
        _campaigns = campaigns;
        _templates = templates;
        _optOuts = optOuts;
        _loading = false;
      });
    }
  }

  Future<void> _createCampaign() async {
    final name = TextEditingController();
    final csv = TextEditingController(
      text: 'phone,full_name,email\n919876543210,Sample Lead,lead@example.com',
    );
    final message = TextEditingController(
      text: 'Hi {{name}}, thanks for your interest in DG.YARD. Reply YES for a free survey.',
    );
    final brief = TextEditingController(text: 'AMC offer for CCTV customers');
    String? templateId;
    var triggerVoice = false;
    var channel = 'whatsapp';
    var audience = 'csv';
    var segment = 'new_leads';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('New campaign'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Campaign name')),
                  DropdownButtonFormField<String>(
                    initialValue: channel,
                    decoration: const InputDecoration(labelText: 'Channel'),
                    items: const [
                      DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'sms', child: Text('SMS')),
                      DropdownMenuItem(value: 'email', child: Text('Email')),
                    ],
                    onChanged: (v) => setS(() => channel = v ?? 'whatsapp'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: const [
                      DropdownMenuItem(value: 'csv', child: Text('CSV import')),
                      DropdownMenuItem(value: 'segment', child: Text('Lead segment')),
                    ],
                    onChanged: (v) => setS(() => audience = v ?? 'csv'),
                  ),
                  if (audience == 'segment')
                    DropdownButtonFormField<String>(
                      initialValue: segment,
                      decoration: const InputDecoration(labelText: 'Segment'),
                      items: const [
                        DropdownMenuItem(value: 'new_leads', child: Text('New leads')),
                        DropdownMenuItem(value: 'hot', child: Text('Hot')),
                        DropdownMenuItem(value: 'warm', child: Text('Warm')),
                        DropdownMenuItem(value: 'cold', child: Text('Cold')),
                        DropdownMenuItem(value: 'converted', child: Text('Converted')),
                      ],
                      onChanged: (v) => setS(() => segment = v ?? 'new_leads'),
                    ),
                  DropdownButtonFormField<String?>(
                    initialValue: templateId,
                    decoration: const InputDecoration(labelText: 'Template (optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Custom message')),
                      ..._templates
                          .where((t) => t.channel == channel)
                          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (v) => setS(() => templateId = v),
                  ),
                  TextField(
                    controller: brief,
                    decoration: const InputDecoration(labelText: 'AI brief (for generate)'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        try {
                          final r = await _repo.generateCampaignCopy(
                            brief: brief.text.trim(),
                            channel: channel,
                            name: name.text.trim().isEmpty ? 'Campaign' : name.text.trim(),
                          );
                          setS(() => message.text = '${r['message'] ?? ''}');
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI generate message'),
                    ),
                  ),
                  TextField(
                    controller: message,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Message body'),
                  ),
                  if (channel == 'whatsapp')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Also queue AI voice follow-up'),
                      value: triggerVoice,
                      onChanged: (v) => setS(() => triggerVoice = v),
                    ),
                  if (audience == 'csv')
                    TextField(
                      controller: csv,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Recipients CSV',
                        hintText: 'phone,full_name,email',
                      ),
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

    if (ok == true && name.text.trim().isNotEmpty) {
      final id = await _repo.createCampaign({
        'name': name.text.trim(),
        'channel': channel,
        'status': 'draft',
        'template_id': templateId,
        'message_body': message.text.trim(),
        'trigger_voice': triggerVoice,
        'segment': audience == 'segment' ? {'preset': segment} : {},
      });
      if (audience == 'csv') {
        final lines = csv.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          await _repo.importCampaignRecipients(id, lines);
        }
      } else {
        final n = await _repo.addCampaignRecipientsFromSegment(
          campaignId: id,
          segmentPreset: segment,
          channel: channel,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added $n recipients from segment "$segment"')),
          );
        }
      }
      _load();
    }
  }

  Future<void> _runCampaign(BosCampaign campaign) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Launch campaign?'),
        content: Text(
          'Send via ${campaign.channel ?? 'whatsapp'} to pending recipients for "${campaign.name}". '
          'Without provider secrets, messages are queued / sent_sim.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Launch')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _repo.runCampaign(campaign.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result['channel'] ?? ''} · sent ${result['sent']}, '
              'skipped ${result['skipped']}, failed ${result['failed']}',
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

  Future<void> _showRecipients(BosCampaign campaign) async {
    final rows = await _repo.listCampaignRecipients(campaign.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Recipients · ${campaign.name}'),
        content: SizedBox(
          width: 480,
          height: 360,
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              return ListTile(
                dense: true,
                title: Text('${r['full_name'] ?? ''} · ${r['phone'] ?? r['email'] ?? ''}'),
                subtitle: Text(
                  '${r['status']} · ${r['delivery_status'] ?? '-'}',
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

  Future<void> _addTemplate() async {
    final name = TextEditingController();
    final body = TextEditingController(text: 'Hi {{name}}, …');
    var channel = 'whatsapp';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Message template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              DropdownButtonFormField<String>(
                initialValue: channel,
                decoration: const InputDecoration(labelText: 'Channel'),
                items: const [
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                ],
                onChanged: (v) => setS(() => channel = v ?? 'whatsapp'),
              ),
              TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Body')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.createWaTemplate(
        name: name.text.trim(),
        body: body.text.trim(),
        channel: channel,
      );
      _load();
    }
  }

  Future<void> _addOptOut() async {
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add opt-out'),
        content: TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && phone.text.trim().isNotEmpty) {
      await _repo.addOptOut(phone.text.trim());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Campaign Manager (WA / SMS / Email)',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          switch (_tabs.index) {
            case 1:
              _addTemplate();
            case 2:
              _addOptOut();
            default:
              _createCampaign();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 1
            ? 'Template'
            : _tabs.index == 2
                ? 'Opt-out'
                : 'Campaign'),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Campaigns'),
              Tab(text: 'Templates'),
              Tab(text: 'Opt-outs'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _campaigns.length,
                          itemBuilder: (_, i) {
                            final c = _campaigns[i];
                            return ListTile(
                              leading: Icon(_channelIcon(c.channel)),
                              title: Text(c.name),
                              subtitle: Text(
                                '${c.channel ?? 'whatsapp'} · ${c.status} · sent ${c.sentCount}'
                                '${c.segmentPreset.isNotEmpty ? ' · ${c.segmentPreset}' : ''}'
                                '${c.triggerVoice ? ' · +voice' : ''}',
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Recipients',
                                    onPressed: () => _showRecipients(c),
                                    icon: const Icon(Icons.people_outline),
                                  ),
                                  if (c.status == 'draft' || c.status == 'paused')
                                    FilledButton(
                                      onPressed: () => _runCampaign(c),
                                      child: const Text('Launch'),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      ListView.builder(
                        itemCount: _templates.length,
                        itemBuilder: (_, i) {
                          final t = _templates[i];
                          return ListTile(
                            leading: Icon(_channelIcon(t.channel)),
                            title: Text(t.name),
                            subtitle: Text(
                              '${t.channel} · ${t.body}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                      ListView.builder(
                        itemCount: _optOuts.length,
                        itemBuilder: (_, i) {
                          final o = _optOuts[i];
                          return ListTile(
                            leading: const Icon(Icons.block),
                            title: Text('${o['phone'] ?? o['email']}'),
                            subtitle: Text('${o['reason'] ?? 'opt-out'} · ${o['channel']}'),
                          );
                        },
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
      case 'sms':
        return Icons.sms;
      case 'email':
        return Icons.email_outlined;
      default:
        return Icons.campaign;
    }
  }
}

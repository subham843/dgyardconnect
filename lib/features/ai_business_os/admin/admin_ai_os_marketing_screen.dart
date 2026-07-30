import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsMarketingScreen extends StatefulWidget {
  const AdminAiOsMarketingScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsMarketingScreen> createState() => _AdminAiOsMarketingScreenState();
}

class _AdminAiOsMarketingScreenState extends State<AdminAiOsMarketingScreen> {
  final _repo = BosRepository();
  List<BosMarketingCampaign> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.listMarketingCampaigns();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final brief = TextEditingController();
    var channel = 'content';
    var tone = 'professional';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Marketing brief'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Campaign name')),
              TextField(controller: brief, maxLines: 4, decoration: const InputDecoration(labelText: 'Brief')),
              DropdownButtonFormField<String>(
                initialValue: channel,
                decoration: const InputDecoration(labelText: 'Channel'),
                items: const [
                  DropdownMenuItem(value: 'content', child: Text('Content')),
                  DropdownMenuItem(value: 'ads', child: Text('Ads')),
                  DropdownMenuItem(value: 'social', child: Text('Social')),
                ],
                onChanged: (v) => setS(() => channel = v ?? 'content'),
              ),
              DropdownButtonFormField<String>(
                initialValue: tone,
                decoration: const InputDecoration(labelText: 'Tone'),
                items: const [
                  DropdownMenuItem(value: 'professional', child: Text('Professional')),
                  DropdownMenuItem(value: 'friendly', child: Text('Friendly')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (v) => setS(() => tone = v ?? 'professional'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        await _repo.generateMarketing(
          name: name.text.trim(),
          brief: brief.text.trim(),
          channel: channel,
          tone: tone,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _view(BosMarketingCampaign m) async {
    // Regenerate / show latest content
    Map<String, dynamic>? content;
    try {
      final result = await _repo.generateMarketing(
        name: m.name,
        brief: m.brief ?? '',
        channel: m.channel ?? 'content',
        campaignId: m.id,
      );
      content = (result['content'] as Map?)?.cast<String, dynamic>();
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.name),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Text(
              content == null
                  ? (m.brief ?? 'No content')
                  : 'Headline: ${content['headline']}\n\n'
                      '${content['primary_text']}\n\n'
                      'CTA: ${content['cta']}\n'
                      'Tags: ${(content['hashtags'] as List?)?.join(' ') ?? ''}',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Digital Marketing AI',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final m = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.campaign),
                    title: Text(m.name),
                    subtitle: Text('${m.channel ?? 'content'} · ${m.status ?? 'draft'}'),
                    onTap: () => _view(m),
                  );
                },
              ),
            ),
    );
  }
}

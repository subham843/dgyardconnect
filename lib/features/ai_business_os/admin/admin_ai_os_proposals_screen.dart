import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsProposalsScreen extends StatefulWidget {
  const AdminAiOsProposalsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsProposalsScreen> createState() => _AdminAiOsProposalsScreenState();
}

class _AdminAiOsProposalsScreenState extends State<AdminAiOsProposalsScreen> {
  final _repo = BosRepository();
  List<BosProposal> _items = [];
  List<BosDeal> _deals = [];
  List<BosLead> _leads = [];
  List<BosQuotation> _quotes = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.listProposals();
    final deals = await _repo.listDeals();
    final leads = await _repo.listLeads();
    final quotes = await _repo.listQuotations();
    final templates = await _repo.listProposalTemplates();
    if (mounted) {
      setState(() {
        _items = items;
        _deals = deals;
        _leads = leads;
        _quotes = quotes;
        _templates = templates;
        _loading = false;
      });
    }
  }

  Future<void> _aiDraft() async {
    String? dealId;
    String? leadId;
    String? quotationId;
    final title = TextEditingController(text: 'Service proposal');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('AI proposal draft'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                DropdownButtonFormField<String?>(
                  initialValue: dealId,
                  decoration: const InputDecoration(labelText: 'Deal'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._deals.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))),
                  ],
                  onChanged: (v) => setS(() => dealId = v),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: leadId,
                  decoration: const InputDecoration(labelText: 'Lead'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._leads.map((l) => DropdownMenuItem(value: l.id, child: Text(l.displayName))),
                  ],
                  onChanged: (v) => setS(() => leadId = v),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: quotationId,
                  decoration: const InputDecoration(labelText: 'Quotation / BOQ'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._quotes.map(
                      (q) => DropdownMenuItem(
                        value: q.id,
                        child: Text(q.title ?? q.quoteNumber ?? q.id),
                      ),
                    ),
                  ],
                  onChanged: (v) => setS(() => quotationId = v),
                ),
                if (_templates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Uses default template: ${_templates.firstWhere((t) => t['is_default'] == true, orElse: () => _templates.first)['name']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await _repo.draftProposalAi(
          dealId: dealId,
          leadId: leadId,
          quotationId: quotationId,
          title: title.text.trim().isEmpty ? null : title.text.trim(),
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _view(BosProposal p) async {
    final body = TextEditingController(text: p.bodyMarkdown ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.title),
        content: SizedBox(
          width: 560,
          height: 440,
          child: TextField(
            controller: body,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _repo.updateProposal(p.id, {'status': 'sent'});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Mark sent'),
          ),
          FilledButton(
            onPressed: () async {
              await _repo.updateProposal(p.id, {
                'body_markdown': body.text,
                'status': p.status ?? 'draft',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Proposal Generator',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _aiDraft,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI draft'),
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
                    leading: const Icon(Icons.description),
                    title: Text(p.title),
                    subtitle: Text(p.status ?? 'draft'),
                    onTap: () => _view(p),
                  );
                },
              ),
            ),
    );
  }
}

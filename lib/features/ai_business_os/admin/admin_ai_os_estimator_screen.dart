import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsEstimatorScreen extends StatefulWidget {
  const AdminAiOsEstimatorScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsEstimatorScreen> createState() => _AdminAiOsEstimatorScreenState();
}

class _AdminAiOsEstimatorScreenState extends State<AdminAiOsEstimatorScreen> {
  final _repo = BosRepository();
  List<BosEstimate> _items = [];
  List<BosLead> _leads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.listEstimates();
    final leads = await _repo.listLeads();
    if (mounted) {
      setState(() {
        _items = items;
        _leads = leads;
        _loading = false;
      });
    }
  }

  Future<void> _wizard() async {
    var type = 'website';
    var ecommerce = false;
    var adminPanel = true;
    var seoPack = false;
    final pages = TextEditingController(text: '8');
    final platforms = TextEditingController(text: '0');
    final title = TextEditingController(text: 'Website estimate');
    String? leadId;
    Map<String, dynamic>? preview;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) {
          void recalc() {
            preview = _repo.computeWebsiteAppEstimate(
              estimateType: type,
              pages: int.tryParse(pages.text) ?? 8,
              platforms: int.tryParse(platforms.text) ?? 0,
              ecommerce: ecommerce,
              adminPanel: adminPanel,
              seoPack: seoPack,
            );
            setS(() {});
          }

          preview ??= _repo.computeWebsiteAppEstimate(
            estimateType: type,
            pages: 8,
            platforms: 0,
            ecommerce: ecommerce,
            adminPanel: adminPanel,
            seoPack: seoPack,
          );

          return AlertDialog(
            title: const Text('Website & App Estimator'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Product'),
                      items: const [
                        DropdownMenuItem(value: 'website', child: Text('Website')),
                        DropdownMenuItem(value: 'mobile_app', child: Text('Mobile app')),
                        DropdownMenuItem(value: 'both', child: Text('Website + App')),
                      ],
                      onChanged: (v) {
                        type = v ?? 'website';
                        recalc();
                      },
                    ),
                    TextField(
                      controller: pages,
                      decoration: const InputDecoration(labelText: 'Pages / screens'),
                      onChanged: (_) => recalc(),
                    ),
                    TextField(
                      controller: platforms,
                      decoration: const InputDecoration(labelText: 'Native platforms (0–2)'),
                      onChanged: (_) => recalc(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('E-commerce'),
                      value: ecommerce,
                      onChanged: (v) {
                        ecommerce = v;
                        recalc();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Admin panel'),
                      value: adminPanel,
                      onChanged: (v) {
                        adminPanel = v;
                        recalc();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('SEO pack'),
                      value: seoPack,
                      onChanged: (v) {
                        seoPack = v;
                        recalc();
                      },
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: leadId,
                      decoration: const InputDecoration(labelText: 'Link lead (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._leads.map((l) => DropdownMenuItem(value: l.id, child: Text(l.displayName))),
                      ],
                      onChanged: (v) => setS(() => leadId = v),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Indicative total: ₹${(((preview?['total_paise'] as num?) ?? 0) / 100).toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final computed = _repo.computeWebsiteAppEstimate(
                    estimateType: type,
                    pages: int.tryParse(pages.text) ?? 8,
                    platforms: int.tryParse(platforms.text) ?? 0,
                    ecommerce: ecommerce,
                    adminPanel: adminPanel,
                    seoPack: seoPack,
                  );
                  await _repo.createEstimateFromAnswers(
                    title: title.text.trim().isEmpty ? '$type estimate' : title.text.trim(),
                    estimateType: type,
                    computed: computed,
                    leadId: leadId,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Save estimate'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toProposal(BosEstimate e) async {
    try {
      await _repo.convertEstimateToProposal(e.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal created from estimate')),
        );
      }
      _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Website & App Estimator',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _wizard,
        icon: const Icon(Icons.calculate),
        label: const Text('New estimate'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final e = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.calculate),
                    title: Text(e.title),
                    subtitle: Text(
                      '${e.estimateType} · ₹${(e.totalPaise / 100).toStringAsFixed(0)} · ${e.status ?? 'draft'}',
                    ),
                    trailing: e.proposalId == null
                        ? TextButton(
                            onPressed: () => _toProposal(e),
                            child: const Text('To proposal'),
                          )
                        : const Chip(label: Text('Converted')),
                  );
                },
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsQuotationsScreen extends StatefulWidget {
  const AdminAiOsQuotationsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsQuotationsScreen> createState() => _AdminAiOsQuotationsScreenState();
}

class _AdminAiOsQuotationsScreenState extends State<AdminAiOsQuotationsScreen> {
  final _repo = BosRepository();
  List<BosQuotation> _quotations = [];
  List<BosDeal> _deals = [];
  List<BosLead> _leads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final quotations = await _repo.listQuotations();
    final deals = await _repo.listDeals();
    final leads = await _repo.listLeads();
    if (mounted) {
      setState(() {
        _quotations = quotations;
        _deals = deals;
        _leads = leads;
        _loading = false;
      });
    }
  }

  Future<void> _createBoq() async {
    final cameras = TextEditingController(text: '8');
    final nvr = TextEditingController(text: '16');
    final cable = TextEditingController(text: '120');
    final labour = TextEditingController(text: '2');
    final hdd = TextEditingController(text: '4');
    final customer = TextEditingController();
    final phone = TextEditingController();
    var cameraType = 'IP';
    String? dealId;
    String? leadId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('CCTV BOQ Generator'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: cameraType,
                    decoration: const InputDecoration(labelText: 'Camera type'),
                    items: const [
                      DropdownMenuItem(value: 'IP', child: Text('IP')),
                      DropdownMenuItem(value: 'HD', child: Text('HD / Analog')),
                    ],
                    onChanged: (v) => setS(() => cameraType = v ?? 'IP'),
                  ),
                  TextField(controller: cameras, decoration: const InputDecoration(labelText: 'Cameras')),
                  TextField(controller: nvr, decoration: const InputDecoration(labelText: 'NVR channels')),
                  TextField(controller: cable, decoration: const InputDecoration(labelText: 'Cable meters')),
                  TextField(controller: hdd, decoration: const InputDecoration(labelText: 'HDD TB')),
                  TextField(controller: labour, decoration: const InputDecoration(labelText: 'Labour days')),
                  TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer name')),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Customer phone')),
                  DropdownButtonFormField<String?>(
                    initialValue: dealId,
                    decoration: const InputDecoration(labelText: 'Link deal (optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._deals.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))),
                    ],
                    onChanged: (v) => setS(() => dealId = v),
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate BOQ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _repo.createCctvBoqQuotation(
        cameras: int.tryParse(cameras.text) ?? 8,
        nvrChannels: int.tryParse(nvr.text) ?? 16,
        cableMeters: int.tryParse(cable.text) ?? 120,
        labourDays: int.tryParse(labour.text) ?? 2,
        hddTb: int.tryParse(hdd.text) ?? 4,
        cameraType: cameraType,
        dealId: dealId,
        leadId: leadId,
        customerName: customer.text.trim().isEmpty ? null : customer.text.trim(),
        customerPhone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        title: 'CCTV BOQ · ${customer.text.trim().isEmpty ? cameraType : customer.text.trim()}',
      );
      _load();
    }
  }

  Future<void> _showLines(BosQuotation q) async {
    final lines = await _repo.listQuotationLines(q.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(q.quoteNumber ?? q.title ?? 'Quotation'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subtotal ₹${(q.subtotalPaise / 100).toStringAsFixed(0)} · '
                'Tax ₹${(q.taxPaise / 100).toStringAsFixed(0)} · '
                'Total ₹${(q.totalPaise / 100).toStringAsFixed(0)}',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: lines.length,
                  itemBuilder: (_, i) {
                    final l = lines[i];
                    return ListTile(
                      dense: true,
                      title: Text('${l['category']}: ${l['description']}'),
                      subtitle: Text(
                        'Qty ${l['qty']} × ₹${((l['unit_price_paise'] as num?) ?? 0) / 100} '
                        '+ ${l['tax_percent']}% GST',
                      ),
                      trailing: Text('₹${((l['line_total_paise'] as num?) ?? 0) / 100}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _repo.updateQuotationStatus(q.id, 'sent');
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Mark sent'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _proposalFromQuote(BosQuotation q) async {
    try {
      await _repo.draftProposalAi(
        quotationId: q.id,
        title: 'Proposal · ${q.title ?? q.quoteNumber}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal drafted — open Proposals module')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Quotation & BOQ',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBoq,
        icon: const Icon(Icons.add),
        label: const Text('CCTV BOQ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _quotations.length,
                itemBuilder: (_, i) {
                  final q = _quotations[i];
                  return ListTile(
                    leading: const Icon(Icons.request_quote),
                    title: Text(q.title ?? q.quoteNumber ?? 'Quotation'),
                    subtitle: Text(
                      '${q.quoteNumber ?? ''} · ₹${(q.totalPaise / 100).toStringAsFixed(0)} · ${q.status ?? 'draft'}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Lines',
                          onPressed: () => _showLines(q),
                          icon: const Icon(Icons.list_alt),
                        ),
                        IconButton(
                          tooltip: 'Draft proposal',
                          onPressed: () => _proposalFromQuote(q),
                          icon: const Icon(Icons.description_outlined),
                        ),
                      ],
                    ),
                    onTap: () => _showLines(q),
                  );
                },
              ),
            ),
    );
  }
}

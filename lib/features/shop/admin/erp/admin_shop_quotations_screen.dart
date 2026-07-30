import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../admin/widgets/admin_embedded_scaffold.dart';
import '../../data/shop_erp_repository.dart';
import '../../../../core/editing/dg_assist_text_field.dart';
import '../../domain/shop_erp_models.dart';

class AdminShopQuotationsScreen extends StatefulWidget {
  const AdminShopQuotationsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopQuotationsScreen> createState() => _AdminShopQuotationsScreenState();
}

class _AdminShopQuotationsScreenState extends State<AdminShopQuotationsScreen> {
  final _repo = ShopErpRepository();
  List<ShopQuotation> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listShopQuotations();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final num = TextEditingController(text: 'SQ-${DateTime.now().millisecondsSinceEpoch % 100000}');
    final notes = TextEditingController();
    final customers = await _repo.listCustomers(activeOnly: true);
    String? customerId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New quotation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: num, decoration: const InputDecoration(labelText: 'Quote number *')),
              DropdownButtonFormField<String?>(
                initialValue: customerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Walk-in —')),
                  for (final c in customers)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setLocal(() => customerId = v),
              ),
              DgAssistTextField(
                controller: notes,
                assistProfile: TextAssistProfile.erpNotes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Quotation notes', border: OutlineInputBorder()),
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
    if (ok != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.createShopQuotation(
      firebaseUid: uid,
      quoteNumber: num.text,
      customerId: customerId,
      notes: notes.text,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Quotations',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.request_quote),
        label: const Text('Quote'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final q = _items[i];
                return ListTile(
                  title: Text(q.quoteNumber),
                  subtitle: Text('${q.customerName ?? '—'} · ${q.status}'),
                  trailing: Text(
                    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(q.totalAmount),
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../data/marketplace_rfq_repository.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceRfqNewScreen extends StatefulWidget {
  const MarketplaceRfqNewScreen({super.key});

  @override
  State<MarketplaceRfqNewScreen> createState() => _MarketplaceRfqNewScreenState();
}

class _MarketplaceRfqNewScreenState extends State<MarketplaceRfqNewScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _gstin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _gstin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
          Text(
            'Request a formal quote',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'D.G.Yard pricing desk will respond. No seller identities are disclosed during negotiation.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Subject / SKU summary'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Requirements (qty, timeline, delivery pincode)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gstin,
            decoration: const InputDecoration(labelText: 'GSTIN (optional)'),
          ),
      ],
    );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Bulk / RFQ request')),
      body: Column(
        children: [
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  if (_title.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add a subject')),
                    );
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    final id = await MarketplaceRfqRepository().submitRfq(
                      buyerUid: uid,
                      title: _title.text.trim(),
                      notes: _notes.text.trim(),
                      companyGstin: _gstin.text.trim().isEmpty ? null : _gstin.text.trim(),
                    );
                    if (!context.mounted) return;
                    context.go(RouteNames.marketplaceRfqDetail(id));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit RFQ'),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'data/admin_marketplace_rules_store.dart';

/// Pricing / margin metadata in the same doc as COD (optional keys for future automation).
class AdminMarketplacePricingScreen extends StatefulWidget {
  const AdminMarketplacePricingScreen({super.key});

  @override
  State<AdminMarketplacePricingScreen> createState() => _AdminMarketplacePricingScreenState();
}

class _AdminMarketplacePricingScreenState extends State<AdminMarketplacePricingScreen> {
  bool _loading = true;
  bool _saving = false;
  final _marginBps = TextEditingController();
  final _inFreightInr = TextEditingController();
  final _outFreightInr = TextEditingController();
  final _handlingInr = TextEditingController();
  final _rolloutKey = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _marginBps.dispose();
    _inFreightInr.dispose();
    _outFreightInr.dispose();
    _handlingInr.dispose();
    _rolloutKey.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await AdminMarketplaceRulesStore.loadOrEmpty();
    if (!mounted) return;
    int paiseToInrInt(int? p) => ((p ?? 0) / 100).round();

    setState(() {
      _marginBps.text = '${(d['default_category_margin_bps'] as num?)?.toInt() ?? 0}';
      _inFreightInr.text = '${paiseToInrInt((d['inbound_freight_flat_paise'] as num?)?.toInt())}';
      _outFreightInr.text = '${paiseToInrInt((d['outbound_freight_flat_paise'] as num?)?.toInt())}';
      _handlingInr.text = '${paiseToInrInt((d['packing_handling_flat_paise'] as num?)?.toInt())}';
      _rolloutKey.text = (d['pricing_rollout_rc_key'] as String?)?.trim() ?? '';
      _notes.text = (d['pricing_notes'] as String?)?.trim() ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final bps = int.tryParse(_marginBps.text.trim());
    final inf = int.tryParse(_inFreightInr.text.trim().replaceAll(',', ''));
    final outf = int.tryParse(_outFreightInr.text.trim().replaceAll(',', ''));
    final hand = int.tryParse(_handlingInr.text.trim().replaceAll(',', ''));
    if (bps == null || bps < 0 || bps > 50000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Margin (bps) must be between 0 and 50000 (100% = 10000 bps).')),
      );
      return;
    }
    if (inf == null || inf < 0 || outf == null || outf < 0 || hand == null || hand < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid INR amounts (0+).')));
      return;
    }

    setState(() => _saving = true);
    try {
      await AdminMarketplaceRulesStore.merge({
        'default_category_margin_bps': bps,
        'inbound_freight_flat_paise': inf * 100,
        'outbound_freight_flat_paise': outf * 100,
        'packing_handling_flat_paise': hand * 100,
        'pricing_rollout_rc_key': _rolloutKey.text.trim(),
        'pricing_notes': _notes.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pricing fields saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing desk'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Stored in config/marketplace_rules (merge). Checkout callables do not read these yet — safe for policy + future automation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _marginBps,
                  decoration: const InputDecoration(
                    labelText: 'Default category margin (basis points)',
                    helperText: '100 bps = 1%. Example: 800 = 8%',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _inFreightInr,
                  decoration: const InputDecoration(
                    labelText: 'Inbound freight flat (INR)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _outFreightInr,
                  decoration: const InputDecoration(
                    labelText: 'Outbound freight flat (INR)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _handlingInr,
                  decoration: const InputDecoration(
                    labelText: 'Packing + handling flat (INR)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rolloutKey,
                  decoration: const InputDecoration(
                    labelText: 'Remote Config key (optional)',
                    hintText: 'feature_flags_json sub-key for staged rollout',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Internal notes',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
    );
  }
}

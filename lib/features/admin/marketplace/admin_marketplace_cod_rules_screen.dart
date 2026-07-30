import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'data/admin_marketplace_rules_store.dart';

/// Edits `config/marketplace_rules` COD fields (enforced by Cloud Functions).
class AdminMarketplaceCodRulesScreen extends StatefulWidget {
  const AdminMarketplaceCodRulesScreen({super.key});

  @override
  State<AdminMarketplaceCodRulesScreen> createState() => _AdminMarketplaceCodRulesScreenState();
}

class _AdminMarketplaceCodRulesScreenState extends State<AdminMarketplaceCodRulesScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _codEnabled = true;
  final _maxInr = TextEditingController();
  final _pincodes = TextEditingController();
  final _minTrust = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maxInr.dispose();
    _pincodes.dispose();
    _minTrust.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await AdminMarketplaceRulesStore.loadOrEmpty();
    if (!mounted) return;
    setState(() {
      _codEnabled = d['cod_enabled'] != false;
      final paise = (d['cod_max_amount_paise'] as num?)?.toInt() ?? 5000000;
      _maxInr.text = (paise / 100).round().toString();
      final pins = d['cod_blocked_pincodes'];
      if (pins is List) {
        _pincodes.text = pins.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join(', ');
      }
      _minTrust.text = '${(d['cod_min_trust_score'] as num?)?.toInt() ?? 0}';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final maxRupees = int.tryParse(_maxInr.text.trim().replaceAll(',', ''));
    final minTrust = int.tryParse(_minTrust.text.trim());
    if (maxRupees == null || maxRupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid max COD amount (INR).')));
      return;
    }
    if (minTrust == null || minTrust < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid minimum trust score (0+).')));
      return;
    }
    final pins = _pincodes.text
        .split(RegExp(r'[\s,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      await AdminMarketplaceRulesStore.merge({
        'cod_enabled': _codEnabled,
        'cod_max_amount_paise': maxRupees * 100,
        'cod_blocked_pincodes': pins,
        'cod_min_trust_score': minTrust,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('COD rules saved')));
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
        title: const Text('COD rules'),
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
                SwitchListTile(
                  title: const Text('COD enabled'),
                  subtitle: const Text('Server still re-checks on every order.'),
                  value: _codEnabled,
                  onChanged: _saving ? null : (v) => setState(() => _codEnabled = v),
                ),
                const Divider(height: 32),
                TextField(
                  controller: _maxInr,
                  decoration: const InputDecoration(
                    labelText: 'Max order amount for COD (INR)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _minTrust,
                  decoration: const InputDecoration(
                    labelText: 'Minimum trust score (users.trustScore)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pincodes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Blocked pincodes',
                    hintText: 'Comma or space separated, e.g. 110001, 400001',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Document: config/marketplace_rules · Callables: marketplaceCheckCodEligibility, marketplacePlaceCodOrder',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
    );
  }
}

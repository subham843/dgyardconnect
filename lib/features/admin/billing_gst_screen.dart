import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: GST / Billing config (config/billing_gst).
class BillingGstScreen extends StatefulWidget {
  const BillingGstScreen({super.key});

  @override
  State<BillingGstScreen> createState() => _BillingGstScreenState();
}

class _BillingGstScreenState extends State<BillingGstScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _gstNumberController;
  late TextEditingController _stateCodeController;
  late TextEditingController _gstRateController;
  bool _gstEnabled = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gstNumberController = TextEditingController();
    _stateCodeController = TextEditingController();
    _gstRateController = TextEditingController(text: '0.18');
    _load();
  }

  Future<void> _load() async {
    final snap = await FirestoreService.billingGstConfig().get();
    if (!mounted) return;
    if (snap.exists && snap.data() != null) {
      final d = snap.data()!;
      _gstEnabled = d['gstEnabled'] as bool? ?? false;
      _gstNumberController.text = d['platformGstNumber'] as String? ?? '';
      _stateCodeController.text = d['stateCode'] as String? ?? '';
      _gstRateController.text = ((d['gstRate'] as num?) ?? 0.18).toString();
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _gstNumberController.dispose();
    _stateCodeController.dispose();
    _gstRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing / GST Config'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(RouteNames.adminHome)),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: const Text('GST Enabled'),
                    subtitle: const Text('Include GST in platform commission invoices'),
                    value: _gstEnabled,
                    onChanged: (v) => setState(() => _gstEnabled = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gstNumberController,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN / Platform GST Number',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stateCodeController,
                    decoration: const InputDecoration(
                      labelText: 'State Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _gstRateController,
                    decoration: const InputDecoration(
                      labelText: 'GST Rate (e.g. 0.18 for 18%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = double.tryParse(v);
                      if (n == null || n < 0 || n > 1) return 'Enter a rate between 0 and 1 (e.g. 0.18)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(context),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _saving ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final rate = double.tryParse(_gstRateController.text) ?? 0.18;
      await FirestoreService.billingGstConfig().set({
        'gstEnabled': _gstEnabled,
        'platformGstNumber': _gstNumberController.text.trim(),
        'stateCode': _stateCodeController.text.trim(),
        'gstRate': rate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

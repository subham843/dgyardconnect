import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/firestore_service.dart';

class JobLimitConfigScreen extends StatefulWidget {
  const JobLimitConfigScreen({super.key});

  @override
  State<JobLimitConfigScreen> createState() => _JobLimitConfigScreenState();
}

class _JobLimitConfigScreenState extends State<JobLimitConfigScreen> {
  final _dealerLimit = TextEditingController();
  final _techLimit = TextEditingController();
  final _techFeeValue = TextEditingController();
  String _techFeeType = 'fixed'; // fixed | percent (percent treated as fixed count in current function)
  bool _saving = false;

  @override
  void dispose() {
    _dealerLimit.dispose();
    _techLimit.dispose();
    _techFeeValue.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (Firebase.apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase is not configured.')),
      );
      return;
    }
    final d = int.tryParse(_dealerLimit.text.trim()) ?? 0;
    final t = int.tryParse(_techLimit.text.trim()) ?? 0;
    final fee = double.tryParse(_techFeeValue.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('adminSetJobLimitConfig').call({
        'defaultDealerPostFreeLimit': d,
        'defaultTechnicianAcceptFreeLimit': t,
        'technicianAcceptanceChargeType': _techFeeType,
        'technicianAcceptanceChargeValue': fee,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job limits')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Job limits'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('config')
            .doc('job_limit_config')
            .snapshots(),
        builder: (context, snapshot) {
          final d = snapshot.data?.data() ?? {};
          _dealerLimit.text = '${(d['defaultDealerPostFreeLimit'] as num?)?.toInt() ?? 10}';
          _techLimit.text = '${(d['defaultTechnicianAcceptFreeLimit'] as num?)?.toInt() ?? 15}';
          _techFeeType = (d['technicianAcceptanceChargeType'] as String?) ?? _techFeeType;
          _techFeeValue.text = '${(d['technicianAcceptanceChargeValue'] as num?)?.toDouble() ?? 0}';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Global free limits', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dealerLimit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dealer free job posts',
                        hintText: 'e.g. 10',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _techLimit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Technician free job accepts',
                        hintText: 'e.g. 15',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Technician acceptance fee (after limit)', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _techFeeType,
                      items: const [
                        DropdownMenuItem(value: 'fixed', child: Text('Fixed (₹)')),
                        DropdownMenuItem(value: 'percent', child: Text('Percent (treated as fixed in current backend)')),
                      ],
                      onChanged: (v) => setState(() => _techFeeType = v ?? 'fixed'),
                      decoration: const InputDecoration(labelText: 'Fee type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _techFeeValue,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Fee value',
                        hintText: 'e.g. 5 or 10',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dealer platform commission is controlled via “Platform charge config”.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ],
          );
        },
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          useMaterial3: true,
        ),
        child: child,
      ),
    );
  }
}


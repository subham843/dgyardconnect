import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminEscrowSettlementScreen extends StatefulWidget {
  const AdminEscrowSettlementScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<AdminEscrowSettlementScreen> createState() => _AdminEscrowSettlementScreenState();
}

class _AdminEscrowSettlementScreenState extends State<AdminEscrowSettlementScreen> {
  bool _loading = false;
  String _decision = 'release_full_to_tech';
  bool _prefilledClaimId = false;
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _percentController = TextEditingController();
  final _newTechController = TextEditingController();
  final _claimIdController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    _percentController.dispose();
    _newTechController.dispose();
    _claimIdController.dispose();
    super.dispose();
  }

  Future<void> _submit(double holdAmount) async {
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'jobId': widget.jobId,
        'decision': _decision,
        'reason': _reasonController.text.trim(),
      };
      final claimId = _claimIdController.text.trim();
      if (claimId.isNotEmpty) data['claimId'] = claimId;

      if (_decision == 'partial_deduction') {
        final amt = double.tryParse(_amountController.text.trim());
        final pct = double.tryParse(_percentController.text.trim());
        if (amt != null && amt > 0) {
          data['amount'] = amt;
        } else if (pct != null && pct > 0) {
          data['percent'] = pct;
        } else {
          throw 'Enter amount or percent for partial deduction.';
        }
      }

      if (_decision == 'assign_to_new_tech') {
        final newTech = _newTechController.text.trim();
        if (newTech.isEmpty) throw 'New technician ID is required.';
        data['newTechnicianId'] = newTech;
      }

      // Safety: avoid accidental settlement if hold is zero.
      if (holdAmount <= 0) throw 'Hold amount is 0. Nothing to settle.';

      await FirebaseFunctions.instance.httpsCallable('adminApproveEscrow').call(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escrow settlement submitted.')),
      );
      context.go(RouteNames.adminEscrowApprovals);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escrow settlement')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Escrow settlement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Open job',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => context.push(RouteNames.adminJobDetail(widget.jobId)),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(widget.jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final doc = snapshot.data!;
          if (!doc.exists) return const Center(child: Text('Job not found'));
          final d = doc.data() ?? {};

          final title = (d['title'] as String?) ?? 'Job';
          final jobCode = (d['jobCode'] as String?)?.trim() ?? '';
          final displayJobId = jobCode.isNotEmpty ? jobCode : widget.jobId;
          final escrowStatus = (d['escrowStatus'] as String?) ?? '—';
          final lockReason = (d['escrowLockReason'] as String?) ?? '—';
          final hold = (d['holdPaymentAmount'] as num?)?.toDouble() ?? 0.0;
          final dealerId = (d['dealerId'] as String?) ?? '';
          final dealerCode = (d['dealerCode'] as String?)?.trim();
          final technicianId = (d['technicianId'] as String?) ?? '';
          final technicianCode = (d['technicianCode'] as String?)?.trim();
          final displayDealerId = dealerCode != null && dealerCode.isNotEmpty
              ? dealerCode
              : (dealerId.isEmpty ? '—' : UserModel(uid: dealerId).displayId);
          final displayTechnicianId = technicianCode != null && technicianCode.isNotEmpty
              ? technicianCode
              : (technicianId.isEmpty ? '—' : UserModel(uid: technicianId).displayId);
          final lockedByClaimId = (d['escrowLockedByClaimId'] as String?)?.trim();

          if (!_prefilledClaimId &&
              (_claimIdController.text.trim().isEmpty) &&
              lockedByClaimId != null &&
              lockedByClaimId.isNotEmpty) {
            _prefilledClaimId = true;
            _claimIdController.text = lockedByClaimId;
          }

          final isPartial = _decision == 'partial_deduction';
          final isReassign = _decision == 'assign_to_new_tech';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        _Row(label: 'Job ID', value: displayJobId),
                        _Row(label: 'Escrow status', value: escrowStatus),
                        _Row(label: 'Lock reason', value: lockReason),
                        _Row(label: 'Hold amount', value: '₹${hold.toStringAsFixed(0)}'),
                        _Row(label: 'Dealer', value: displayDealerId),
                        _Row(label: 'Technician', value: displayTechnicianId),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Decision',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _decision,
                          decoration: const InputDecoration(
                            labelText: 'Settlement type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'release_full_to_tech', child: Text('Release full to technician')),
                            DropdownMenuItem(value: 'partial_deduction', child: Text('Partial deduction (tech + dealer split)')),
                            DropdownMenuItem(value: 'transfer_to_dealer', child: Text('Transfer full to dealer')),
                            DropdownMenuItem(value: 'assign_to_new_tech', child: Text('Assign full to new technician')),
                            DropdownMenuItem(value: 'keep_platform', child: Text('Keep with platform')),
                          ],
                          onChanged: _loading ? null : (v) => setState(() => _decision = v ?? _decision),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _claimIdController,
                          decoration: const InputDecoration(
                            labelText: 'Claim ID (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isPartial) ...[
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Technician amount (₹) OR leave blank',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _percentController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Technician percent (0-100) OR leave blank',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (isReassign) ...[
                          TextFormField(
                            controller: _newTechController,
                            decoration: const InputDecoration(
                              labelText: 'New technician UID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason (recommended)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loading ? null : () => _submit(hold),
                          icon: _loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Approve & settle escrow'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Note: This action will close escrow for this job and write an audit record in escrow_transactions.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}


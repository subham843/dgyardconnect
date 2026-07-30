import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/account_completion_guard.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/rejection_reason_dialog.dart';
import '../../shared/widgets/technician_glass_kit.dart';

class TechnicianBiddingScreen extends StatelessWidget {
  const TechnicianBiddingScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
          appBar: const TechnicianGlassAppBar(title: 'Bidding'),
          body: const TechnicianGlassBackground(
            child: Center(child: Text('Firebase is not configured.')),
          ),
        ),
      );
    }
    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Bidding',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/technician/jobs/$jobId'),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final doc = snapshot.data!;
          if (!doc.exists) return const Center(child: Text('Job not found.'));
          final data = doc.data() ?? {};
          final job = JobModel.fromFirestore(doc);
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final offeredIds = (data['offeredToTechnicianIds'] as List<dynamic>?)?.cast<String>() ?? [];
          final lastRejectedBy = data['lastRejectedBy'] as String?;
          final dealerRejectedMe = uid != null &&
              offeredIds.contains(uid) &&
              data['technicianId'] == null &&
              lastRejectedBy == 'dealer';
          if (dealerRejectedMe) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.orange.shade700, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Job closed',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The dealer has rejected your offer. This job will be assigned to another technician.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(RouteNames.technicianHome),
                    child: const Text('Go to home'),
                  ),
                ],
              ),
            );
          }
          if (job.status == JobStatus.paymentPending) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.green.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payment, color: Colors.green.shade700, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Waiting for payment',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rate agreed. Bidding closed. Dealer will complete payment.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/technician/jobs/$jobId'),
                    child: const Text('View job'),
                  ),
                ],
              ),
            );
          }
          final lastBid = (data['lastTechnicianBidAmount'] as num?)?.toDouble();
          final dealerCounter = (data['dealerCounterAmount'] as num?)?.toDouble();
          final isLastNegotiation = data['isLastNegotiation'] == true;
          final technicianSentFinalCounter = data['technicianSentFinalCounter'] == true;
          final isMaterialByTech = data['materialOption'] == 'material_by_technician';
          final materialList = (data['materialList'] as List<dynamic>?) ?? [];
          final displayJobAmount = dealerCounter ?? job.dealerRate ?? job.fixedRate ?? 0.0;
          final displayMaterialTotal = _computeMaterialTotal(materialList, useDealerCounter: true);
          final displayAmount = displayJobAmount + displayMaterialTotal;
          final hasTechnicianBid = lastBid != null;
          final dealerHasCountered = dealerCounter != null;
          final waitingForDealer = hasTechnicianBid && !dealerHasCountered;
          final canAcceptOrRejectCounter = dealerHasCountered;
          final canSubmitBid = !hasTechnicianBid;
          final canCounterOffer = canAcceptOrRejectCounter && !technicianSentFinalCounter;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  job.title ?? 'Job',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (waitingForDealer) ...[
                  Card(
                    color: Colors.blue.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.hourglass_empty, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Waiting for dealer response',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isMaterialByTech && materialList.isNotEmpty
                                ? 'Your bid: Job ₹${lastBid.toStringAsFixed(0)} + Materials ₹${_computeMaterialTotal(materialList, useTechBid: true).toStringAsFixed(0)} = ₹${(lastBid + _computeMaterialTotal(materialList, useTechBid: true)).toStringAsFixed(0)}'
                                : 'Your bid: ₹${lastBid.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You cannot bid again until dealer accepts, counters, or rejects.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            dealerCounter != null
                                ? (isLastNegotiation ? 'Dealer final offer' : 'Dealer counter offer')
                                : 'Dealer rate',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (isMaterialByTech && materialList.isNotEmpty) ...[
                            Text(
                              'Job: ₹${displayJobAmount.toStringAsFixed(0)} (dealer posted: ₹${(job.dealerRate ?? job.fixedRate ?? 0).toStringAsFixed(0)})',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              'Materials: ₹${displayMaterialTotal.toStringAsFixed(0)} (dealer posted: ₹${_computeMaterialTotal(materialList).toStringAsFixed(0)})',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                          ] else if (!isMaterialByTech) ...[
                            Text(
                              'Dealer posted: ₹${(job.dealerRate ?? job.fixedRate ?? 0).toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            '₹${displayAmount.toStringAsFixed(0)}${isMaterialByTech && materialList.isNotEmpty ? ' (total)' : ''}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          if (isLastNegotiation)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Chip(
                                label: const Text('Final offer'),
                                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (canAcceptOrRejectCounter && canCounterOffer)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'You may accept this offer, send a counter offer, or reject. '
                        'If you send a counter offer, it will be your final offer. After that, your bidding option will close. '
                        'If the dealer accepts, you will receive the job. If the dealer rejects, the job will be assigned to another technician.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                if (canAcceptOrRejectCounter) ...[
                  if (canCounterOffer) ...[
                    OutlinedButton(
                      onPressed: () => _showBidSheet(context, job, data, isCounterOffer: true, lastBid: lastBid, dealerCounter: dealerCounter),
                      child: const Text('Counter offer'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: () => _acceptRate(context, displayAmount, materialList, isMaterialByTech),
                    child: const Text('Accept rate'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _rejectCounter(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Reject counter'),
                  ),
                ] else if (canSubmitBid) ...[
                  FilledButton(
                    onPressed: () => _showBidSheet(context, job, data, isCounterOffer: false, lastBid: null, dealerCounter: dealerCounter),
                    child: const Text('Counter offer'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _acceptRate(context, displayAmount, materialList, isMaterialByTech),
                    child: const Text('Accept rate'),
                  ),
                ],
              ],
            ),
          );
        },
      )),
    ),
    );
  }

  void _showBidSheet(
    BuildContext context,
    JobModel job,
    Map<String, dynamic> data, {
    required bool isCounterOffer,
    double? lastBid,
    double? dealerCounter,
  }) {
    final isMaterialByTech = data['materialOption'] == 'material_by_technician';
    final materialList = (data['materialList'] as List<dynamic>?) ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TechnicianBidSheetContent(
        job: job,
        jobId: jobId,
        materialList: materialList,
        isMaterialByTech: isMaterialByTech,
        isCounterOffer: isCounterOffer,
        initialJobValue: isCounterOffer
            ? (lastBid ?? dealerCounter ?? job.dealerRate ?? job.fixedRate ?? 0)
            : (job.dealerRate ?? job.fixedRate ?? 0),
      ),
    );
  }

  Future<void> _acceptRate(
    BuildContext context,
    double amount,
    List<dynamic> materialList,
    bool isMaterialByTech,
  ) async {
    final canAccept = await AccountCompletionGuard.ensureTechnicianCanAcceptJob(context);
    if (!canAccept || !context.mounted) return;

    final updates = <String, dynamic>{
      'agreedAmount': amount,
      'status': 'payment_pending',
      'technicianPayoutAmount': amount,
    };
    if (isMaterialByTech && materialList.isNotEmpty) {
      final newMaterialList = materialList.map((e) {
        final m = Map<String, dynamic>.from(e is Map ? Map.from(e) : <String, dynamic>{});
        final rate = (m['dealerCounterRate'] as num?)?.toDouble() ??
            (m['technicianBidRate'] as num?)?.toDouble() ??
            (m['rate'] as num?)?.toDouble() ??
            0.0;
        m['rate'] = rate;
        m['amount'] = ((m['qty'] as num?)?.toInt() ?? 1) * rate;
        m.remove('technicianBidRate');
        m.remove('dealerCounterRate');
        return m;
      }).toList();
      updates['materialList'] = newMaterialList;
    }
    await FirestoreService.jobs().doc(jobId).update(updates);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate accepted. Waiting for payment.')));
      context.go('/technician/jobs/$jobId');
    }
  }

  Future<void> _rejectCounter(BuildContext context) async {
    final reason = await showRejectionReasonDialog(context, type: 'technician');
    if (reason == null) return;
    try {
    final doc = await FirestoreService.jobs().doc(jobId).get();
    final data = doc.data() ?? {};
    final techId = data['technicianId'] as String?;
    final materialList = (data['materialList'] as List<dynamic>?) ?? [];
    final isMaterialByTech = data['materialOption'] == 'material_by_technician';
    final dealerCounter = (data['dealerCounterAmount'] as num?)?.toDouble();
    final lastBid = (data['lastTechnicianBidAmount'] as num?)?.toDouble();
    final dealerJobPrice = dealerCounter ?? 0.0;
    final techJobPrice = lastBid ?? 0.0;
    final dealerMaterialTotal = isMaterialByTech && materialList.isNotEmpty
        ? _computeMaterialTotal(materialList, useDealerCounter: true)
        : 0.0;
    final techMaterialTotal = isMaterialByTech && materialList.isNotEmpty
        ? _computeMaterialTotal(materialList, useTechBid: true)
        : 0.0;
    final dealerPrice = dealerJobPrice + dealerMaterialTotal;
    final technicianPrice = techJobPrice + techMaterialTotal;
    final lastPrice = dealerPrice;
    final offeredIds = (data['offeredToTechnicianIds'] as List<dynamic>?) ?? [];
    final willReachMax = offeredIds.length >= 2;
    final rejectionEntry = <String, dynamic>{
      'technicianId': techId,
      'dealerPrice': dealerPrice,
      'technicianPrice': technicianPrice,
      'lastPrice': lastPrice,
      'reason': reason,
      'rejectedAt': Timestamp.fromDate(DateTime.now()),
      'ordinal': offeredIds.length + 1,
    };
    final existingHistory = (data['technicianRejectionHistory'] as List<dynamic>?) ?? [];
    final newHistory = [...existingHistory.map((e) => e is Map ? Map<String, dynamic>.from(Map.from(e)) : <String, dynamic>{}), rejectionEntry];
    final updates = <String, dynamic>{
      'technicianId': null,
      'status': 'posted',
      'lastTechnicianBidAmount': FieldValue.delete(),
      'dealerCounterAmount': FieldValue.delete(),
      'isLastNegotiation': FieldValue.delete(),
      'technicianSentFinalCounter': FieldValue.delete(),
      'technicianRejectionHistory': newHistory,
    };
    if (isMaterialByTech && materialList.isNotEmpty) {
      final newMaterialList = materialList.map((e) {
        final m = Map<String, dynamic>.from(e is Map ? Map.from(e) : <String, dynamic>{});
        m.remove('technicianBidRate');
        m.remove('dealerCounterRate');
        final rate = (m['rate'] as num?)?.toDouble() ?? 0.0;
        m['amount'] = ((m['qty'] as num?)?.toInt() ?? 1) * rate;
        return m;
      }).toList();
      updates['materialList'] = newMaterialList;
    }
    if (techId != null) {
      updates['offeredToTechnicianIds'] = FieldValue.arrayUnion([techId]);
    }
    updates['lastRejectedBy'] = 'technician';
    updates['lastRejectionReason'] = reason;
    if (willReachMax) {
      updates['biddingMaxReached'] = true;
    }
    await FirestoreService.jobs().doc(jobId).update(updates);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willReachMax
                ? 'Counter rejected. Maximum bidding reached for this job.'
                : 'Counter rejected. Next technician will be notified.',
          ),
        ),
      );
      context.go(RouteNames.technicianMyJobs);
    }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e')),
        );
      }
    }
  }
}

class _TechnicianBidSheetContent extends StatefulWidget {
  const _TechnicianBidSheetContent({
    required this.job,
    required this.jobId,
    required this.materialList,
    required this.isMaterialByTech,
    required this.isCounterOffer,
    required this.initialJobValue,
  });
  final JobModel job;
  final String jobId;
  final List<dynamic> materialList;
  final bool isMaterialByTech;
  final bool isCounterOffer;
  final double initialJobValue;

  @override
  State<_TechnicianBidSheetContent> createState() => _TechnicianBidSheetContentState();
}

class _TechnicianBidSheetContentState extends State<_TechnicianBidSheetContent> {
  late final TextEditingController _jobController;
  late final Map<int, TextEditingController> _materialControllers;

  @override
  void initState() {
    super.initState();
    _jobController = TextEditingController(text: widget.initialJobValue.toStringAsFixed(0));
    _materialControllers = {};
    for (var i = 0; i < widget.materialList.length; i++) {
      final m = widget.materialList[i] is Map ? (widget.materialList[i] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final rate = (m['dealerCounterRate'] as num?)?.toDouble() ??
          (m['technicianBidRate'] as num?)?.toDouble() ??
          (m['rate'] as num?)?.toDouble() ??
          0.0;
      _materialControllers[i] = TextEditingController(text: rate.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    _jobController.dispose();
    for (final c in _materialControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final jobAmount = double.tryParse(_jobController.text.trim());
    if (jobAmount == null || jobAmount < 0) return;
    final updates = <String, dynamic>{
      'lastTechnicianBidAmount': jobAmount,
      'technicianBidCount': FieldValue.increment(1),
    };
    if (widget.isMaterialByTech && widget.materialList.isNotEmpty) {
      final newMaterialList = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.materialList.length; i++) {
        final m = Map<String, dynamic>.from(
          widget.materialList[i] is Map ? (widget.materialList[i] as Map).cast<String, dynamic>() : <String, dynamic>{},
        );
        final rate = double.tryParse(_materialControllers[i]!.text.trim()) ?? (m['rate'] as num?)?.toDouble() ?? 0.0;
        m['technicianBidRate'] = rate;
        if (widget.isCounterOffer) m.remove('dealerCounterRate');
        m['amount'] = ((m['qty'] as num?)?.toInt() ?? 1) * rate;
        newMaterialList.add(m);
      }
      updates['materialList'] = newMaterialList;
    }
    if (widget.isCounterOffer) {
      updates['dealerCounterAmount'] = FieldValue.delete();
      updates['isLastNegotiation'] = FieldValue.delete();
      updates['technicianSentFinalCounter'] = true;
    }
    await FirestoreService.jobs().doc(widget.jobId).update(updates);
    if (!mounted) return;
    Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isCounterOffer ? 'Counter offer sent to dealer.' : 'Bid sent to dealer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Job cost (₹)', style: Theme.of(context).textTheme.titleSmall),
              Text(
                'Dealer posted: ₹${(widget.job.dealerRate ?? widget.job.fixedRate ?? 0).toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _jobController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Amount'),
              ),
              if (widget.isMaterialByTech && widget.materialList.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Material list', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 8),
                    Icon(Icons.lock_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                    Text(' Item & qty locked', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                ...widget.materialList.asMap().entries.map((e) {
                  final m = e.value is Map ? (e.value as Map).cast<String, dynamic>() : <String, dynamic>{};
                  final slNo = (m['slNo'] as num?)?.toInt() ?? (e.key + 1);
                  final itemName = m['itemName'] as String? ?? 'Item';
                  final qty = (m['qty'] as num?)?.toInt() ?? 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('$slNo.', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(itemName, style: Theme.of(context).textTheme.bodyMedium)),
                                Text('Qty: $qty', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dealer posted: ₹${((m['rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('Your rate (₹): ', style: Theme.of(context).textTheme.bodySmall),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () {
                                    final v = double.tryParse(_materialControllers[e.key]!.text.trim()) ?? 0;
                                    _materialControllers[e.key]!.text = (v - 1).clamp(0, double.infinity).toStringAsFixed(0);
                                  },
                                  style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(36, 36)),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: _materialControllers[e.key],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(hintText: 'Rate', isDense: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () {
                                    final v = double.tryParse(_materialControllers[e.key]!.text.trim()) ?? 0;
                                    _materialControllers[e.key]!.text = (v + 1).toStringAsFixed(0);
                                  },
                                  style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(36, 36)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              if (widget.isCounterOffer) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'This is your final offer. After submitting, your bidding option will close. '
                    'If the dealer accepts, you will receive the job. If the dealer rejects, the job will be assigned to another technician.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: const Text('Send counter offer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _computeMaterialTotal(List<dynamic> materialList, {bool useTechBid = false, bool useDealerCounter = false}) {
  var total = 0.0;
  for (final e in materialList) {
    final m = e is Map ? Map<String, dynamic>.from(Map.from(e)) : <String, dynamic>{};
    final qty = (m['qty'] as num?)?.toInt() ?? 1;
    double rate;
    if (useDealerCounter && (m['dealerCounterRate'] as num?) != null) {
      rate = (m['dealerCounterRate'] as num).toDouble();
    } else if (useTechBid && (m['technicianBidRate'] as num?) != null) {
      rate = (m['technicianBidRate'] as num).toDouble();
    } else {
      rate = (m['rate'] as num?)?.toDouble() ?? 0.0;
    }
    total += qty * rate;
  }
  return total;
}

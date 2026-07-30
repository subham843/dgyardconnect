import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/dealer_ui_tokens.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/fcm_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/rejection_reason_dialog.dart';
import 'dealer_job_tracking_view.dart';

class DealerBiddingScreen extends StatefulWidget {
  const DealerBiddingScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<DealerBiddingScreen> createState() => _DealerBiddingScreenState();
}

class _DealerBiddingScreenState extends State<DealerBiddingScreen> {
  String get jobId => widget.jobId;

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bidding')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      backgroundColor: DealerUiTokens.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: DealerUiTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Bidding',
          style: TextStyle(
            fontSize: DealerUiTokens.titleNav,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dealer/jobs/$jobId'),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final doc = snapshot.data!;
          if (!doc.exists) return const Center(child: Text('Job not found.'));
          final job = JobModel.fromFirestore(doc);
          if (job.status == JobStatus.paymentPending) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: DealerUiTokens.border),
                    ),
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
                            'Rate agreed. Bidding closed. Proceed to payment.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push(
                      '/dealer/jobs/$jobId/pay',
                      extra: <String, double>{
                        'amount': job.technicianPayoutAmount ?? job.agreedAmount ?? 0,
                      },
                    ),
                    child: const Text('Proceed to payment'),
                  ),
                ],
              ),
            );
          }
          final data = doc.data() ?? {};
          final lastBid = (data['lastTechnicianBidAmount'] as num?)?.toDouble();
          final dealerCounter = (data['dealerCounterAmount'] as num?)?.toDouble();
          final isLastNegotiation = data['isLastNegotiation'] == true;
          final isMaterialByTechnician = data['materialOption'] == 'material_by_technician';
          final materialList = data['materialList'] as List<dynamic>? ?? [];
          final dealerHasCountered = dealerCounter != null;
          final technicianSentFinalCounter = data['technicianSentFinalCounter'] == true;
          final biddingMaxReached = data['biddingMaxReached'] == true;
          final offeredIds = (data['offeredToTechnicianIds'] as List<dynamic>?)?.length ?? 0;
          final technicianId = data['technicianId'] as String?;
          final waitingForTechnician = lastBid != null && dealerHasCountered;
          final canRespondToBid = lastBid != null && !dealerHasCountered;
          final canCounterOffer = canRespondToBid && !technicianSentFinalCounter;
          final isLastTechnician = offeredIds == 2;
          final technicianAcceptedWaitingForBid = technicianId != null && lastBid == null;
          final showTracking = technicianId != null &&
              (job.status == JobStatus.paid || job.status == JobStatus.inProgress);
          if (showTracking) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(job.title ?? 'Job', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(job.status.name),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  const SizedBox(height: 16),
                  DealerJobTrackingView(
                    jobId: jobId,
                    job: job,
                    jobData: data,
                  ),
                ],
              ),
            );
          }
          if (biddingMaxReached) {
            final rejectionHistory = _buildRejectionDisplayList(data);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rejectionHistory.isNotEmpty) ...[
                    _TechnicianRejectionCardsSection(history: rejectionHistory),
                    const SizedBox(height: 24),
                  ],
                  Text(job.title ?? 'Job', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: DealerUiTokens.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Maximum bidding reached for job',
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
                            'You have reached the maximum limit of 3 technicians for bidding on this job. No further bidding is possible.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(RouteNames.dealerHome),
                    child: const Text('Go to home'),
                  ),
                ],
              ),
            );
          }
          final rejectionHistory = _buildRejectionDisplayList(data);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rejectionHistory.isNotEmpty) ...[
                  _TechnicianRejectionCardsSection(history: rejectionHistory),
                  const SizedBox(height: 24),
                ],
                Text(
                  job.title ?? 'Job',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (waitingForTechnician) ...[
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: DealerUiTokens.border),
                    ),
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
                                'Waiting for technician response',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your counter offer: ₹${dealerCounter.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You cannot bid again until technician accepts or rejects.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          if (isLastTechnician) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'This is your last technician to bid. After this, you cannot bid with another technician for this job.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else if (lastBid != null)
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: DealerUiTokens.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Technician bid',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (isMaterialByTechnician && materialList.isNotEmpty) ...[
                            Text(
                              'Job: ₹${lastBid.toStringAsFixed(0)} (your posted: ₹${(job.dealerRate ?? job.fixedRate ?? 0).toStringAsFixed(0)})',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              'Materials: ₹${_computeMaterialTotal(materialList, useTechBid: true).toStringAsFixed(0)} (your posted: ₹${_computeMaterialTotal(materialList).toStringAsFixed(0)})',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                          ] else if (!isMaterialByTechnician) ...[
                            Text(
                              'Your posted rate: ₹${(job.dealerRate ?? job.fixedRate ?? 0).toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            '₹${(lastBid + (isMaterialByTechnician && materialList.isNotEmpty ? _computeMaterialTotal(materialList, useTechBid: true) : 0)).toStringAsFixed(0)}${isMaterialByTechnician && materialList.isNotEmpty ? ' (total)' : ''}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isLastNegotiation && !waitingForTechnician)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: const Text('Last negotiation'),
                      backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                if (isMaterialByTechnician && materialList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _InlineMaterialListWithPriceEditor(
                    key: ValueKey('mat-$lastBid-${materialList.length}'),
                    jobId: jobId,
                    materialList: materialList,
                    canEditPrice: canRespondToBid && canCounterOffer,
                  ),
                ],
                const SizedBox(height: 24),
                if (canRespondToBid) ...[
                  if (technicianSentFinalCounter)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'If you accept, the technician will receive the job. Otherwise, the job will be assigned to another technician.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ),
                  FilledButton(
                    onPressed: () => _acceptBid(context),
                    child: const Text('Accept bid'),
                  ),
                  if (canCounterOffer) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _showCounterSheet(context, job, data),
                      child: const Text('Counter offer'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _rejectBid(context),
                    child: const Text('Reject'),
                  ),
                ] else if (waitingForTechnician)
                  const SizedBox.shrink()
                else if (technicianAcceptedWaitingForBid)
                  _TechnicianAcceptedWaitingForBidCard()
                else ...[
                  _SearchingForTechnicianCard(),
                  if (job.status == JobStatus.posted &&
                      job.biddingEnabled == true &&
                      (job.bidRound ?? 1) < 3 &&
                      technicianId == null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _requestMoreBids(context),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Request more bids (next 10 technicians)'),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static List<Map<String, dynamic>> _buildRejectionDisplayList(Map<String, dynamic> data) {
    final history = (data['technicianRejectionHistory'] as List<dynamic>?) ?? [];
    if (history.isNotEmpty) {
      return history.map((e) => e is Map ? Map<String, dynamic>.from(Map.from(e)) : <String, dynamic>{}).toList();
    }
    final lastRejectedBy = data['lastRejectedBy'] as String?;
    final lastRejectionReason = data['lastRejectionReason'] as String?;
    if (lastRejectedBy == 'technician' && lastRejectionReason != null && lastRejectionReason.isNotEmpty) {
      return [
        {
          'dealerPrice': (data['dealerCounterAmount'] as num?)?.toDouble() ?? 0.0,
          'technicianPrice': (data['lastTechnicianBidAmount'] as num?)?.toDouble() ?? 0.0,
          'lastPrice': (data['dealerCounterAmount'] as num?)?.toDouble() ?? 0.0,
          'reason': lastRejectionReason,
          'ordinal': 1,
        },
      ];
    }
    return [];
  }

  void _showCounterSheet(BuildContext context, JobModel job, Map<String, dynamic> data) {
    final isMaterialByTech = data['materialOption'] == 'material_by_technician';
    final materialList = (data['materialList'] as List<dynamic>?) ?? [];
    final lastBid = (data['lastTechnicianBidAmount'] as num?)?.toDouble();
    final dealerCounter = (data['dealerCounterAmount'] as num?)?.toDouble();
    final jobInitial = dealerCounter ?? lastBid ?? job.dealerRate ?? job.fixedRate ?? 0.0;
    final jobController = TextEditingController(text: jobInitial.toStringAsFixed(0));
    final materialControllers = <int, TextEditingController>{};
    for (var i = 0; i < materialList.length; i++) {
      final m = materialList[i] is Map ? (materialList[i] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final rate = (m['dealerCounterRate'] as num?)?.toDouble() ??
          (m['technicianBidRate'] as num?)?.toDouble() ??
          (m['rate'] as num?)?.toDouble() ??
          0.0;
      materialControllers[i] = TextEditingController(text: rate.toStringAsFixed(0));
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Job cost (₹)', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  'Your posted: ₹${(job.dealerRate ?? job.fixedRate ?? 0).toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: jobController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Amount'),
                ),
                if (isMaterialByTech && materialList.isNotEmpty) ...[
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
                  ...materialList.asMap().entries.map((e) {
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
                                'Posted: ₹${((m['rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Counter (₹): ', style: Theme.of(context).textTheme.bodySmall),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () {
                                      final v = double.tryParse(materialControllers[e.key]!.text.trim()) ?? 0;
                                      materialControllers[e.key]!.text = (v - 1).clamp(0, double.infinity).toStringAsFixed(0);
                                    },
                                    style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(36, 36)),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: materialControllers[e.key],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(hintText: 'Rate', isDense: true),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      final v = double.tryParse(materialControllers[e.key]!.text.trim()) ?? 0;
                                      materialControllers[e.key]!.text = (v + 1).toStringAsFixed(0);
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    final jobAmount = double.tryParse(jobController.text.trim());
                    if (jobAmount == null || jobAmount < 0) return;
                    final updates = <String, dynamic>{
                      'dealerCounterAmount': jobAmount,
                      'isLastNegotiation': true,
                    };
                    if (isMaterialByTech && materialList.isNotEmpty) {
                      final newMaterialList = <Map<String, dynamic>>[];
                      for (var i = 0; i < materialList.length; i++) {
                        final m = Map<String, dynamic>.from(
                          materialList[i] is Map ? (materialList[i] as Map).cast<String, dynamic>() : <String, dynamic>{},
                        );
                        final rate = double.tryParse(materialControllers[i]!.text.trim()) ?? (m['rate'] as num?)?.toDouble() ?? 0.0;
                        m['dealerCounterRate'] = rate;
                        m['amount'] = ((m['qty'] as num?)?.toInt() ?? 1) * rate;
                        newMaterialList.add(m);
                      }
                      updates['materialList'] = newMaterialList;
                    }
                    await FirestoreService.jobs().doc(jobId).update(updates);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter offer sent.')));
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      for (final c in materialControllers.values) {
                        c.dispose();
                      }
                      jobController.dispose();
                    });
                  },
                  child: const Text('Send counter offer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptBid(BuildContext context) async {
    await FcmService.cancelJobNotification();
    final doc = await FirestoreService.jobs().doc(jobId).get();
    final data = doc.data() ?? {};
    final isMaterialByTech = data['materialOption'] == 'material_by_technician';
    final materialList = (data['materialList'] as List<dynamic>?) ?? [];
    final jobAmount = (data['dealerCounterAmount'] as num?)?.toDouble() ??
        (data['lastTechnicianBidAmount'] as num?)?.toDouble() ??
        (data['dealerRate'] as num?)?.toDouble() ??
        0.0;
    var totalAmount = jobAmount;
    Map<String, dynamic>? materialUpdate;
    if (isMaterialByTech && materialList.isNotEmpty) {
      final materialTotal = _computeMaterialTotal(materialList, useDealerCounter: true, useTechBid: true);
      totalAmount = jobAmount + materialTotal;
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
      materialUpdate = {'materialList': newMaterialList};
    }
    final updates = <String, dynamic>{
      'agreedAmount': totalAmount,
      'status': 'payment_pending',
      'technicianPayoutAmount': totalAmount,
      ...?materialUpdate,
    };
    await FirestoreService.jobs().doc(jobId).update(updates);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid accepted. Proceed to payment.')));
      context.go('/dealer/jobs/$jobId/bidding');
    }
  }

  Future<void> _rejectBid(BuildContext context) async {
    final reason = await showRejectionReasonDialog(context, type: 'dealer');
    if (reason == null) return;
    await FcmService.cancelJobNotification();
    final doc = await FirestoreService.jobs().doc(jobId).get();
    final data = doc.data() ?? {};
    final techId = data['technicianId'] as String?;
    final bidRound = (data['bidRound'] as num?)?.toInt() ?? 1;
    final willReachMax = bidRound >= 3;
    final materialList = (data['materialList'] as List<dynamic>?) ?? [];
    final isMaterialByTech = data['materialOption'] == 'material_by_technician';
    final updates = <String, dynamic>{
      'technicianId': null,
      'status': 'posted',
      'lastTechnicianBidAmount': FieldValue.delete(),
      'dealerCounterAmount': FieldValue.delete(),
      'isLastNegotiation': FieldValue.delete(),
      'technicianSentFinalCounter': FieldValue.delete(),
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
    if (techId != null) updates['offeredToTechnicianIds'] = FieldValue.arrayUnion([techId]);
    updates['lastRejectedBy'] = 'dealer';
    updates['lastRejectionReason'] = reason;
    await FirestoreService.jobs().doc(jobId).update(updates);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willReachMax
                ? 'Maximum bidding reached for this job.'
                : 'Searching for other technician.',
          ),
        ),
      );
    }
  }

  Future<void> _requestMoreBids(BuildContext context) async {
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('requestMoreBids').call({'jobId': jobId});
      final data = result.data as Map<String, dynamic>?;
      final count = data?['notifiedCount'] as int? ?? 0;
      final round = data?['bidRound'] as int? ?? 0;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Round $round: $count more technicians notified.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.code)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  static double _computeMaterialTotal(List<dynamic> materialList, {bool useTechBid = false, bool useDealerCounter = false}) {
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

}

class _TechnicianRejectionCardsSection extends StatelessWidget {
  const _TechnicianRejectionCardsSection({required this.history});
  final List<dynamic> history;

  @override
  Widget build(BuildContext context) {
    final list = history.map((e) => e is Map ? Map<String, dynamic>.from(Map.from(e)) : <String, dynamic>{}).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Job rejection list',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.error,
              ),
        ),
        const SizedBox(height: 12),
        ...list.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final ordinal = (r['ordinal'] as num?)?.toInt() ?? (i + 1);
          final dealerPrice = (r['dealerPrice'] as num?)?.toDouble() ?? 0.0;
          final technicianPrice = (r['technicianPrice'] as num?)?.toDouble() ?? 0.0;
          final lastPrice = (r['lastPrice'] as num?)?.toDouble() ?? 0.0;
          final reason = r['reason'] as String? ?? '—';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.red.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '$ordinal${_ordinalSuffix(ordinal)} technician rejected your job',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PriceRow(label: 'Your price (dealer)', value: '₹${dealerPrice.toStringAsFixed(0)}'),
                  _PriceRow(label: 'Technician price', value: '₹${technicianPrice.toStringAsFixed(0)}'),
                  _PriceRow(label: 'Last price', value: '₹${lastPrice.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  Text(
                    'Rejection reason: $reason',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _ordinalSuffix(int n) {
    if (n == 1) return 'st';
    if (n == 2) return 'nd';
    if (n == 3) return 'rd';
    return 'th';
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _MaterialPriceEditorRow extends StatefulWidget {
  const _MaterialPriceEditorRow({
    required this.index,
    required this.initialRate,
    required this.onRateChanged,
  });
  final int index;
  final double initialRate;
  final void Function(double) onRateChanged;

  @override
  State<_MaterialPriceEditorRow> createState() => _MaterialPriceEditorRowState();
}

class _MaterialPriceEditorRowState extends State<_MaterialPriceEditorRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRate.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_MaterialPriceEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRate != widget.initialRate &&
        _controller.text != widget.initialRate.toStringAsFixed(0)) {
      _controller.text = widget.initialRate.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitValue() {
    final val = double.tryParse(_controller.text.trim());
    if (val != null && val >= 0) widget.onRateChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Current: ', style: Theme.of(context).textTheme.titleSmall),
        IconButton.filledTonal(
          icon: const Icon(Icons.remove, size: 18),
          onPressed: () {
            final v = double.tryParse(_controller.text.trim()) ?? widget.initialRate;
            final newVal = (v - 1).clamp(0.0, double.infinity).toDouble();
            _controller.text = newVal.toStringAsFixed(0);
            widget.onRateChanged(newVal);
          },
          style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(36, 36)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: '₹', isDense: true),
            onSubmitted: (_) => _submitValue(),
            onTapOutside: (_) => _submitValue(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: const Icon(Icons.add, size: 18),
          onPressed: () {
            final v = double.tryParse(_controller.text.trim()) ?? widget.initialRate;
            final newVal = v + 1;
            _controller.text = newVal.toStringAsFixed(0);
            widget.onRateChanged(newVal);
          },
          style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(36, 36)),
        ),
      ],
    );
  }
}

class _InlineMaterialListWithPriceEditor extends StatelessWidget {
  const _InlineMaterialListWithPriceEditor({
    super.key,
    required this.jobId,
    required this.materialList,
    required this.canEditPrice,
  });
  final String jobId;
  final List<dynamic> materialList;
  final bool canEditPrice;

  double _getEffectiveRate(Map<String, dynamic> m) =>
      (m['dealerCounterRate'] as num?)?.toDouble() ??
      (m['technicianBidRate'] as num?)?.toDouble() ??
      (m['rate'] as num?)?.toDouble() ??
      0.0;

  Future<void> _updateItemRate(BuildContext context, int index, double newRate) async {
    if (newRate < 0) return;
    final newMaterialList = <Map<String, dynamic>>[];
    for (var i = 0; i < materialList.length; i++) {
      final item = Map<String, dynamic>.from(
        materialList[i] is Map ? Map.from(materialList[i] as Map) : <String, dynamic>{},
      );
      final rate = i == index ? newRate : _getEffectiveRate(item);
      if (i == index) item['dealerCounterRate'] = newRate;
      item['amount'] = ((item['qty'] as num?)?.toInt() ?? 1) * rate;
      newMaterialList.add(item);
    }
    await FirestoreService.jobs().doc(jobId).update({'materialList': newMaterialList});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Material list', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Icon(Icons.lock_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                Text(' Item & qty locked', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            ...materialList.asMap().entries.map((e) {
              final m = e.value is Map ? (e.value as Map).cast<String, dynamic>() : <String, dynamic>{};
              final slNo = (m['slNo'] as num?)?.toInt() ?? (e.key + 1);
              final itemName = m['itemName'] as String? ?? 'Item';
              final qty = (m['qty'] as num?)?.toInt() ?? 1;
              final rate = _getEffectiveRate(m);
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
                          'Posted: ₹${((m['rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 8),
                        canEditPrice
                            ? _MaterialPriceEditorRow(
                                index: e.key,
                                initialRate: rate,
                                onRateChanged: (r) => _updateItemRate(context, e.key, r),
                              )
                            : Row(
                                children: [
                                  Text('Current: ₹${rate.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleSmall),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TechnicianAcceptedWaitingForBidCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade700)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 1500.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 16),
            Text(
              'Technician accepted your job. Waiting for bid.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchingForTechnicianCard extends StatefulWidget {
  @override
  State<_SearchingForTechnicianCard> createState() => _SearchingForTechnicianCardState();
}

class _SearchingForTechnicianCardState extends State<_SearchingForTechnicianCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 48, color: Colors.blue.shade700)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final dotCount = ((_controller.value * 4) % 4).floor();
                final dots = '.' * dotCount;
                return Text(
                  'Searching for technician$dots',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

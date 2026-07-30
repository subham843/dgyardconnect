import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/route_names.dart';
import '../../core/utils/address_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/job_model.dart';
import '../../shared/models/service_completion_record_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/profile_card_dealer.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import '../../core/theme/technician_ui_tokens.dart';
import '../shared/chat_screen.dart' as shared_chat;

bool _hasSiteContact(Map<String, dynamic>? data) {
  if (data == null) return false;
  final phone = data['siteContactPhone'] as String?;
  return phone != null && phone.trim().isNotEmpty;
}

bool _shouldShowFullAddress(JobStatus status) =>
    status == JobStatus.paid ||
    status == JobStatus.inProgress ||
    status == JobStatus.completed ||
    status == JobStatus.pendingDealerConfirm;

bool _showMaterialInfo(JobStatus status, Map<String, dynamic>? data) {
  if (data == null) return false;
  final opt = data['materialOption'] as String?;
  if (opt == null || opt == 'no_pickup') return false;
  return status == JobStatus.paid || status == JobStatus.inProgress;
}

class TechnicianJobDetailScreen extends StatelessWidget {
  const TechnicianJobDetailScreen({super.key, required this.jobId});
  final String jobId;

  Future<void> _initiateCall(BuildContext context, String jobId, {bool callDealer = false}) async {
    if (Firebase.apps.isEmpty) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting...')),
      );
      final params = <String, dynamic>{'jobId': jobId};
      if (callDealer) params['target'] = 'dealer';
      final result = await FirebaseFunctions.instance.httpsCallable('initMaskedCall').call(params);
      if (context.mounted) {
        final msg = (result.data is Map && (result.data as Map)['message'] != null)
            ? (result.data as Map)['message'] as String
            : 'Call initiated.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e')),
        );
      }
    }
  }

  Future<void> _openInMaps(BuildContext context, String? address) async {
    final q = (address ?? '').trim();
    if (q.isEmpty) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: const TechnicianGlassAppBar(title: 'Job detail'),
        body: const TechnicianGlassBackground(
          child: Center(child: Text('Firebase is not configured.')),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Job detail',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.technicianMyJobs),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('Job not found.'));
          }
          final job = JobModel.fromFirestore(doc);
          final jobData = doc.data();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _JobHeroCard(job: job),
                if (job.isEmergency)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Chip(label: Text('Emergency'), backgroundColor: Colors.orange),
                  ),
                const SizedBox(height: 16),
                TechnicianGlassCard(
                  radius: 20,
                  blurSigma: 28,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    job.description ?? '—',
                    style: TechnicianUiTokens.textSubhead(),
                  ),
                ),
                if (job.lastRejectionReason != null && job.lastRejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TechnicianGlassCard(
                    radius: 18,
                    blurSigma: 24,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last rejection (${job.lastRejectedBy ?? "—"})',
                          style: TechnicianUiTokens.textCaption1(color: TechnicianUiTokens.labelPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(job.lastRejectionReason!, style: TechnicianUiTokens.textCaption1()),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (job.dealerId.isNotEmpty) ...[
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirestoreService.users().doc(job.dealerId).snapshots(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                      final d = userSnap.data!.data() ?? {};
                      final profile = d['profile'] as Map<String, dynamic>?;
                      return ProfileCardDealer(
                        name: profile?['name'] as String?,
                        level: d['dealerLevel'] as String?,
                        rating: (d['avgRating'] as num?)?.toDouble(),
                        jobsPosted: d['totalJobsCompleted'] as int?,
                        paymentSpeed: 'Fast',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TechnicianGlassCard(
                  radius: 20,
                  blurSigma: 28,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Address', style: TechnicianUiTokens.textCaption1()),
                      const SizedBox(height: 8),
                      Text(
                        _shouldShowFullAddress(job.status)
                            ? (job.address ?? '—')
                            : maskAddressToArea(job.address),
                        style: TechnicianUiTokens.textSubhead(color: TechnicianUiTokens.labelPrimary),
                      ),
                      const SizedBox(height: 12),
                      _PremiumWideButton(
                        label: 'Open in Maps',
                        icon: Icons.location_on_outlined,
                        filled: false,
                        onTap: () => _openInMaps(context, job.address),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (job.status == JobStatus.pendingDealerConfirm && jobData != null) ...[
                  _JobSummaryCard(jobData: jobData),
                  const SizedBox(height: 16),
                ],
                if (jobData != null && _showMaterialInfo(job.status, jobData)) ...[
                  const SizedBox(height: 12),
                  _MaterialInfoCard(jobData: jobData),
                ],
                TechnicianGlassCard(
                  radius: 18,
                  blurSigma: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: _Row(
                    label: 'Your payout',
                    value: '₹${job.technicianPayoutAmount ?? job.agreedAmount ?? 0}',
                  ),
                ),
                const SizedBox(height: 10),
                if (job.status == JobStatus.bidding && job.biddingEnabled)
                  _PremiumWideButton(
                    label: 'Bidding',
                    icon: Icons.gavel_rounded,
                    onTap: () => context.push('/technician/jobs/$jobId/bidding'),
                  ),
                if (job.status == JobStatus.paymentPending)
                  TechnicianGlassCard(
                    radius: 18,
                    blurSigma: 24,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: Colors.amber.shade800),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Waiting for payment',
                            style: TechnicianUiTokens.textHeadline(),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (job.status == JobStatus.paid || job.status == JobStatus.inProgress)
                  _PremiumWideButton(
                    label: job.status == JobStatus.inProgress ? 'Continue job' : 'Start job',
                    icon: Icons.play_arrow_rounded,
                    onTap: () {
                      final data = jobData ?? {};
                      final materialReturn = data['materialReturnRequested'] == true;
                      final hasHandover = data['materialHandoverLocation'] != null;
                      final jobComplete = (data['status'] as String?) == 'pending_dealer_confirm' ||
                          (data['status'] as String?) == 'completed';
                      final proofPhotos = (data['proofPhotos'] as List<dynamic>?) ?? [];
                      final hasAfterImages = proofPhotos.any((p) => (p as Map)['type'] == 'after');

                      if (materialReturn && hasHandover && !jobComplete) {
                        context.push('/technician/jobs/$jobId/material-return');
                      } else if (materialReturn && hasHandover && jobComplete) {
                        context.push('/technician/jobs/$jobId/execute');
                      } else if (hasAfterImages) {
                        context.push('/technician/jobs/$jobId/finish');
                      } else {
                        context.push('/technician/jobs/$jobId/execute');
                      }
                    },
                  ),
                if (job.status == JobStatus.completed) ...[
                  _TechnicianServiceRecordCard(jobId: jobId),
                  const SizedBox(height: 12),
                  if ((jobData?['technicianRatingToDealer'] != null) ||
                      (jobData?['dealerRatingToTechnician'] != null))
                    _RatingDisplayCard(
                      rating: (jobData?['technicianRatingToDealer'] ?? jobData?['dealerRatingToTechnician']) as num?,
                      review: (jobData?['technicianReviewToDealer'] ?? jobData?['dealerReviewToTechnician']) as String?,
                      label: jobData?['technicianRatingToDealer'] != null
                          ? 'Your rating'
                          : 'Dealer rated you',
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => context.push('/technician/jobs/$jobId/rate'),
                      icon: const Icon(Icons.star),
                      label: const Text('Rate dealer'),
                    ),
                ],
                if (job.status == JobStatus.pendingDealerConfirm) ...[
                  if (job.dealerApprovalDeadline != null)
                    _TechnicianApprovalCountdown(deadline: job.dealerApprovalDeadline!),
                  if (job.dealerId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PremiumWideButton(
                        label: 'Call dealer',
                        icon: Icons.phone,
                        filled: false,
                        onTap: () => _initiateCall(context, jobId, callDealer: true),
                      ),
                    ),
                ]
                else if ((job.status == JobStatus.paid || job.status == JobStatus.inProgress) &&
                    _hasSiteContact(jobData))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PremiumWideButton(
                      label: 'Call customer',
                      icon: Icons.phone,
                      filled: false,
                      onTap: () => _initiateCall(context, jobId),
                    ),
                  ),
                if (job.status == JobStatus.paid ||
                    job.status == JobStatus.inProgress ||
                    job.status == JobStatus.pendingDealerConfirm)
                  _PremiumWideButton(
                    label: 'Chat',
                    icon: Icons.chat_outlined,
                    filled: false,
                    onTap: () => shared_chat.showChatPopup(context, jobId),
                  ),
              ],
            ),
          );
        },
      )),
    );
  }
}

String _pickupAddressToArea(String? addr) {
  if (addr == null || addr.trim().isEmpty) return '—';
  final parts = addr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return addr;
  if (parts.length <= 2) return addr;
  return parts.sublist(parts.length - 2).join(', ');
}

class _JobSummaryCard extends StatelessWidget {
  const _JobSummaryCard({required this.jobData});
  final Map<String, dynamic> jobData;

  @override
  Widget build(BuildContext context) {
    final started = (jobData['jobStartedAt'] as Timestamp?)?.toDate();
    final completed = (jobData['completedAt'] as Timestamp?)?.toDate();
    final totalTravelKm = (jobData['totalTravelKm'] as num?)?.toDouble();
    final payout = (jobData['technicianPayoutAmount'] as num?)?.toDouble() ??
        (jobData['agreedAmount'] as num?)?.toDouble() ??
        0.0;
    final travelExpense = (jobData['travelExpenseAmount'] as num?)?.toDouble();
    final warrantyDays = (jobData['warrantyPeriodDays'] as num?)?.toInt() ??
        (jobData['warrantyPeriod'] as num?)?.toInt() ??
        30;

    final totalDuration = (started != null && completed != null)
        ? completed.difference(started)
        : null;
    final availablePart = payout * 0.8;
    final heldPart = payout * 0.2;
    final travelAmt = travelExpense ?? 0.0;
    final withdrawableNow = availablePart + travelAmt;
    final withdrawableAfterWarranty = heldPart;
    final totalToWallet = payout + travelAmt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _summaryRow('Job started', AppDateUtils.formatDateTime(started)),
            _summaryRow('Job completed', AppDateUtils.formatDateTime(completed)),
            _summaryRow('Total time', totalDuration != null ? AppDateUtils.formatDuration(totalDuration) : '—'),
            _summaryRow('Total travel', totalTravelKm != null ? '${totalTravelKm.toStringAsFixed(1)} km' : '—'),
            const Divider(height: 20),
            _summaryRow('Amount to wallet', '₹${totalToWallet.toStringAsFixed(0)}${travelExpense == null && (totalTravelKm ?? 0) > 15 ? ' (+ travel after confirm)' : ''}'),
            _summaryRow('Warranty deduction (20%)', '₹${heldPart.toStringAsFixed(0)}'),
            _summaryRow('Withdrawable now', '₹${withdrawableNow.toStringAsFixed(0)}${travelExpense == null && (totalTravelKm ?? 0) > 15 ? ' (+ travel)' : ''}'),
            _summaryRow('Withdrawable after warranty', '₹${withdrawableAfterWarranty.toStringAsFixed(0)}'),
            _summaryRow('Remaining withdrawable in', '$warrantyDays days'),
            _summaryRow('Warranty period', '$warrantyDays days'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _MaterialInfoCard extends StatelessWidget {
  const _MaterialInfoCard({required this.jobData});
  final Map<String, dynamic> jobData;

  @override
  Widget build(BuildContext context) {
    final opt = jobData['materialOption'] as String?;
    if (opt == 'pickup') {
      final addr = jobData['pickupAddress'] as String? ?? '—';
      final area = _pickupAddressToArea(addr);
      final list = jobData['pickupMaterialList'] as List<dynamic>? ?? [];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup material', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(area, style: Theme.of(context).textTheme.bodyMedium),
              if (list.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Material list', style: Theme.of(context).textTheme.titleSmall),
                ...list.map((e) {
                  final m = e as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${m['slNo'] ?? ''}. ${m['itemName'] ?? ''} × ${m['qty'] ?? 1}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      );
    }
    if (opt == 'material_by_technician') {
      final list = jobData['materialList'] as List<dynamic>? ?? [];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Material by technician', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Text('No items', style: Theme.of(context).textTheme.bodySmall)
              else
                ...list.map((e) {
                  final m = e as Map<String, dynamic>;
                  final amt = (m['amount'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${m['itemName'] ?? ''} × ${m['qty'] ?? 1} @ ₹${m['rate'] ?? 0} = ₹${amt.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _TechnicianServiceRecordCard extends StatelessWidget {
  const _TechnicianServiceRecordCard({required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.serviceCompletionRecords()
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final record = ServiceCompletionRecordModel.fromFirestore(snapshot.data!.docs.first);
        return TechnicianGlassCard(
          radius: 20,
          blurSigma: 28,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service Record', style: TechnicianUiTokens.textTitle2()),
              const SizedBox(height: 12),
              _ServiceInfoRow(icon: Icons.badge_outlined, label: 'Record ID', value: record.displayRecordId),
              _ServiceInfoRow(icon: Icons.tag_outlined, label: 'Job ID', value: record.displayJobId),
              _ServiceInfoRow(icon: Icons.build_circle_outlined, label: 'Service type', value: record.serviceType ?? '—'),
              _ServiceInfoRow(
                icon: Icons.event_outlined,
                label: 'Completion date',
                value: record.completionDate != null
                    ? '${record.completionDate!.day}/${record.completionDate!.month}/${record.completionDate!.year}'
                    : '—',
              ),
              _ServiceInfoRow(icon: Icons.verified_outlined, label: 'Warranty status', value: record.warrantyStatusLabel),
              const SizedBox(height: 12),
              _PremiumWideButton(
                label: 'View record',
                icon: Icons.visibility_outlined,
                onTap: () => context.push(RouteNames.technicianServiceRecord(jobId)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RatingDisplayCard extends StatelessWidget {
  const _RatingDisplayCard({
    required this.rating,
    required this.review,
    required this.label,
  });
  final num? rating;
  final String? review;
  final String label;

  @override
  Widget build(BuildContext context) {
    final stars = rating != null ? rating!.toInt() : 0;
    final score = (rating ?? 0).toDouble();
    return TechnicianGlassCard(
      radius: 20,
      blurSigma: 26,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TechnicianUiTokens.textTitle2()),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFFFB020),
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${score.toStringAsFixed(1)} Excellent service',
            style: TechnicianUiTokens.textCaption1(color: TechnicianUiTokens.labelPrimary),
          ),
          if (review != null && review!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review!, style: TechnicianUiTokens.textSubhead()),
          ],
        ],
      ),
    );
  }
}

class _TechnicianApprovalCountdown extends StatefulWidget {
  const _TechnicianApprovalCountdown({required this.deadline});
  final DateTime deadline;

  @override
  State<_TechnicianApprovalCountdown> createState() => _TechnicianApprovalCountdownState();
}

class _TechnicianApprovalCountdownState extends State<_TechnicianApprovalCountdown> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = widget.deadline.difference(now);
    if (remaining.isNegative) {
      return Card(
        color: Colors.orange.shade50,
        margin: const EdgeInsets.only(bottom: 12),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Dealer approval window passed. Auto payment release shortly.'),
        ),
      );
    }
    final minutes = remaining.inMinutes;
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Dealer approval pending. Auto payment release in $minutes minute${minutes == 1 ? '' : 's'}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _JobHeroCard extends StatelessWidget {
  const _JobHeroCard({required this.job});
  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final payout = (job.technicianPayoutAmount ?? job.agreedAmount ?? 0).toDouble();
    final (status, color) = _statusPill(job.status);
    return TechnicianGlassCard(
      radius: 24,
      blurSigma: 30,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TechnicianUiTokens.accentSoft,
            ),
            child: Icon(_heroIcon(job), color: TechnicianUiTokens.accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title?.trim().isNotEmpty == true ? job.title!.trim() : 'Job Detail',
                  style: TechnicianUiTokens.textTitle1(),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Text(status, style: TechnicianUiTokens.textCaption1(color: color)),
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${payout.toStringAsFixed(0)}',
                  style: TechnicianUiTokens.textLargeTitle(color: TechnicianUiTokens.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceInfoRow extends StatelessWidget {
  const _ServiceInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: TechnicianUiTokens.labelTertiary),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(label, style: TechnicianUiTokens.textCaption2()),
          ),
          Expanded(
            child: Text(
              value,
              style: TechnicianUiTokens.textCaption1(color: TechnicianUiTokens.labelPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumWideButton extends StatelessWidget {
  const _PremiumWideButton({
    required this.label,
    required this.icon,
    this.filled = true,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: filled
                ? LinearGradient(
                    colors: [
                      TechnicianUiTokens.accent.withValues(alpha: 0.92),
                      TechnicianUiTokens.accent,
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.55),
            border: Border.all(
              color: filled ? Colors.white.withValues(alpha: 0.25) : TechnicianUiTokens.hairlineOnGlass,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : TechnicianUiTokens.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TechnicianUiTokens.textCaption1(
                  color: filled ? Colors.white : TechnicianUiTokens.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(String, Color) _statusPill(JobStatus status) {
  if (status == JobStatus.completed) return ('Completed', const Color(0xFF059669));
  if ({JobStatus.inProgress, JobStatus.pendingDealerConfirm, JobStatus.paid}.contains(status)) {
    return ('Running', const Color(0xFF2563EB));
  }
  return ('Pending', const Color(0xFFEA580C));
}

IconData _heroIcon(JobModel job) {
  final t = (job.title ?? '').toLowerCase();
  if (t.contains('cctv')) return Icons.videocam_outlined;
  if (t.contains('ac') || t.contains('air')) return Icons.ac_unit_rounded;
  return Icons.handyman_rounded;
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

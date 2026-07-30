import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

class AdminFraudAlertDetailScreen extends StatelessWidget {
  const AdminFraudAlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  static String _recommendationText({required String type, required double? risk}) {
    final r = (risk ?? 0).toInt();
    final band = r >= 85 ? 'High' : (r >= 70 ? 'Medium' : 'Low');
    final base = 'Risk: $band (${risk?.toStringAsFixed(0) ?? '—'}). ';
    switch (type) {
      case 'fake_completion':
        return '${base}Recommended: Add strike + apply penalty points; suspend if repeated or if evidence confirms.';
      case 'warranty_abuse':
        return '${base}Recommended: Apply penalty points; add strike if repeated; suspend for chronic failures.';
      case 'repeat_cancellation':
        return '${base}Recommended: Apply penalty points + warnings; add strike (tech) if after acceptance.';
      case 'duplicate_job':
        return '${base}Recommended: Mark reviewed; contact dealer; suspend only if repeated abuse.';
      default:
        return '${base}Recommended: Mark reviewed, check evidence, then enforce (penalty/strike/suspend) if confirmed.';
    }
  }

  static Future<void> _resolveWithAudit(
    BuildContext context,
    String alertId,
  ) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve fraud alert'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'Why resolved? What was checked?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('resolveFraudAlert').call({
        'alertId': alertId,
        'note': noteCtrl.text.trim(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resolved with audit.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  static Future<void> _addStrikeFromAlert(
    BuildContext context,
    String technicianId, {
    String? jobId,
    required String type,
  }) async {
    final reason = type == 'fake_completion'
        ? 'fake_completion_attempt'
        : (type == 'warranty_abuse' ? 'warranty_claim_failure' : 'dispute_loss');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add strike'),
        content: Text('Add a strike to this technician?\nReason: $reason'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add strike')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('addTechnicianStrike').call({
        'technicianId': technicianId,
        'reason': reason,
        'jobId': jobId,
        'strikeLevel': 1,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Strike added.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    }
  }

  static Future<void> _applyPenaltyFromAlert(
    BuildContext context, {
    String? dealerId,
    String? technicianId,
    String? fallbackUserId,
  }) async {
    final targetUid = technicianId ?? dealerId ?? fallbackUserId;
    if (targetUid == null) return;
    final isTech = technicianId != null || (dealerId == null && fallbackUserId != null);
    final pointsCtrl = TextEditingController(
      text: (() {
        // Best defaults
        if (technicianId != null) return '2';
        return '1';
      })(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply penalty points'),
        content: TextField(
          controller: pointsCtrl,
          keyboardType: const TextInputType.numberWithOptions(signed: false),
          decoration: const InputDecoration(labelText: 'Points (e.g., 1, 2, 5)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final pts = int.tryParse(pointsCtrl.text.trim());
    if (pts == null || pts < 0) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable(isTech ? 'applyTechnicianPenalty' : 'applyDealerPenalty')
          .call({'uid': targetUid, 'points': pts});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Penalty applied.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    }
  }

  static Future<void> _suspendFromAlert(
    BuildContext context, {
    String? dealerId,
    String? technicianId,
    String? fallbackUserId,
  }) async {
    final targetUid = technicianId ?? dealerId ?? fallbackUserId;
    if (targetUid == null) return;
    final daysCtrl = TextEditingController(text: '7');
    final reasonCtrl = TextEditingController(text: 'fraud_alert_enforcement');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: daysCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: false),
              decoration: const InputDecoration(labelText: 'Days (max 90 recommended)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Suspend')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final days = int.tryParse(daysCtrl.text.trim()) ?? 7;
    try {
      await FirebaseFunctions.instance.httpsCallable('suspendUser').call({
        'uid': targetUid,
        'days': days,
        'reason': reasonCtrl.text.trim(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User suspended.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    }
  }

  static Future<void> _reactivateFromAlert(
    BuildContext context, {
    String? dealerId,
    String? technicianId,
    String? fallbackUserId,
  }) async {
    final targetUid = technicianId ?? dealerId ?? fallbackUserId;
    if (targetUid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate user'),
        content: const Text('Clear suspension/block and set account active?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reactivate')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('reactivateUser').call({
        'uid': targetUid,
        'reason': 'reactivated_from_fraud_alert',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User reactivated.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fraud alert'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(RouteNames.adminFraudAlerts),
          ),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    final ref = FirestoreService.fraudAlerts().doc(alertId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud alert'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminFraudAlerts),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Alert not found.'));
          }
          final d = snapshot.data!.data() ?? {};
          final type = d['type'] as String? ?? 'unknown';
          final status = d['status'] as String? ?? 'open';
          final risk = (d['riskScore'] as num?)?.toDouble();
          final jobId = d['jobId'] as String?;
          final userId = d['userId'] as String?;
          final dealerId = d['dealerId'] as String?;
          final technicianId = d['technicianId'] as String?;
          final reason = d['reason'] as String?;
          final signals = (d['signals'] as Map?)?.cast<String, dynamic>();
          final createdAt = d['createdAt'] is Timestamp
              ? (d['createdAt'] as Timestamp).toDate()
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                type: type,
                status: status,
                risk: risk,
                jobId: jobId,
                userId: userId,
                createdAt: createdAt,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Quick links',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if ((technicianId ?? dealerId ?? userId) != null)
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          RouteNames.adminTrustScoreHistoryForUser(
                            (technicianId ?? dealerId ?? userId)!,
                          ),
                        ),
                        icon: const Icon(Icons.shield_rounded),
                        label: const Text('Trust history'),
                      ),
                    if (jobId != null && jobId.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          RouteNames.adminJobEvidenceView(jobId),
                        ),
                        icon: const Icon(Icons.folder_special_rounded),
                        label: const Text('Evidence'),
                      ),
                    if (jobId != null && jobId.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jobId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Job ID copied.')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy Job ID'),
                      ),
                    if ((technicianId ?? dealerId ?? userId) != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          final uid = (technicianId ?? dealerId ?? userId)!;
                          Clipboard.setData(ClipboardData(text: uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User ID copied.')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy User ID'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (reason != null && reason.trim().isNotEmpty)
                _InfoCard(
                  title: 'Reason',
                  child: Text(reason),
                ),
              if (signals != null && signals.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Signals',
                  child: Text(signals.toString()),
                ),
              ],
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Recommended action',
                child: Text(_recommendationText(type: type, risk: risk)),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Actions',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if ((dealerId ?? technicianId ?? userId) != null && status != 'resolved')
                      FilledButton.icon(
                        onPressed: () async {
                          // One-click: apply penalty + resolve with audit note
                          await _applyPenaltyFromAlert(
                            context,
                            dealerId: dealerId,
                            technicianId: technicianId,
                            fallbackUserId: userId,
                          );
                          await _resolveWithAudit(context, alertId);
                        },
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: const Text('Penalty + Resolve'),
                      ),
                    FilledButton.icon(
                      onPressed: status == 'open'
                          ? () => ref.update({'status': 'reviewed'})
                          : null,
                      icon: const Icon(Icons.fact_check_rounded),
                      label: const Text('Mark reviewed'),
                    ),
                    FilledButton.icon(
                      onPressed: status != 'resolved'
                          ? () => _resolveWithAudit(context, alertId)
                          : null,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Resolve (audit)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: status != 'open'
                          ? () => ref.update({'status': 'open'})
                          : null,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Re-open'),
                    ),
                    if ((technicianId ?? userId) != null)
                      OutlinedButton.icon(
                        onPressed: () => _addStrikeFromAlert(
                          context,
                          technicianId ?? userId!,
                          jobId: jobId,
                          type: type,
                        ),
                        icon: const Icon(Icons.warning_amber_rounded),
                        label: const Text('Add strike'),
                      ),
                    if ((dealerId ?? technicianId ?? userId) != null)
                      OutlinedButton.icon(
                        onPressed: () => _applyPenaltyFromAlert(
                          context,
                          dealerId: dealerId,
                          technicianId: technicianId,
                          fallbackUserId: userId,
                        ),
                        icon: const Icon(Icons.gavel_rounded),
                        label: const Text('Penalty points'),
                      ),
                    if ((dealerId ?? technicianId ?? userId) != null)
                      FilledButton.icon(
                        onPressed: () => _suspendFromAlert(
                          context,
                          dealerId: dealerId,
                          technicianId: technicianId,
                          fallbackUserId: userId,
                        ),
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Suspend'),
                      ),
                    if ((dealerId ?? technicianId ?? userId) != null)
                      OutlinedButton.icon(
                        onPressed: () => _reactivateFromAlert(
                          context,
                          dealerId: dealerId,
                          technicianId: technicianId,
                          fallbackUserId: userId,
                        ),
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Reactivate'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Next (recommended)',
                child: const Text(
                  'Connect this screen to: user detail, job detail, audit logs, and enforcement actions '
                  '(penalty points, strikes, account suspension).',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.type,
    required this.status,
    required this.risk,
    required this.jobId,
    required this.userId,
    required this.createdAt,
  });

  final String type;
  final String status;
  final double? risk;
  final String? jobId;
  final String? userId;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type.replaceAll('_', ' ').toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(label: Text('STATUS: ${status.toUpperCase()}')),
                if (risk != null) Chip(label: Text('RISK: ${risk!.toStringAsFixed(0)}')),
              ],
            ),
            const SizedBox(height: 10),
            Text('Job: ${jobId ?? '—'}'),
            Text('User: ${userId ?? '—'}'),
            if (createdAt != null) Text('Created: ${_fmt(createdAt!)}'),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}


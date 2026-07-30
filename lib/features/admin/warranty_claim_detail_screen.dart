import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/warranty_claim_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminWarrantyClaimDetailScreen extends StatelessWidget {
  const AdminWarrantyClaimDetailScreen({super.key, required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Warranty claim')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    final claimRef = FirestoreService.warrantyClaims().doc(claimId);
    final dateFormat = DateFormat('d MMM y, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranty claim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: claimRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Claim not found.'));
          }
          final claim = WarrantyClaimModel.fromFirestore(snapshot.data!);
          final dealerRef = claim.dealerId.isNotEmpty ? FirestoreService.users().doc(claim.dealerId) : null;
          final techRef = claim.technicianId.isNotEmpty ? FirestoreService.users().doc(claim.technicianId) : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            claim.isResolved ? Icons.check_circle : Icons.schedule,
                            color: claim.isResolved ? AppColors.success : Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  claim.statusLabel,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (claim.claimTime != null)
                                  Text(
                                    dateFormat.format(claim.claimTime!),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Problem',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(claim.problemDescription),
                      if (claim.categoryTitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${claim.categoryTitle}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parties & job',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'Claim ID', value: claim.id),
                      _InfoRow(label: 'Job ID', value: claim.displayJobId),
                      if (dealerRef != null)
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: dealerRef.snapshots(),
                          builder: (context, s) {
                            final u = s.data != null && s.data!.exists ? UserModel.fromFirestore(s.data!) : null;
                            final label = u == null ? claim.dealerId : '${u.displayId} • ${u.displayName}';
                            return _InfoRow(label: 'Dealer', value: label);
                          },
                        )
                      else
                        _InfoRow(label: 'Dealer', value: '—'),
                      if (techRef != null)
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: techRef.snapshots(),
                          builder: (context, s) {
                            final u = s.data != null && s.data!.exists ? UserModel.fromFirestore(s.data!) : null;
                            final label = u == null ? claim.technicianId : '${u.displayId} • ${u.displayName}';
                            return _InfoRow(label: 'Technician', value: label);
                          },
                        )
                      else
                        _InfoRow(label: 'Technician', value: '—'),
                      if (claim.claimResponseDeadline != null)
                        _InfoRow(label: 'Response deadline', value: dateFormat.format(claim.claimResponseDeadline!)),
                      if (claim.technicianResponseStatus != null)
                        _InfoRow(label: 'Tech response', value: claim.technicianResponseStatus!),
                      if (claim.rejectionReason != null && claim.rejectionReason!.isNotEmpty)
                        _InfoRow(label: 'Rejection reason', value: claim.rejectionReason!),
                      if (claim.resolvedAt != null)
                        _InfoRow(label: 'Resolved at', value: dateFormat.format(claim.resolvedAt!)),
                      if (claim.holdPaymentAmount != null)
                        _InfoRow(label: 'Hold amount', value: '₹${claim.holdPaymentAmount!.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ),
              if (claim.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photos (${claim.photoUrls.length})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: claim.photoUrls.map((url) => _PhotoChip(url: url)).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push(RouteNames.adminJobDetail(claim.jobId)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open job'),
                  ),
                  if (claim.dealerId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => context.push(RouteNames.adminTrustScoreHistoryForUser(claim.dealerId)),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Dealer trust'),
                    ),
                  if (claim.technicianId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => context.push(RouteNames.adminTrustScoreHistoryForUser(claim.technicianId)),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Tech trust'),
                    ),
                ],
              ),
              if (!claim.isResolved) ...[
                const SizedBox(height: 24),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _closeClaim(context, claimId),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          label: const Text('Close claim (e.g. fraudulent)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _closeClaim(BuildContext context, String claimId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close claim'),
        content: const Text(
          'Mark this claim as closed? Use for fraudulent or invalid claims. The job warranty status will not be changed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, close claim'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirestoreService.warrantyClaims().doc(claimId).update({'claimStatus': 'closed'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim closed.')));
        context.pop();
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
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
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Could open URL in browser or full-screen image viewer
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 48)),
                const SizedBox(height: 8),
                SelectableText(url, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
          ),
        ),
      ),
    );
  }
}

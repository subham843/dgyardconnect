import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/firestore_service.dart';

/// Sellers inferred from recent listings + user status (suspension triggers catalog delist via Cloud Function).
class AdminMarketplaceSellersScreen extends StatelessWidget {
  const AdminMarketplaceSellersScreen({super.key});

  static List<String> _dedupeSellerUids(QuerySnapshot<Map<String, dynamic>> snap) {
    final seen = <String>{};
    final out = <String>[];
    for (final d in snap.docs) {
      final uid = (d.data()['seller_uid'] as String?)?.trim() ?? '';
      if (uid.isEmpty || seen.contains(uid)) continue;
      seen.add(uid);
      out.add(uid);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller registry')),
      body: !FirestoreService.isAvailable
          ? const Center(child: Text('Firebase is not configured.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.marketplaceListings().orderBy('updated_at', descending: true).limit(120).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('${snap.error}', textAlign: TextAlign.center)),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final uids = _dedupeSellerUids(snap.data!);
          if (uids.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No marketplace listings yet. When sellers submit drafts, they appear here by seller UID.\n\n'
                'Setting a user to Suspended updates users.marketplace_seller_status; Cloud Functions delist live catalog SKUs.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: uids.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final uid = uids[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  title: _SellerTitle(uid: uid),
                  subtitle: _SellerSubtitle(uid: uid),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openSellerSheet(context, uid),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openSellerSheet(BuildContext context, String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _SellerManageSheet(uid: uid),
      ),
    );
  }
}

class _SellerTitle extends StatelessWidget {
  const _SellerTitle({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return Text(uid, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14));
        }
        final u = UserModel.fromFirestore(snap.data!);
        return Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
      },
    );
  }
}

class _SellerSubtitle extends StatelessWidget {
  const _SellerSubtitle({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return Text(uid, style: Theme.of(context).textTheme.bodySmall);
        }
        final d = snap.data!.data() ?? {};
        final mp = (d['marketplace_seller_status'] as String?)?.trim() ?? '—';
        final trust = (d['trustScore'] as num?)?.toString() ?? '—';
        final role = d['role'] as String? ?? '';
        final short = uid.length > 10 ? '${uid.substring(0, 8)}…' : uid;
        return Text('UID · $short · $role · MP: $mp · trust: $trust',
            style: Theme.of(context).textTheme.bodySmall);
      },
    );
  }
}

class _SellerManageSheet extends StatefulWidget {
  const _SellerManageSheet({required this.uid});

  final String uid;

  @override
  State<_SellerManageSheet> createState() => _SellerManageSheetState();
}

class _SellerManageSheetState extends State<_SellerManageSheet> {
  String? _statusOverride;
  bool _saving = false;

  static const _options = ['none', 'pending', 'approved', 'suspended'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(widget.uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final fromServer = (data?['marketplace_seller_status'] as String?)?.trim();
        final serverNorm = (fromServer != null && _options.contains(fromServer)) ? fromServer : 'none';
        final effective = _statusOverride ?? serverNorm;
        final user = snap.hasData && snap.data!.exists ? UserModel.fromFirestore(snap.data!) : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Seller', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(user?.displayName ?? widget.uid, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('mp_seller_${widget.uid}_$effective'),
                initialValue: effective,
                decoration: const InputDecoration(
                  labelText: 'Marketplace seller status',
                  border: OutlineInputBorder(),
                ),
                items: _options
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _statusOverride = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await FirestoreService.users().doc(widget.uid).update({
                            'marketplace_seller_status': effective,
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: _saving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save status'),
              ),
              const Divider(height: 32),
              Text('Shortcuts', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(RouteNames.adminPendingApprovalDetail(widget.uid));
                },
                child: const Text('Open registration / KYC detail'),
              ),
              if (user?.role == AppRole.technician)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RouteNames.adminStrikeHistoryForTechnician(widget.uid));
                  },
                  child: const Text('Technician strikes'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(RouteNames.adminStrikes);
                },
                child: const Text('All strikes (admin)'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(RouteNames.adminFraudAlerts);
                },
                child: const Text('Fraud alerts'),
              ),
              const SizedBox(height: 8),
              Text(
                'Suspended → published catalog SKUs for this seller are set offline (Cloud Function).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }
}

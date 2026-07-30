import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/minimal_app_bar.dart';

void _showNotificationPopup(BuildContext context, {required String message, bool isError = false}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: isError ? AppColors.error : AppColors.brandWarmDark,
        size: 48,
      ),
      title: Text(isError ? 'Error' : 'Success'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Settlement Account screen for both Dealer and Technician.
/// Users can add and manage bank accounts, cards, and UPI (VPA) for payouts/refunds.
/// Verification is done via Razorpay.
class SettlementAccountScreen extends StatelessWidget {
  const SettlementAccountScreen({
    super.key,
    required this.backRoute,
  });

  final String backRoute;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: MinimalAppBar(
          title: 'Settlement Account',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go(backRoute),
          ),
        ),
        body: const Center(child: Text(AppConstants.signInRequired)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 10,
              12,
              16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                  onPressed: () => context.go(backRoute),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Settlement Account',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _glassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: AppColors.brandWarmDark, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Secured by Razorpay\nYour payments are 100% safe and encrypted',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.02, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 20),
            Text(
              'Your accounts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Primary account is used for withdrawals and refunds',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.settlementAccounts(uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Unable to load settlement accounts right now. Please check your connection and try again.',
                      style: TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                }
                final rawDocs = snapshot.data!.docs;
                final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(rawDocs)
                  ..sort((a, b) {
                    final aPrimary = a.data()['isPrimary'] as bool? ?? false;
                    final bPrimary = b.data()['isPrimary'] as bool? ?? false;
                    return (bPrimary ? 1 : 0) - (aPrimary ? 1 : 0);
                  });
                if (docs.isEmpty) {
                  return _glassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
                              ),
                            ),
                            child: const Icon(Icons.account_balance_wallet_outlined, size: 38, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No payment methods added',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a bank account or UPI to receive payouts instantly',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn();
                }
                return Column(
                  children: docs.asMap().entries.map((e) {
                    final doc = e.value;
                    final data = doc.data();
                    final index = e.key;
                    return _AccountCard(
                      docId: doc.id,
                      uid: uid,
                      data: data,
                      backRoute: backRoute,
                    )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: index * 50))
                        .slideX(begin: 0.03, end: 0, curve: Curves.easeOut);
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            _PrimaryCtaButton(
              label: 'Add Bank Account (Recommended)',
              icon: Icons.account_balance_rounded,
              onTap: () => _showAddBankSheet(context, uid),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddUpiSheet(context, uid),
                    icon: const Icon(Icons.phone_android, size: 20),
                    label: const Text('Add UPI'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandWarmDark,
                      side: BorderSide(color: AppColors.brandWarmLight.withValues(alpha: 0.9)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddCardSheet(context, uid),
                    icon: const Icon(Icons.credit_card_rounded, size: 20),
                    label: const Text('Add Card'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandWarmDark,
                      side: BorderSide(color: AppColors.brandWarmLight.withValues(alpha: 0.9)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  static void _showAddBankSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddBankSheet(uid: uid),
    );
  }

  static void _showAddUpiSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddUpiSheet(uid: uid),
    );
  }

  static void _showAddCardSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddCardSheet(uid: uid),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.docId,
    required this.uid,
    required this.data,
    required this.backRoute,
  });

  final String docId;
  final String uid;
  final Map<String, dynamic> data;
  final String backRoute;

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'bank_account';
    final status = data['status'] as String? ?? 'pending';
    final isPrimary = data['isPrimary'] as bool? ?? false;
    final isBank = type == 'bank_account';
    final isCard = type == 'card';

    String title;
    String subtitle;
    IconData icon;
    if (isBank) {
      final name = data['accountHolderName'] as String? ?? '—';
      final bankName = data['bankName'] as String? ?? '';
      final masked = _maskAccount(data['accountNumber'] as String? ?? '');
      title = name;
      subtitle = bankName.isNotEmpty ? '$bankName • $masked' : masked;
      icon = Icons.account_balance;
    } else if (isCard) {
      final brand = (data['cardBrand'] as String? ?? 'Card').toUpperCase();
      final last4 = data['cardLast4'] as String? ?? '****';
      title = '$brand card';
      subtitle = '**** **** **** $last4';
      icon = Icons.credit_card_rounded;
    } else {
      final vpa = data['vpa'] as String? ?? '—';
      title = 'UPI';
      subtitle = vpa;
      icon = Icons.phone_android;
    }

    final statusColor = status == 'verified'
        ? AppColors.brandWarmDark
        : status == 'failed'
            ? AppColors.error
            : status == 'created'
                ? AppColors.brandWarmLight
                : AppColors.brandWarmSoft;
    final statusLabel = status == 'verified'
        ? 'Verified'
        : status == 'failed'
            ? 'Failed'
            : status == 'created'
                ? 'Ready'
                : 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: (isBank
                  ? AppColors.brandWarmLight
                  : isCard
                      ? AppColors.brandWarmSoft
                      : AppColors.brandWarmDark)
              .withValues(alpha: 0.15),
          child: Icon(
            icon,
            color: isBank
                ? AppColors.brandWarmDark
                : isCard
                    ? AppColors.brandWarmSoft
                    : AppColors.brandWarmDark,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isPrimary ? AppColors.brandWarmLight.withValues(alpha: 0.22) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isPrimary ? 'Primary' : 'Secondary',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPrimary ? AppColors.brandWarmDark : Colors.grey.shade700),
              ),
            ),
          ],
        ),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
            ),
            if (status == 'failed' || status == 'pending')
              TextButton(
                onPressed: () => _retryValidation(context, uid, docId),
                child: Text(status == 'failed' ? 'Retry' : 'Verify', style: const TextStyle(fontSize: 12)),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'set_primary') {
                  await _setAsPrimary(context, uid, docId);
                } else if (v == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Remove account?'),
                      content: const Text('This account will be removed from your settlement options.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final wasPrimary = isPrimary;
                    await FirestoreService.settlementAccounts(uid).doc(docId).delete();
                    if (wasPrimary) {
                      final remaining = await FirestoreService.settlementAccounts(uid).get();
                      if (remaining.docs.isNotEmpty) {
                        await remaining.docs.first.reference.update({'isPrimary': true});
                        await FirestoreService.users().doc(uid).set(
                          {'primarySettlementAccountId': remaining.docs.first.id},
                          SetOptions(merge: true),
                        );
                      } else {
                        await FirestoreService.users().doc(uid).set(
                          {'primarySettlementAccountId': FieldValue.delete()},
                          SetOptions(merge: true),
                        );
                      }
                    }
                    if (context.mounted) {
                      _showNotificationPopup(context, message: 'Account removed');
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                if (!isPrimary)
                  const PopupMenuItem(value: 'set_primary', child: Text('Set as primary')),
                const PopupMenuItem(value: 'delete', child: Text('Remove account')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _maskAccount(String s) {
    if (s.length < 4) return '****';
    return '****${s.substring(s.length - 4)}';
  }

  static Future<void> _setAsPrimary(BuildContext context, String uid, String docId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final accountsSnap = await FirestoreService.settlementAccounts(uid).get();
      for (final doc in accountsSnap.docs) {
        batch.update(doc.reference, {'isPrimary': doc.id == docId});
      }
      batch.set(
        FirestoreService.users().doc(uid),
        {'primarySettlementAccountId': docId},
        SetOptions(merge: true),
      );
      await batch.commit();
      if (context.mounted) {
        _showNotificationPopup(
          context,
          message: 'Primary account updated. Withdrawals and refunds will use this account.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showNotificationPopup(context, message: '${AppConstants.errorGeneric} $e', isError: true);
      }
    }
  }

  static Future<void> _retryValidation(BuildContext context, String uid, String docId) async {
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('validateSettlementAccount').call({'accountId': docId});
      if (context.mounted) {
        final data = result.data as Map<String, dynamic>?;
        _showNotificationPopup(context, message: data?['message'] as String? ?? 'Verification initiated');
      }
    } catch (e) {
      if (context.mounted) {
        _showNotificationPopup(context, message: '${AppConstants.errorGeneric} $e', isError: true);
      }
    }
  }
}

Widget _glassCard({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: child,
      ),
    ),
  );
}

class _PrimaryCtaButton extends StatefulWidget {
  const _PrimaryCtaButton({
    required this.label,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  State<_PrimaryCtaButton> createState() => _PrimaryCtaButtonState();
}

class _PrimaryCtaButtonState extends State<_PrimaryCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 130),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandWarmSoft.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBankSheet extends StatefulWidget {
  const _AddBankSheet({required this.uid});

  final String uid;

  @override
  State<_AddBankSheet> createState() => _AddBankSheetState();
}

class _AddBankSheetState extends State<_AddBankSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final existing = await FirestoreService.settlementAccounts(widget.uid).get();
      final isFirst = existing.docs.isEmpty;
      final created = await FirestoreService.settlementAccounts(widget.uid).add({
        'type': 'bank_account',
        'accountHolderName': _nameController.text.trim(),
        'accountNumber': _accountController.text.trim().replaceAll(' ', ''),
        'ifsc': _ifscController.text.trim().toUpperCase(),
        'bankName': '', // Will be fetched by Razorpay/Cloud Function
        'status': 'pending',
        'isPrimary': isFirst,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (isFirst) {
        await FirestoreService.users().doc(widget.uid).set(
          {'primarySettlementAccountId': created.id},
          SetOptions(merge: true),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        _showNotificationPopup(context, message: 'Bank account added. Verification will be initiated.');
      }
    } catch (e) {
      if (mounted) {
        _showNotificationPopup(context, message: '${AppConstants.errorGeneric} $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Bank Account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                  hintText: 'As per bank records',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'Account number',
                  hintText: 'Enter account number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.replaceAll(' ', '').length < 9) return 'Invalid account number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ifscController,
                decoration: const InputDecoration(
                  labelText: 'IFSC code',
                  hintText: 'e.g. HDFC0001234',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length != 11) return 'IFSC must be 11 characters';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddUpiSheet extends StatefulWidget {
  const _AddUpiSheet({required this.uid});

  final String uid;

  @override
  State<_AddUpiSheet> createState() => _AddUpiSheetState();
}

class _AddUpiSheetState extends State<_AddUpiSheet> {
  final _formKey = GlobalKey<FormState>();
  final _vpaController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _vpaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vpa = _vpaController.text.trim().toLowerCase();
    setState(() => _saving = true);
    try {
      final existing = await FirestoreService.settlementAccounts(widget.uid).get();
      final isFirst = existing.docs.isEmpty;
      final created = await FirestoreService.settlementAccounts(widget.uid).add({
        'type': 'vpa',
        'vpa': vpa,
        'status': 'pending',
        'isPrimary': isFirst,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (isFirst) {
        await FirestoreService.users().doc(widget.uid).set(
          {'primarySettlementAccountId': created.id},
          SetOptions(merge: true),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        _showNotificationPopup(context, message: 'UPI account added. Verification will be initiated.');
      }
    } catch (e) {
      if (mounted) {
        _showNotificationPopup(context, message: '${AppConstants.errorGeneric} $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add UPI ID', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _vpaController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'e.g. name@paytm, name@ybl, name@phonepe, name@okaxis',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final trimmed = v.trim().toLowerCase();
                  if (!trimmed.contains('@')) return 'Enter valid UPI ID (e.g. name@paytm)';
                  final parts = trimmed.split('@');
                  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return 'Enter valid UPI ID';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add UPI'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet({required this.uid});

  final String uid;

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardHolderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final raw = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final last4 = raw.substring(raw.length - 4);
    final first = raw.isNotEmpty ? raw[0] : '';
    final brand = first == '4'
        ? 'visa'
        : (first == '5'
            ? 'mastercard'
            : (first == '3' ? 'amex' : 'card'));

    setState(() => _saving = true);
    try {
      final existing = await FirestoreService.settlementAccounts(widget.uid).get();
      final isFirst = existing.docs.isEmpty;
      final created = await FirestoreService.settlementAccounts(widget.uid).add({
        'type': 'card',
        'cardHolderName': _cardHolderController.text.trim(),
        'cardLast4': last4,
        'cardBrand': brand,
        'cardExpiry': _expiryController.text.trim(),
        'status': 'pending',
        'isPrimary': isFirst,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (isFirst) {
        await FirestoreService.users().doc(widget.uid).set(
          {'primarySettlementAccountId': created.id},
          SetOptions(merge: true),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        _showNotificationPopup(
          context,
          message: 'Card added. Verification will be initiated via Razorpay.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showNotificationPopup(
          context,
          message: '${AppConstants.errorGeneric} $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Card', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _cardHolderController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Card holder name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Card number',
                  hintText: '16 digits',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) return 'Required';
                  if (digits.length < 12 || digits.length > 19) return 'Invalid card number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry (MM/YY)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Required';
                  if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(t)) return 'Use MM/YY';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add card'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

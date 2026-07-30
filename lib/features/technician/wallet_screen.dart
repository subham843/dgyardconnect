import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

class TechnicianWalletScreen extends StatefulWidget {
  const TechnicianWalletScreen({super.key});

  @override
  State<TechnicianWalletScreen> createState() => _TechnicianWalletScreenState();
}

class _TechnicianWalletScreenState extends State<TechnicianWalletScreen> {
  double _lastAvailableBalance = 0;
  bool _seeded = false;

  Future<void> _requestWithdrawal(BuildContext context, double available) async {
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No balance available to withdraw.')),
      );
      return;
    }
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: available.toStringAsFixed(0));
        return AlertDialog(
          title: const Text('Withdraw'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              hintText: 'Enter amount',
            ),
            onChanged: (_) {},
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text);
                if (v != null && v > 0 && v <= available) {
                  Navigator.of(ctx).pop(v);
                }
              },
              child: const Text('Request'),
            ),
          ],
        );
      },
    );
    if (amount == null || !context.mounted) return;
    try {
      if (Firebase.apps.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppConstants.withdrawNotAvailable)),
          );
        }
        return;
      }
      final result = await FirebaseFunctions.instance
          .httpsCallable('requestWithdrawal')
          .call({'amount': amount});
      final data = result.data as Map<dynamic, dynamic>?;
      if (!context.mounted) return;
      if (data != null && data['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal requested successfully.')),
        );
        return;
      }
      final reason = data?['reason'] as String?;
      final message = data?['message'] as String?;
      final displayMsg = message ?? (reason == 'no_settlement_account' || reason == 'account_not_verified'
          ? 'Add and verify a settlement account, set one as primary.'
          : AppConstants.withdrawNotAvailable);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(displayMsg)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal failed: $e')),
        );
      }
    }
  }

  Future<void> _refreshWallet(String uid) async {
    await FirestoreService.wallets().doc(uid).get(
          const GetOptions(source: Source.server),
        );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: TechnicianGlassAppBar(
          title: 'Wallet',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go(RouteNames.technicianHome),
          ),
        ),
        body: const TechnicianGlassBackground(
          child: Center(child: Text(AppConstants.signInRequired)),
        ),
        ),
      );
    }
    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Wallet',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.technicianHome),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.wallets().doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.brandWarmLight, strokeWidth: 2),
            );
          }
          final doc = snapshot.data!;
          final available = (doc.data()?['availableBalance'] as num?)?.toDouble() ?? 0.0;
          final held = (doc.data()?['heldBalance'] as num?)?.toDouble() ?? 0.0;
          final holds = doc.data()?['holds'] as List<dynamic>? ?? [];
          final txns = (doc.data()?['recentTransactions'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (!_seeded) {
            _lastAvailableBalance = available;
            _seeded = true;
          }
          return RefreshIndicator(
            onRefresh: () => _refreshWallet(uid),
            color: AppColors.brandWarmDark,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandWarmSoft.withValues(alpha: 0.26),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Balance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        key: ValueKey<double>(available),
                        tween: Tween(begin: _lastAvailableBalance, end: available),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Text(
                            '₹${value.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn().scale(curve: Curves.easeOutBack),
                const SizedBox(height: 14),
                TechnicianGlassCard(
                  radius: 16,
                  blurSigma: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '₹${held.toStringAsFixed(0)} on hold',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Held balance is released after hold duration.',
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: TechnicianUiTokens.labelSecondary,
                            ),
                      ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Releasing on 25 Mar',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: TechnicianUiTokens.labelSecondary,
                            ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 16),
                _WalletPrimaryCta(
                  label: 'Withdraw Earnings',
                  onTap: available > 0
                      ? () => _requestWithdrawal(context, available)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No balance available to withdraw.')),
                          ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(RouteNames.technicianPaymentReceipts),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Payment Receipts'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: AppColors.brandWarmLight.withValues(alpha: 0.7)),
                    foregroundColor: AppColors.brandWarmDark,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(RouteNames.technicianPayoutHistory),
                  icon: const Icon(Icons.history),
                  label: const Text('Withdrawal History'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: AppColors.brandWarmLight.withValues(alpha: 0.7)),
                    foregroundColor: AppColors.brandWarmDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (txns.isNotEmpty)
                  ...txns.take(6).map((t) {
                    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
                    final isCredit = amount >= 0;
                    final note = (t['note'] as String?) ??
                        (isCredit ? 'Completed job' : 'Withdrawal');
                    return _txnTile(
                      context,
                      amountText: '${isCredit ? '+' : '-'}₹${amount.abs().toStringAsFixed(0)}',
                      note: note,
                      isCredit: isCredit,
                    );
                  })
                else ...[
                  _txnTile(
                    context,
                    amountText: '+₹500',
                    note: 'Completed job',
                    isCredit: true,
                  ),
                  _txnTile(
                    context,
                    amountText: '-₹200',
                    note: 'Withdrawal',
                    isCredit: false,
                  ),
                ],
                if (holds.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Holds by job', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...holds.take(3).map((e) {
                    final m = e as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TechnicianGlassCard(
                        radius: 14,
                        blurSigma: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text('Job: ${m['jobId'] ?? '—'}')),
                            Text('₹${(m['amount'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 12),
                TechnicianGlassCard(
                  radius: 14,
                  blurSigma: 20,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 18, color: AppColors.brandWarmDark),
                      const SizedBox(width: 8),
                      Text(
                        'Secure withdrawals via bank/UPI',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      )),
    ),
    );
  }

  Widget _txnTile(
    BuildContext context, {
    required String amountText,
    required String note,
    required bool isCredit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TechnicianGlassCard(
        radius: 14,
        blurSigma: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 18,
              color: isCredit ? AppColors.brandWarmDark : AppColors.brandWarmSoft,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(note, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              amountText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCredit ? AppColors.brandWarmDark : AppColors.brandWarmSoft,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPrimaryCta extends StatefulWidget {
  const _WalletPrimaryCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_WalletPrimaryCta> createState() => _WalletPrimaryCtaState();
}

class _WalletPrimaryCtaState extends State<_WalletPrimaryCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandWarmSoft.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

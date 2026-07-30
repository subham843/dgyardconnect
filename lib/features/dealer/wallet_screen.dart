import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/dealer_ui_kit.dart';

String _truncateJobId(dynamic jobId) {
  final s = (jobId ?? '—').toString();
  return s.length > 8 ? '${s.substring(0, 8)}...' : s;
}

class DealerWalletScreen extends StatelessWidget {
  const DealerWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        appBar: DealerMinimalAppBar(
          title: 'Wallet',
          onBack: () => context.go(RouteNames.dealerHome),
        ),
        body: const Center(child: Text(AppConstants.signInRequired)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: DealerMinimalAppBar(
        title: 'Wallet',
        onBack: () => context.go(RouteNames.dealerHome),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.wallets().doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          final data = doc.data();
          final balance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
          final locks = data?['locks'] as List<dynamic>? ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DealerFloatingCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Text(
                        'Available balance',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '₹${balance.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().scale(curve: Curves.easeOutBack),
                if (locks.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Locked (per job)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...locks.asMap().entries.map((e) {
                    final m = e.value as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DealerFloatingCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Job: ${_truncateJobId(m['jobId'])}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '₹${(m['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 50 * e.key)).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
                  }),
                  const SizedBox(height: 24),
                ],
                DealerFloatingCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 24, color: AppColors.primary.withValues(alpha: 0.8)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Payment history and Razorpay integration can be added here.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(RouteNames.dealerSettlementAccount),
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: const Text('Manage payout / refund accounts'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

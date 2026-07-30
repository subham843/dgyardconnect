import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

/// Technician withdrawal history (technician_payouts with transfer_id).
class PayoutHistoryScreen extends StatelessWidget {
  const PayoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return TechnicianLightScope(
        child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const TechnicianGlassAppBar(title: 'Withdrawal history'),
        body: const TechnicianGlassBackground(
          child: Center(child: Text('Sign in required')),
        ),
        ),
      );
    }
    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Withdrawal history',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.technicianPayouts()
            .where('technicianId', isEqualTo: uid)
            .orderBy('payoutDate', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: TechnicianUiTokens.accent, strokeWidth: 2));
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No withdrawals yet.'));
          }
          final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final amount = (d['amount'] as num?)?.toDouble() ?? 0;
              final transferId = d['transferId'] as String?;
              final payoutDate = (d['payoutDate'] as Timestamp?)?.toDate();
              final status = d['status'] as String? ?? '—';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TechnicianUiTokens.hairlineOnGlass),
                ),
                child: ListTile(
                  title: Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${payoutDate != null ? dateFormat.format(payoutDate) : "—"}\n${transferId != null ? "Transfer: $transferId" : ""}\n$status'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      )),
    ),
    );
  }
}

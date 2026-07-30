import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/motion_tokens.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/empty_error_states.dart';

class SupportTicketsScreen extends StatelessWidget {
  const SupportTicketsScreen({super.key});

  static const _bgLight = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
          title: Text(
            'My tickets',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => _safeSupportBack(context),
          ),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
          title: Text(
            'My tickets',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => _safeSupportBack(context),
          ),
        ),
        body: const Center(child: Text('Sign in required.')),
      );
    }

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
        title: Text(
          'My tickets',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => _safeSupportBack(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_tickets')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.confirmation_number_outlined,
              title: 'No tickets yet',
              subtitle: 'Create a ticket for help or feedback.',
              actionLabel: 'Create ticket',
              onAction: () => context.push(RouteNames.supportCreateTicket),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final subject = d['subject'] as String? ?? '—';
              final status = d['status'] as String? ?? 'open';
              final lastPreview =
                  (d['lastMessagePreview'] as String?) ??
                  (d['message'] as String?) ??
                  '';
              final createdAt = d['createdAt'] is Timestamp
                  ? (d['createdAt'] as Timestamp).toDate()
                  : null;
              return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(
                          status,
                        ).withValues(alpha: 0.12),
                        child: Icon(
                          Icons.confirmation_number_rounded,
                          color: _statusColor(status),
                        ),
                      ),
                      title: Text(
                        subject,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        'Status: ${status.toUpperCase()}'
                        '${lastPreview.trim().isNotEmpty ? '\n${lastPreview.trim()}' : ''}'
                        '${createdAt != null ? '\n${_fmt(createdAt)}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: MotionTokens.base,
                    curve: MotionTokens.inCurve,
                    delay: Duration(
                      milliseconds: i * MotionTokens.listStaggerMs,
                    ),
                  )
                  .slideY(
                    begin: 0.05,
                    end: 0,
                    duration: MotionTokens.base,
                    curve: MotionTokens.inCurve,
                    delay: Duration(
                      milliseconds: i * MotionTokens.listStaggerMs,
                    ),
                  );
            },
          );
        },
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'closed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  static String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

void _safeSupportBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RouteNames.supportHome);
  }
}

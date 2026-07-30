import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/legal_constants.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

/// Legal section: grouped policies and agreements. Technician does not see Dealer Agreement; Dealer does not see Technician Agreement.
class LegalMenuScreen extends StatelessWidget {
  const LegalMenuScreen({super.key});

  static const List<MapEntry<String, String>> _allItems = [
    MapEntry(LegalConstants.termsOfService, 'Terms of Service'),
    MapEntry(LegalConstants.privacyPolicy, 'Privacy Policy'),
    MapEntry(LegalConstants.cancellationPolicy, 'Cancellation Policy'),
    MapEntry(LegalConstants.refundPolicy, 'Refund Policy'),
    MapEntry(LegalConstants.technicianAgreement, 'Technician Agreement'),
    MapEntry(LegalConstants.dealerAgreement, 'Dealer Agreement'),
  ];

  static const List<String> _policyOrder = [
    LegalConstants.termsOfService,
    LegalConstants.privacyPolicy,
    LegalConstants.cancellationPolicy,
    LegalConstants.refundPolicy,
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final Widget body = uid == null || !FirestoreService.isAvailable
        ? _LegalContent(items: _allItems)
        : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirestoreService.users().doc(uid).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final role = snapshot.data?.data()?['role'] as String?;
              final items = _itemsForRole(role);
              return _LegalContent(items: items);
            },
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _LegalGradientBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LegalAppBar(onBack: () => context.pop()),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<MapEntry<String, String>> _itemsForRole(String? role) {
    if (role == 'technician') {
      return _allItems
          .where((e) => e.key != LegalConstants.dealerAgreement)
          .toList();
    }
    if (role == 'dealer') {
      return _allItems
          .where((e) => e.key != LegalConstants.technicianAgreement)
          .toList();
    }
    return _allItems;
  }
}

class _LegalGradientBackground extends StatelessWidget {
  const _LegalGradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFF1F5F9),
            Colors.white.withValues(alpha: 0.96),
          ],
        ),
      ),
    );
  }
}

class _LegalAppBar extends StatelessWidget {
  const _LegalAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF0F172A),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          const Expanded(
            child: Text(
              'Legal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  const _LegalContent({required this.items});

  final List<MapEntry<String, String>> items;

  @override
  Widget build(BuildContext context) {
    final policies = <MapEntry<String, String>>[];
    final agreements = <MapEntry<String, String>>[];

    for (final e in items) {
      if (e.key == LegalConstants.technicianAgreement ||
          e.key == LegalConstants.dealerAgreement) {
        agreements.add(e);
      } else {
        policies.add(e);
      }
    }

    policies.sort((a, b) {
      final ia = LegalMenuScreen._policyOrder.indexOf(a.key);
      final ib = LegalMenuScreen._policyOrder.indexOf(b.key);
      return ia.compareTo(ib);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (policies.isNotEmpty) ...[
          const _SectionTitle('Policies'),
          const SizedBox(height: 10),
          ...policies.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LegalTile(
                title: e.value,
                icon: _iconForDocument(e.key),
                onTap: () => context.push(
                  RouteNames.legalDocumentView(e.key),
                  extra: e.value,
                ),
              ),
            ),
          ),
        ],
        if (policies.isNotEmpty && agreements.isNotEmpty)
          const SizedBox(height: 22),
        if (agreements.isNotEmpty) ...[
          const _SectionTitle('Agreements'),
          const SizedBox(height: 10),
          ...agreements.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LegalTile(
                title: e.value,
                icon: _iconForDocument(e.key),
                onTap: () => context.push(
                  RouteNames.legalDocumentView(e.key),
                  extra: e.value,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _iconForDocument(String id) {
    switch (id) {
      case LegalConstants.termsOfService:
        return Icons.description_outlined;
      case LegalConstants.privacyPolicy:
        return Icons.lock_outline_rounded;
      case LegalConstants.cancellationPolicy:
        return Icons.cancel_outlined;
      case LegalConstants.refundPolicy:
        return Icons.account_balance_wallet_outlined;
      case LegalConstants.technicianAgreement:
      case LegalConstants.dealerAgreement:
        return Icons.article_outlined;
      default:
        return Icons.article_outlined;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _LegalTile extends StatefulWidget {
  const _LegalTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_LegalTile> createState() => _LegalTileState();
}

class _LegalTileState extends State<_LegalTile> {
  bool _pressed = false;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xFF475569);

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              child: InkWell(
                onTap: widget.onTap,
                splashColor: AppColors.brandWarmSoft.withValues(alpha: 0.12),
                highlightColor: AppColors.brandWarmSoft.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 24, color: iconColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                            height: 1.25,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 24,
                        color: const Color(0xFF64748B).withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

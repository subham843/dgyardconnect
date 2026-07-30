import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../shared/router/app_router.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/services/fcm_service.dart';
import '../../shared/services/firestore_service.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveFcmToken());
  }

  Future<void> _saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FcmService.saveTokenToUser(uid);
      } catch (_) {}
    }
  }

  void _goToRoleHome(Map<String, dynamic> data) {
    if (!mounted) return;
    final role = data['role'] as String?;
    if (role == 'dealer') {
      context.go(RouteNames.dealerHome);
    } else if (role == 'technician') {
      context.go(RouteNames.technicianHome);
    }
  }

  static const _bgLight = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: uid != null && FirestoreService.isAvailable
            ? StreamBuilder(
                stream: FirestoreService.users().doc(uid).snapshots(),
                builder: (context, snapshot) {
                  final approved = snapshot.data?.data()?['approved'] as bool? ?? false;
                  final data = snapshot.data?.data();
                  if (approved && data != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _goToRoleHome(data));
                  }
                  return _buildContent(context);
                },
              )
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.how_to_reg_outlined,
              size: 80,
              color: AppColors.primary,
            ),
          )
              .animate()
              .scale(curve: Curves.easeOutBack)
              .fadeIn(),
          const SizedBox(height: 32),
          Text(
            AppConstants.waitingForAdminApproval,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Text(
              AppConstants.waitingForAdminApprovalMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF0F172A),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 48),
          OutlinedButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              if (rootNavigatorKey.currentContext != null) {
                rootNavigatorKey.currentContext!.go(AuthPostLogin.postLogoutRoute());
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: _cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

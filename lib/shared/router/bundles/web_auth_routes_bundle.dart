import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../features/ai_business_os/admin/bos_public_chat_screen.dart';
import '../../../features/ai_business_os/admin/bos_trial_signup_screen.dart';
import '../../../features/auth/login_screen.dart';
import '../../../features/auth/otp_verify_screen.dart';
import '../../../features/auth/pending_approval_screen.dart';
import '../../../features/auth/phone_entry_screen.dart';
import '../../../features/auth/register_customer_screen.dart';
import '../../../features/auth/register_dealer_screen.dart';
import '../../../features/auth/register_technician_screen.dart';
import '../../../features/auth/splash_screen.dart';
import '../../../shared/models/service_area_result.dart';
import '../../../shared/widgets/success_animation_screen.dart';

/// Deferred auth bundle — login / register / OTP (not needed for public home cold start).
Widget buildAuthScreen(GoRouterState state) {
  switch (state.uri.path) {
    case RouteNames.splash:
      return const SplashScreen();
    case RouteNames.login:
      return const LoginScreen();
    case RouteNames.phoneEntry:
      return const PhoneEntryScreen();
    case RouteNames.otpVerify:
      final verificationId = state.extra is String ? state.extra as String : '';
      return OtpVerifyScreen(verificationId: verificationId);
    case RouteNames.registerDealer:
      final extra = state.extra is Map<String, dynamic>
          ? state.extra as Map<String, dynamic>?
          : null;
      return RegisterDealerScreen(
        initialServiceArea: extra?['serviceArea'] as ServiceAreaResult?,
        fromPhone: extra?['fromPhone'] as bool? ?? false,
      );
    case RouteNames.registerTechnician:
      final extra = state.extra is Map<String, dynamic>
          ? state.extra as Map<String, dynamic>?
          : null;
      return RegisterTechnicianScreen(
        initialServiceArea: extra?['serviceArea'] as ServiceAreaResult?,
        fromPhone: extra?['fromPhone'] as bool? ?? false,
      );
    case RouteNames.registerCustomer:
      return const RegisterCustomerScreen();
    case RouteNames.bosTrialSignup:
      return const BosTrialSignupScreen();
    case RouteNames.bosPublicChat:
      return const BosPublicChatScreen();
    case RouteNames.pendingApproval:
      return const PendingApprovalScreen();
    case RouteNames.successAnimation:
      final data = state.extra is Map<String, dynamic>
          ? state.extra as Map<String, dynamic>
          : <String, dynamic>{};
      return SuccessAnimationScreen(
        successType:
            data['successType'] as SuccessType? ?? SuccessType.loginSuccess,
        nextRoute: data['nextRoute'] as String? ?? RouteNames.login,
        extra: data['extra'],
      );
    default:
      return const Scaffold(
        body: Center(child: Text('Unknown auth route')),
      );
  }
}

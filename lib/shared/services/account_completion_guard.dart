import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import 'firestore_service.dart';

class AccountCompletionGuard {
  AccountCompletionGuard._();

  static Future<bool> ensureDealerCanOpenKyc(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return false;
    final doc = await FirestoreService.users().doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    if (!isDealerProfileComplete(data)) {
      if (!context.mounted) return false;
      await _showBlockingDialog(
        context: context,
        title: 'Profile Completion Required',
        message:
            'Please complete your profile details before proceeding to KYC verification.',
        actionLabel: 'Complete Profile',
        onAction: () => context.push(RouteNames.dealerProfile),
      );
      return false;
    }
    return true;
  }

  static Future<bool> ensureTechnicianCanOpenKyc(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return false;
    final doc = await FirestoreService.users().doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    if (!isTechnicianProfileComplete(data)) {
      if (!context.mounted) return false;
      await _showBlockingDialog(
        context: context,
        title: 'Profile Completion Required',
        message:
            'Please complete your profile details before proceeding to KYC verification.',
        actionLabel: 'Complete Profile',
        onAction: () => context.push(RouteNames.technicianProfile),
      );
      return false;
    }
    return true;
  }

  static Future<bool> ensureDealerCanCreateJob(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return false;

    final doc = await FirestoreService.users().doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    if (!isDealerProfileComplete(data)) {
      if (!context.mounted) return false;
      await _showBlockingDialog(
        context: context,
        title: 'Profile Completion Required',
        message:
            'Please complete your profile details before creating a new job posting.',
        actionLabel: 'Complete Profile',
        onAction: () => context.push(RouteNames.dealerProfile),
      );
      return false;
    }

    final kycStatus = (data['kycStatus'] as String?) ?? 'pending';
    if (kycStatus != 'verified') {
      if (!context.mounted) return false;
      await _showBlockingDialog(
        context: context,
        title: 'KYC Verification Required',
        message:
            'Please complete your KYC verification to continue with job posting.',
        actionLabel: 'Complete KYC',
        onAction: () => context.push(RouteNames.dealerKyc),
      );
      return false;
    }

    return true;
  }

  static Future<bool> ensureTechnicianCanAcceptJob(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return false;

    final doc = await FirestoreService.users().doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    if (!isTechnicianProfileComplete(data)) {
      if (!context.mounted) return false;
      await _showBlockingDialog(
        context: context,
        title: 'Profile Completion Required',
        message:
            'Please complete your profile details before accepting a job request.',
        actionLabel: 'Complete Profile',
        onAction: () => context.push(RouteNames.technicianProfile),
      );
      return false;
    }

    final kycStatus = (data['kycStatus'] as String?) ?? 'pending';
    if (kycStatus != 'verified') {
      if (!context.mounted) return false;
      await _showBlockingDialog(
        context: context,
        title: 'KYC Verification Required',
        message:
            'Please complete your KYC verification to continue with job acceptance.',
        actionLabel: 'Complete KYC',
        onAction: () => context.push(RouteNames.technicianKyc),
      );
      return false;
    }

    return true;
  }

  static bool isDealerProfileComplete(Map<String, dynamic> data) {
    return dealerMissingFields(data).isEmpty;
  }

  static bool isTechnicianProfileComplete(Map<String, dynamic> data) {
    return technicianMissingFields(data).isEmpty;
  }

  static List<String> dealerMissingFields(Map<String, dynamic> data) {
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final name = (profile['name'] as String?)?.trim() ?? '';
    final phone = (profile['phone'] as String?)?.trim() ?? '';
    final sectors = data['dealerSectors'] as List<dynamic>? ?? const [];
    final serviceArea = data['serviceArea'] as Map<String, dynamic>? ?? {};
    final missing = <String>[];
    if (name.isEmpty) missing.add('Name');
    if (phone.isEmpty) missing.add('Phone Number');
    if (sectors.isEmpty) missing.add('Service Sectors');
    if (serviceArea.isEmpty) missing.add('Service Area');
    return missing;
  }

  static List<String> technicianMissingFields(Map<String, dynamic> data) {
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final name = (profile['name'] as String?)?.trim() ?? '';
    final phone = (profile['phone'] as String?)?.trim() ?? '';
    final skills = data['skills'] as List<dynamic>? ?? const [];
    final serviceArea = data['serviceArea'] as Map<String, dynamic>? ?? {};
    final missing = <String>[];
    if (name.isEmpty) missing.add('Name');
    if (phone.isEmpty) missing.add('Phone Number');
    if (skills.isEmpty) missing.add('Skills');
    if (serviceArea.isEmpty) missing.add('Service Area');
    return missing;
  }

  static bool isKycVerified(Map<String, dynamic> data) {
    return (data['kycStatus'] as String?) == 'verified';
  }

  static Future<void> _showBlockingDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onAction();
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }
}

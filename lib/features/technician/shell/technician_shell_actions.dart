import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../shared/services/account_completion_guard.dart';
import '../../../shared/widgets/profile_under_review_dialog.dart';

void showTechnicianUnderReviewDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => const ProfileUnderReviewDialog(
      message:
          'Your profile is under review. Once approved, you will be able to go online and accept jobs. '
          'This may take up to 24 hours. You will receive a notification when approved.',
    ),
  );
}

Future<void> openTechnicianKycWithProfileGate(BuildContext context) async {
  final allowed = await AccountCompletionGuard.ensureTechnicianCanOpenKyc(context);
  if (!context.mounted || !allowed) return;
  context.push(RouteNames.technicianKyc);
}

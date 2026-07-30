import 'package:flutter/material.dart';

import '../../../v2/v2_colors.dart';
import '../../../v2/v2_glass.dart';
import '../../../v2/v2_text.dart';

/// Visible popup for checkout validation errors and payment failures.
Future<void> showStoreCheckoutAlert(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
  bool isError = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: v2BackdropGlass(
          blurSigma: 24,
          backgroundColor: Colors.white.withValues(alpha: 0.94),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isError ? V2Colors.ember : V2Colors.plasma)
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      icon,
                      color: isError ? V2Colors.ember : V2Colors.plasma,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: V2Text.bodyEmph().copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: V2Text.small().copyWith(
                      color: V2Colors.fgSubtle,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: V2Colors.ink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shorthand for missing-field / validation warnings.
Future<void> showStoreCheckoutValidationAlert(
  BuildContext context, {
  required String message,
  String title = 'Please check',
}) {
  return showStoreCheckoutAlert(
    context,
    title: title,
    message: message,
    icon: Icons.error_outline_rounded,
    isError: true,
  );
}

/// Shorthand for payment / server errors.
Future<void> showStoreCheckoutErrorAlert(
  BuildContext context, {
  required String message,
  String title = 'Something went wrong',
}) {
  return showStoreCheckoutAlert(
    context,
    title: title,
    message: message,
    icon: Icons.warning_amber_rounded,
    isError: true,
  );
}
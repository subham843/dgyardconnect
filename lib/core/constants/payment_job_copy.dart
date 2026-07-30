/// User-facing copy for job-linked (on-site service) payments.
/// Wording is chosen to reduce Google Play confusion with in-app digital purchases.
abstract final class PaymentJobCopy {
  static const String screenTitle = 'Pay for on-site service';

  static const String subtitle =
      'This payment is only for the field service job below—not for app subscriptions, plans, or feature access.';

  static const String sectionJobHeading = 'Job you are paying for';

  static const String labelJobRef = 'Job reference';
  static const String labelService = 'Service / job title';
  static const String labelWorkLocation = 'Work location';
  static const String labelPostedOn = 'Job posted';
  static const String labelYourRole = 'You are paying as';

  static const String roleDealer = 'Dealer (job owner)';

  static const String sectionAmountHeading = 'Amount for this job';

  static const String labelWhatPaymentIsFor = 'What this payment is for';

  /// Shown when job is in payment_pending — escrow booking for agreed work.
  static const String amountReasonEscrowBooking =
      'Escrow payment for the agreed on-site service. Funds are held for this job until work is completed and verified per platform rules.';

  static const String sectionEscrowHeading = 'How your payment is held';

  static const String escrowBody =
      'Your payment is held in escrow for this specific job. It pays for real installation, repair, or maintenance work at the site above. It does not unlock app features, contacts, or digital content.';

  static const String settlementNote =
      'After on-site work is verified, settlement to the technician and any platform service fee follow your Dealer Agreement and job status.';

  static const String refundNote =
      'Cancellations and refunds follow the Cancellation Policy and Refund Policy (Legal menu).';

  static const String razorpayCheckoutNote =
      'Secure checkout is processed by Razorpay for this job payment only.';

  static const String helpLinkLabel = 'How job payments work';

  static const String confirmDialogTitle = 'Confirm job payment';

  static String confirmDialogBody({
    required String jobRef,
    required String amountLabel,
    required String serviceLine,
    required String locationLine,
  }) =>
      'You are paying $amountLabel for job $jobRef.\n\n'
      'Service: $serviceLine\n'
      'Location: $locationLine\n\n'
      'This payment is for on-site field service arranged through D.G.Yard Connect. It is not for subscriptions or in-app features.';

  static const String confirmPayAction = 'Confirm and pay';
  static const String goBackAction = 'Go back';

  static String primaryPayButton(String amountLabel) =>
      'Pay $amountLabel for this job';

  static const String notNow = 'Not now';

  static const String legacyCheckoutLabel =
      'Payment confirmation (admin / legacy)';

  static const String completePaymentForJob = 'Complete job payment';

  static String paymentRecorded(String jobRef) =>
      'We\'ve recorded your payment for job $jobRef. The job will update and the technician will be notified as per your job status.';

  static const String viewJob = 'View job';

  static const String paymentNotCompletedTitle = 'Payment not completed';

  static const String paymentNotCompletedBody =
      'Your bank or UPI did not complete this payment. No job payment was recorded. You can try again from this screen.';

  static const String tryAgain = 'Try again';

  static const String verificationFailedPrefix =
      'We could not verify this payment: ';

  static const String jobNotFound =
      'This job could not be found. Go back to My jobs and open the job again.';

  static const String notJobOwner =
      'Only the dealer who posted this job can pay for it. Sign in with the correct account.';

  static const String jobNotPayable =
      'This job is not waiting for payment. Open the job from My jobs to see the current status.';

  static const String amountMismatchHint =
      'The amount was updated from the job. Paying the figure shown below.';

  static const String loadingJob = 'Loading job details…';
}

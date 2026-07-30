/// Analytics event names and param keys. Use these when logging so reports stay consistent.
abstract final class AnalyticsEvents {
  AnalyticsEvents._();

  // --- Custom events (funnel & ops) ---
  static const String jobPosted = 'job_posted';
  static const String paymentCompleted = 'payment_completed';
  static const String warrantyClaimCreated = 'warranty_claim_created';
  static const String jobDisputeCreated = 'job_dispute_created';
  static const String supportTicketCreated = 'support_ticket_created';

  // --- Param keys (snake_case) ---
  static const String paramJobId = 'jobId';
  static const String paramClaimId = 'claimId';
  static const String paramTicketId = 'ticketId';
  static const String paramMethod = 'method';
  static const String paramAmount = 'amount';
  static const String paramBiddingEnabled = 'biddingEnabled';
  static const String paramEmergency = 'emergency';
  static const String paramHasPhotos = 'has_photos';
  static const String paramHasVideo = 'has_video';
  static const String paramSubjectLen = 'subject_len';
}

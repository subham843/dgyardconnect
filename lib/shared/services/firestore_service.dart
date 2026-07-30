import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreService {
  static FirebaseFirestore get _instance => FirebaseFirestore.instance;

  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static CollectionReference<Map<String, dynamic>> users() => _instance.collection('users');
  static CollectionReference<Map<String, dynamic>> settlementAccounts(String uid) =>
      users().doc(uid).collection('settlement_accounts');
  static CollectionReference<Map<String, dynamic>> jobs() => _instance.collection('jobs');
  static CollectionReference<Map<String, dynamic>> wallets() => _instance.collection('wallets');
  static CollectionReference<Map<String, dynamic>> jobTypes() => _instance.collection('job_types');
  static CollectionReference<Map<String, dynamic>> sectors() => _instance.collection('sectors');
  static CollectionReference<Map<String, dynamic>> sectorSubOptions() => _instance.collection('sector_sub_options');
  static CollectionReference<Map<String, dynamic>> skills() => _instance.collection('skills');
  static CollectionReference<Map<String, dynamic>> industryTypes() => _instance.collection('industry_types');
  static CollectionReference<Map<String, dynamic>> industrySubOptions() => _instance.collection('industry_sub_options');
  static CollectionReference<Map<String, dynamic>> rateMatrix() => _instance.collection('rate_matrix');
  static CollectionReference<Map<String, dynamic>> defaultWarranty() => _instance.collection('default_warranty');
  static CollectionReference<Map<String, dynamic>> wiringTypes() => _instance.collection('wiring_types');
  static CollectionReference<Map<String, dynamic>> wiringRateConfig() => _instance.collection('wiring_rate_config');
  static CollectionReference<Map<String, dynamic>> platformChargeConfig() => _instance.collection('platform_charge_config');
  static CollectionReference<Map<String, dynamic>> travelExpenseConfig() => _instance.collection('travel_expense_config');
  static CollectionReference<Map<String, dynamic>> jobChats(String jobId) => _instance.collection('job_chats').doc(jobId).collection('messages');

  /// Job disputes (dealer raises before auto-approval; admin resolves).
  static CollectionReference<Map<String, dynamic>> jobDisputes() => _instance.collection('job_disputes');

  /// Legal documents (Terms, Privacy, etc.). Doc IDs: terms_of_service, privacy_policy, technician_agreement, dealer_agreement, cancellation_policy, refund_policy.
  static DocumentReference<Map<String, dynamic>> legalDocument(String docId) => _instance.collection('legal_documents').doc(docId);
  static CollectionReference<Map<String, dynamic>> legalDocuments() => _instance.collection('legal_documents');

  /// User terms/privacy acceptance records (signup consent).
  static CollectionReference<Map<String, dynamic>> userTermsAcceptance() => _instance.collection('user_terms_acceptance');

  /// Cancellation compensations (admin-paid travel/pickup).
  static CollectionReference<Map<String, dynamic>> cancellationCompensations() => _instance.collection('cancellation_compensations');

  /// Trust score change history (read-only from app; written by Cloud Functions).
  static CollectionReference<Map<String, dynamic>> trustScoreHistory() => _instance.collection('trust_score_history');

  static DocumentReference<Map<String, dynamic>> rejectionReasonsConfig() =>
      _instance.collection('config').doc('rejection_reasons');

  static DocumentReference<Map<String, dynamic>> brandKit() =>
      _instance.collection('config').doc('brand_kit');

  /// App update config (admin-managed). Used to power Remote Config values.
  static DocumentReference<Map<String, dynamic>> appUpdateConfig() =>
      _instance.collection('config').doc('app_update');

  /// Runtime UI/text/feature flags (admin-managed). Mirrors Remote Config keys.
  static DocumentReference<Map<String, dynamic>> appRuntimeConfig() =>
      _instance.collection('config').doc('app_runtime');

  static CollectionReference<Map<String, dynamic>> ads() =>
      _instance.collection('ads');

  /// User notifications (in-app notification center).
  static CollectionReference<Map<String, dynamic>> notifications(String uid) =>
      users().doc(uid).collection('notifications');

  /// Warranty claims (dealer raises claim on completed job).
  static CollectionReference<Map<String, dynamic>> warrantyClaims() =>
      _instance.collection('warranty_claims');

  /// Admin-managed claim categories (by sector/sub-sector).
  static CollectionReference<Map<String, dynamic>> warrantyClaimCategories() =>
      _instance.collection('warranty_claim_categories');

  /// Service completion records (auto-created when dealer approves job).
  static CollectionReference<Map<String, dynamic>> serviceCompletionRecords() =>
      _instance.collection('service_completion_records');

  /// Billing: dealer payment receipts (created when Razorpay payment succeeds).
  static CollectionReference<Map<String, dynamic>> dealerPaymentReceipts() =>
      _instance.collection('dealer_payment_receipts');

  /// Billing: platform commission invoices (created on job completion).
  static CollectionReference<Map<String, dynamic>> platformInvoices() =>
      _instance.collection('platform_invoices');

  /// Billing: technician payment receipts (created when 80% is credited).
  static CollectionReference<Map<String, dynamic>> technicianPaymentReceipts() =>
      _instance.collection('technician_payment_receipts');

  /// Billing: warranty hold release receipts (created when hold is released).
  static CollectionReference<Map<String, dynamic>> warrantyReleaseReceipts() =>
      _instance.collection('warranty_release_receipts');

  /// Technician payouts (withdrawal to bank with transfer_id).
  static CollectionReference<Map<String, dynamic>> technicianPayouts() =>
      _instance.collection('technician_payouts');

  /// Product announcements / what’s new (admin-managed).
  static CollectionReference<Map<String, dynamic>> announcements() =>
      _instance.collection('announcements');

  /// Billing: platform expenses (admin-managed).
  static CollectionReference<Map<String, dynamic>> platformExpenses() =>
      _instance.collection('platform_expenses');

  /// Billing: financial reports (generated by backend).
  static CollectionReference<Map<String, dynamic>> platformFinancialReports() =>
      _instance.collection('platform_financial_reports');

  /// GST/billing config (admin-managed).
  static DocumentReference<Map<String, dynamic>> billingGstConfig() =>
      _instance.collection('config').doc('billing_gst');

  /// Marketplace COD + pricing knobs (superadmin-managed; callables read COD subset).
  static DocumentReference<Map<String, dynamic>> marketplaceRulesDoc() =>
      _instance.collection('config').doc('marketplace_rules');

  /// Seller payout batch headers (admin-managed; optional until finance automation).
  static CollectionReference<Map<String, dynamic>> marketplacePayoutBatches() =>
      _instance.collection('marketplace_payout_batches');

  /// Technician strikes (read-only from app; written by Cloud Functions).
  static CollectionReference<Map<String, dynamic>> technicianStrikes() =>
      _instance.collection('technician_strikes');

  /// Audit logs (super admin only).
  static CollectionReference<Map<String, dynamic>> auditLogs() =>
      _instance.collection('audit_logs');

  /// Job evidence locker (one doc per job, created on completion; read-only).
  static DocumentReference<Map<String, dynamic>> jobEvidence(String jobId) =>
      _instance.collection('job_evidence').doc(jobId);

  static CollectionReference<Map<String, dynamic>> jobEvidenceCollection() =>
      _instance.collection('job_evidence');

  /// Fraud alerts (admin only).
  static CollectionReference<Map<String, dynamic>> fraudAlerts() =>
      _instance.collection('fraud_alerts');

  // --- Marketplace (B2B catalog & procurement; isolated collections) ---

  /// Buyer-facing catalog. No seller identity stored here (admin-curated / published).
  static CollectionReference<Map<String, dynamic>> marketplaceCatalog() =>
      _instance.collection('marketplace_catalog');

  /// Admin-managed taxonomy: categories / subcategories / attribute options.
  static CollectionReference<Map<String, dynamic>> marketplaceCategories() =>
      _instance.collection('marketplace_categories');

  static CollectionReference<Map<String, dynamic>> marketplaceSubcategories(String categoryId) =>
      marketplaceCategories().doc(categoryId).collection('subcategories');

  static CollectionReference<Map<String, dynamic>> marketplaceCategoryAttributes(String categoryId, String subcategoryId) =>
      marketplaceSubcategories(categoryId).doc(subcategoryId).collection('attributes');

  /// Seller drafts & submissions (contains seller_uid; not for buyer clients).
  static CollectionReference<Map<String, dynamic>> marketplaceListings() =>
      _instance.collection('marketplace_listings');

  static CollectionReference<Map<String, dynamic>> marketplaceOrders() =>
      _instance.collection('marketplace_orders');

  static CollectionReference<Map<String, dynamic>> marketplaceOrderLines(String orderId) =>
      marketplaceOrders().doc(orderId).collection('lines');

  static CollectionReference<Map<String, dynamic>> marketplaceRfqs() =>
      _instance.collection('marketplace_rfqs');

  /// Cart line items: users/{uid}/marketplace_cart/items/{itemId}
  static CollectionReference<Map<String, dynamic>> marketplaceCartItems(String uid) =>
      users().doc(uid).collection('marketplace_cart').doc('data').collection('items');

  static DocumentReference<Map<String, dynamic>> marketplaceCartRoot(String uid) =>
      users().doc(uid).collection('marketplace_cart').doc('data');

  /// Internal seller profile (KYC-linked ops; admin + owner).
  static CollectionReference<Map<String, dynamic>> marketplaceSellerProfiles() =>
      _instance.collection('marketplace_seller_profiles');

  /// Marketplace-scoped audit entries (admin read; server write recommended).
  static CollectionReference<Map<String, dynamic>> marketplaceAuditLogs() =>
      _instance.collection('marketplace_audit_logs');

  /// Per-line seller fulfillment queue (server-created; seller + superadmin read).
  static CollectionReference<Map<String, dynamic>> marketplaceSellerOrderRequests() =>
      _instance.collection('marketplace_seller_order_requests');
}

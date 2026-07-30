import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../features/admin/admin_home_screen.dart';
import '../../../features/admin/adjust_trust_score_screen.dart' as admin_adjust_trust;
import '../../../features/admin/ads_screen.dart';
import '../../../features/admin/app_updates_screen.dart';
import '../../../features/admin/audit_logs_screen.dart';
import '../../../features/admin/billing_gst_screen.dart' as admin_billing_gst;
import '../../../features/admin/brand_kit_screen.dart';
import '../../../features/admin/dealers_list_screen.dart';
import '../../../features/admin/dispute_detail_screen.dart';
import '../../../features/admin/disputes_list_screen.dart' as admin_disputes;
import '../../../features/admin/escrow_approvals_screen.dart';
import '../../../features/admin/escrow_settlement_screen.dart';
import '../../../features/admin/expenses_screen.dart' as admin_expenses;
import '../../../features/admin/finance_dashboard_screen.dart' as admin_finance;
import '../../../features/admin/financial_documents_screen.dart' as admin_financial_docs;
import '../../../features/admin/fraud_alert_detail_screen.dart';
import '../../../features/admin/fraud_alerts_screen.dart';
import '../../../features/admin/job_detail_screen.dart';
import '../../../features/admin/job_evidence_list_screen.dart';
import '../../../features/admin/job_evidence_view_screen.dart';
import '../../../features/admin/jobs_list_screen.dart';
import '../../../features/admin/kyc_screen.dart' as admin_kyc;
import '../../../features/admin/legal_document_edit_screen.dart' as admin_legal_doc_edit;
import '../../../features/admin/legal_documents_screen.dart' as admin_legal_docs;
import '../../../features/admin/legal_logs_screen.dart' as admin_legal_logs;
import '../../../features/admin/marketplace/admin_marketplace_attributes_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_audit_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_catalog_product_edit_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_catalog_products_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_cod_rules_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_dispatch_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_home_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_inward_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_order_detail_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_orders_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_payouts_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_pricing_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_product_review_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_products_queue_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_qc_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_rfq_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_sellers_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_subcategories_screen.dart';
import '../../../features/admin/marketplace/admin_marketplace_taxonomy_screen.dart';
import '../../../features/admin/master_data/default_warranty_screen.dart';
import '../../../features/admin/master_data/industry_sub_options_screen.dart';
import '../../../features/admin/master_data/industry_types_screen.dart';
import '../../../features/admin/master_data/job_limit_config_screen.dart';
import '../../../features/admin/master_data/job_types_screen.dart';
import '../../../features/admin/master_data/master_data_home_screen.dart';
import '../../../features/admin/master_data/platform_charge_config_screen.dart';
import '../../../features/admin/master_data/rate_matrix_screen.dart';
import '../../../features/admin/master_data/rejection_reasons_screen.dart';
import '../../../features/admin/master_data/sector_sub_options_screen.dart';
import '../../../features/admin/master_data/sectors_screen.dart';
import '../../../features/admin/master_data/skills_screen.dart';
import '../../../features/admin/master_data/travel_expense_config_screen.dart';
import '../../../features/admin/master_data/warranty_claim_categories_screen.dart';
import '../../../features/admin/master_data/wiring_rate_config_screen.dart';
import '../../../features/admin/master_data/wiring_types_screen.dart';
import '../../../features/admin/override_level_screen.dart';
import '../../../features/admin/penalty_status_screen.dart';
import '../../../features/admin/pending_approval_detail_screen.dart';
import '../../../features/admin/pending_approvals_screen.dart';
import '../../../features/admin/platform_dashboard_screen.dart';
import '../../../features/admin/profile_approvals_screen.dart';
import '../../../features/admin/send_push_screen.dart';
import '../../../features/admin/service_completion_records_screen.dart' as admin_service_records;
import '../../../features/admin/strikes_list_screen.dart';
import '../../../features/admin/support_ticket_detail_screen.dart';
import '../../../features/admin/support_tickets_list_screen.dart';
import '../../../features/admin/technicians_list_screen.dart';
import '../../../features/admin/trust_score_history_screen.dart' as admin_trust_history;
import '../../../features/admin/warranty_claim_detail_screen.dart';
import '../../../features/admin/warranty_claims_list_screen.dart';
import '../../../features/shared/chat_screen.dart' as shared_chat;
import '../../../features/shared/service_completion_record_screen.dart' as service_record;

/// Deferred Connect admin screens (Firebase) — not loaded on public homepage cold-start.
Widget buildConnectAdminScreen(GoRouterState state) {
  final path = state.uri.path;
  final params = state.pathParameters;

  switch (path) {
    case RouteNames.adminHome:
      return const AdminHomeScreen();
    case RouteNames.adminPendingApprovals:
      return const PendingApprovalsScreen();
    case RouteNames.adminProfileApprovals:
      return const ProfileApprovalsScreen();
    case RouteNames.adminMasterData:
      return const MasterDataHomeScreen();
    case RouteNames.adminJobTypes:
      return const JobTypesScreen();
    case RouteNames.adminSectors:
      return const SectorsScreen();
    case RouteNames.adminSectorSubOptions:
      return const SectorSubOptionsScreen();
    case RouteNames.adminSkills:
      return const SkillsScreen();
    case RouteNames.adminIndustryTypes:
      return const IndustryTypesScreen();
    case RouteNames.adminIndustrySubOptions:
      return const IndustrySubOptionsScreen();
    case RouteNames.adminRateMatrix:
      return const RateMatrixScreen();
    case RouteNames.adminDefaultWarranty:
      return const DefaultWarrantyScreen();
    case RouteNames.adminWiringTypes:
      return const WiringTypesScreen();
    case RouteNames.adminWiringRateConfig:
      return const WiringRateConfigScreen();
    case RouteNames.adminPlatformChargeConfig:
      return const PlatformChargeConfigScreen();
    case RouteNames.adminJobLimitConfig:
      return const JobLimitConfigScreen();
    case RouteNames.adminTravelExpenseConfig:
      return const TravelExpenseConfigScreen();
    case RouteNames.adminRejectionReasons:
      return const RejectionReasonsScreen();
    case RouteNames.adminKyc:
      return const admin_kyc.AdminKycScreen();
    case RouteNames.adminDealersList:
      return const AdminDealersListScreen();
    case RouteNames.adminTechniciansList:
      return const AdminTechniciansListScreen();
    case RouteNames.adminJobsList:
      return const AdminJobsListScreen();
    case RouteNames.adminWarrantyClaims:
      return const AdminWarrantyClaimsListScreen();
    case RouteNames.adminEscrowApprovals:
      return const AdminEscrowApprovalsScreen();
    case RouteNames.adminServiceCompletionRecords:
      return const admin_service_records.AdminServiceCompletionRecordsScreen();
    case RouteNames.adminFinance:
      return const admin_finance.FinanceDashboardScreen();
    case RouteNames.adminExpenses:
      return const admin_expenses.AdminExpensesScreen();
    case RouteNames.adminFinancialDocuments:
      return const admin_financial_docs.AdminFinancialDocumentsScreen();
    case RouteNames.adminBillingGst:
      return const admin_billing_gst.BillingGstScreen();
    case RouteNames.adminDisputes:
      return admin_disputes.AdminDisputesListScreen(
        initialJobId: state.extra is String ? state.extra as String? : null,
      );
    case RouteNames.adminLegalLogs:
      return const admin_legal_logs.AdminLegalLogsScreen();
    case RouteNames.adminLegalDocuments:
      return const admin_legal_docs.AdminLegalDocumentsScreen();
    case RouteNames.adminTrustScoreHistory:
      return const admin_trust_history.AdminTrustScoreHistoryScreen();
    case RouteNames.adminAdjustTrustScore:
      return admin_adjust_trust.AdminAdjustTrustScoreScreen(
        prefillUserId: state.extra is String ? state.extra as String? : null,
      );
    case RouteNames.adminWarrantyClaimCategories:
      return const WarrantyClaimCategoriesScreen();
    case RouteNames.adminOverrideLevel:
      return const AdminOverrideLevelScreen();
    case RouteNames.adminPenaltyStatus:
      return const AdminPenaltyStatusScreen();
    case RouteNames.adminStrikes:
      return const AdminStrikesListScreen();
    case RouteNames.adminAuditLogs:
      return const AdminAuditLogsScreen();
    case RouteNames.adminJobEvidence:
      return const AdminJobEvidenceListScreen();
    case RouteNames.adminSupportTickets:
      return const AdminSupportTicketsListScreen();
    case RouteNames.adminFraudAlerts:
      return const AdminFraudAlertsScreen();
    case RouteNames.adminPlatformDashboard:
      return const AdminPlatformDashboardScreen();
    case RouteNames.adminBrandKit:
      return const BrandKitScreen();
    case RouteNames.adminAds:
      return const AdminAdsScreen();
    case RouteNames.adminAppUpdates:
      return const AdminAppUpdatesScreen();
    case RouteNames.adminSendPush:
      return const AdminSendPushScreen();
    case RouteNames.adminMarketplaceHome:
      return const AdminMarketplaceHomeScreen();
    case RouteNames.adminMarketplaceTaxonomy:
      return const AdminMarketplaceTaxonomyScreen();
    case RouteNames.adminMarketplaceProductsQueue:
      return const AdminMarketplaceProductsQueueScreen();
    case RouteNames.adminMarketplaceCatalogProducts:
      return const AdminMarketplaceCatalogProductsScreen();
    case RouteNames.adminMarketplacePricing:
      return const AdminMarketplacePricingScreen();
    case RouteNames.adminMarketplaceOrders:
      return const AdminMarketplaceOrdersScreen();
    case RouteNames.adminMarketplaceRfq:
      return const AdminMarketplaceRfqScreen();
    case RouteNames.adminMarketplaceCodRules:
      return const AdminMarketplaceCodRulesScreen();
    case RouteNames.adminMarketplaceInward:
      return const AdminMarketplaceInwardScreen();
    case RouteNames.adminMarketplaceQc:
      return const AdminMarketplaceQcScreen();
    case RouteNames.adminMarketplaceDispatch:
      return const AdminMarketplaceDispatchScreen();
    case RouteNames.adminMarketplacePayouts:
      return const AdminMarketplacePayoutsScreen();
    case RouteNames.adminMarketplaceSellers:
      return const AdminMarketplaceSellersScreen();
    case RouteNames.adminMarketplaceAudit:
      return const AdminMarketplaceAuditScreen();
  }

  final pendingId = params['id'];
  if (pendingId != null && path.startsWith('/admin/pending-approvals/detail/')) {
    return PendingApprovalDetailScreen(uid: pendingId);
  }

  final jobId = params['jobId'];
  if (jobId != null && path == '/admin/jobs/$jobId/chat') {
    return shared_chat.ChatScreen(
      jobId: jobId,
      backRoute: RouteNames.adminJobDetail(jobId),
    );
  }
  if (jobId != null && path == '/admin/jobs/$jobId') {
    return AdminJobDetailScreen(jobId: jobId);
  }

  final claimId = params['claimId'];
  if (claimId != null && path == '/admin/warranty-claims/$claimId') {
    return AdminWarrantyClaimDetailScreen(claimId: claimId);
  }

  if (jobId != null && path == '/admin/escrow-approvals/$jobId') {
    return AdminEscrowSettlementScreen(jobId: jobId);
  }

  if (jobId != null && path == '/admin/service-completion-records/view/$jobId') {
    return service_record.ServiceCompletionRecordScreen(
      jobId: jobId,
      allowDownloadAndPrint: true,
      backRoute: RouteNames.adminServiceCompletionRecords,
    );
  }

  final disputeId = params['disputeId'];
  if (disputeId != null && path == '/admin/disputes/$disputeId') {
    return AdminDisputeDetailScreen(disputeId: disputeId);
  }

  final documentId = params['documentId'];
  if (documentId != null && path == '/admin/legal-documents/edit/$documentId') {
    return admin_legal_doc_edit.AdminLegalDocumentEditScreen(
      documentId: documentId,
      title: state.extra is String ? state.extra as String? : null,
    );
  }

  final uid = params['uid'];
  if (uid != null && path == '/admin/trust-score-history/$uid') {
    return admin_trust_history.AdminTrustScoreHistoryScreen(
      userId: uid.isEmpty ? null : uid,
    );
  }

  if (jobId != null && path == '/admin/job-evidence/$jobId') {
    return AdminJobEvidenceViewScreen(jobId: jobId);
  }

  final ticketId = params['ticketId'];
  if (ticketId != null && path == '/admin/support-tickets/$ticketId') {
    return AdminSupportTicketDetailScreen(ticketId: ticketId);
  }

  final alertId = params['alertId'];
  if (alertId != null && path == '/admin/fraud-alerts/$alertId') {
    return AdminFraudAlertDetailScreen(alertId: alertId);
  }

  final categoryId = params['categoryId'];
  final subcategoryId = params['subcategoryId'];
  if (categoryId != null &&
      subcategoryId != null &&
      path == '/admin/marketplace/taxonomy/$categoryId/subs/$subcategoryId/attrs') {
    return AdminMarketplaceAttributesScreen(
      categoryId: categoryId,
      subcategoryId: subcategoryId,
    );
  }
  if (categoryId != null && path == '/admin/marketplace/taxonomy/$categoryId/subs') {
    return AdminMarketplaceSubcategoriesScreen(categoryId: categoryId);
  }

  final catalogProductId = params['catalogProductId'];
  if (catalogProductId != null &&
      path == '/admin/marketplace/catalog/products/$catalogProductId/edit') {
    return AdminMarketplaceCatalogProductEditScreen(productId: catalogProductId);
  }

  final listingId = params['listingId'];
  if (listingId != null && path == '/admin/marketplace/products/$listingId/review') {
    return AdminMarketplaceProductReviewScreen(listingId: listingId);
  }

  final orderId = params['orderId'];
  if (orderId != null && path == '/admin/marketplace/orders/$orderId/detail') {
    return AdminMarketplaceOrderDetailScreen(orderId: orderId);
  }

  return const AdminHomeScreen();
}

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/route_names.dart';
import 'route_guards.dart';
import 'router_transitions.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/app_walkthrough_screen.dart';
import '../../features/auth/phone_entry_screen.dart';
import '../../features/auth/otp_verify_screen.dart';
import '../../features/auth/service_area_picker_screen.dart';
import '../../features/auth/service_area_details_screen.dart';
import '../../features/auth/role_choice_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/ai_business_os/admin/bos_public_chat_screen.dart';
import '../../features/ai_business_os/admin/bos_trial_signup_screen.dart';
import '../../features/ai_business_os/admin/admin_ai_os_onboarding_screen.dart';
import '../../features/auth/register_customer_screen.dart';
import '../../features/auth/register_dealer_screen.dart';
import '../../features/auth/register_technician_screen.dart';
import '../../features/auth/pending_approval_screen.dart';
import '../../shared/models/service_area_result.dart';
import '../../shared/widgets/success_animation_screen.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/admin/pending_approvals_screen.dart';
import '../../features/admin/pending_approval_detail_screen.dart';
import '../../features/admin/profile_approvals_screen.dart';
import '../../features/admin/kyc_screen.dart' as admin_kyc;
import '../../features/admin/master_data/master_data_home_screen.dart';
import '../../features/admin/master_data/job_types_screen.dart';
import '../../features/admin/master_data/sectors_screen.dart';
import '../../features/admin/master_data/sector_sub_options_screen.dart';
import '../../features/admin/master_data/skills_screen.dart';
import '../../features/admin/master_data/industry_types_screen.dart';
import '../../features/admin/master_data/industry_sub_options_screen.dart';
import '../../features/admin/master_data/rate_matrix_screen.dart';
import '../../features/admin/master_data/default_warranty_screen.dart';
import '../../features/admin/master_data/wiring_types_screen.dart';
import '../../features/admin/master_data/wiring_rate_config_screen.dart';
import '../../features/admin/master_data/platform_charge_config_screen.dart';
import '../../features/admin/master_data/job_limit_config_screen.dart';
import '../../features/admin/master_data/travel_expense_config_screen.dart';
import '../../features/admin/master_data/rejection_reasons_screen.dart';
import '../../features/dealer/dealer_home_screen.dart';
import '../../features/dealer/profile_screen.dart' as dealer;
import '../../features/dealer/edit_profile_screen.dart' as dealer_edit;
import '../../features/dealer/post_job_screen.dart' as dealer_post_job;
import '../../features/dealer/draft_jobs_screen.dart';
import '../../features/dealer/my_jobs_screen.dart' as dealer_my_jobs;
import '../../features/dealer/job_detail_screen.dart' as dealer_job_detail;
import '../../features/dealer/wallet_screen.dart' as dealer_wallet;
import '../../features/dealer/kyc_screen.dart' as dealer_kyc;
import '../../features/dealer/bidding_screen.dart' as dealer_bidding;
import '../../features/dealer/track_technician_screen.dart' as dealer_track;
import '../../features/dealer/rate_technician_screen.dart' as dealer_rate;
import '../../features/dealer/payment_screen.dart' as dealer_payment;
import '../../features/dealer/warranty_claim_form_screen.dart'
    as dealer_warranty_form;
import '../../features/dealer/job_dispute_form_screen.dart'
    as dealer_dispute_form;
import '../../features/dealer/warranty_claims_list_screen.dart'
    as dealer_warranty_list;
import '../../features/dealer/warranty_claim_detail_screen.dart'
    as dealer_warranty_detail;
import '../../features/dealer/job_warranty_claims_screen.dart'
    as dealer_job_warranty;
import '../../features/dealer/under_warranty_jobs_screen.dart'
    as dealer_under_warranty;
import '../../features/dealer/service_completion_records_screen.dart'
    as dealer_service_records;
import '../../features/dealer/documents_screen.dart' as dealer_documents;
import '../../features/technician/warranty_claim_detail_screen.dart'
    as tech_warranty_detail;
import '../../features/technician/technician_home_screen.dart';
import '../../features/technician/profile_screen.dart' as tech;
import '../../features/technician/edit_profile_screen.dart' as tech_edit;
import '../../features/technician/technician_skills_edit_screen.dart';
import '../../features/technician/technician_service_area_edit_screen.dart';
import '../../features/technician/my_jobs_screen.dart' as tech_my_jobs;
import '../../features/technician/job_detail_screen.dart' as tech_job_detail;
import '../../features/technician/wallet_screen.dart' as tech_wallet;
import '../../features/technician/payment_receipts_screen.dart'
    as tech_payment_receipts;
import '../../features/technician/payout_history_screen.dart'
    as tech_payout_history;
import '../../features/technician/technician_quick_start_screen.dart';
import '../../features/technician/technician_warranty_claims_screen.dart';
import '../../features/technician/under_warranty_jobs_screen.dart'
    as tech_under_warranty;
import '../../features/technician/technician_disputes_screen.dart';
import '../../features/technician/kyc_screen.dart' as tech_kyc;
import '../../features/technician/incoming_job_screen.dart';
import '../../features/technician/bidding_screen.dart' as tech_bidding;
import '../../features/technician/job_execution_screen.dart' as tech_execution;
import '../../features/technician/finish_job_screen.dart' as tech_finish_job;
import '../../features/technician/material_return_screen.dart'
    as tech_material_return;
import '../../features/technician/rate_dealer_screen.dart' as tech_rate;
import '../../features/shared/chat_screen.dart' as shared_chat;
import '../../features/shared/service_completion_record_screen.dart'
    as service_record;
import '../../features/shared/service_record_verify_screen.dart'
    as verify_screen;
import '../../features/shared/notifications_screen.dart';
import '../../features/shared/settlement_account_screen.dart' as settlement;
import '../../features/shared/legal_menu_screen.dart';
import '../../features/shared/legal_document_viewer_screen.dart';
import '../../features/shared/settings_screen.dart';
import '../../features/shared/support_home_screen.dart';
import '../../features/shared/support_faq_screen.dart';
import '../../features/shared/support_create_ticket_screen.dart';
import '../../features/shared/support_tickets_screen.dart';
import '../../features/shared/offers_screen.dart';
import '../../features/admin/override_level_screen.dart';
import '../../features/admin/penalty_status_screen.dart';
import '../../features/admin/dealers_list_screen.dart';
import '../../features/admin/technicians_list_screen.dart';
import '../../features/admin/jobs_list_screen.dart';
import '../../features/admin/job_detail_screen.dart';
import '../../features/admin/warranty_claims_list_screen.dart';
import '../../features/admin/warranty_claim_detail_screen.dart';
import '../../features/admin/escrow_approvals_screen.dart';
import '../../features/admin/escrow_settlement_screen.dart';
import '../../features/admin/service_completion_records_screen.dart'
    as admin_service_records;
import '../../features/admin/finance_dashboard_screen.dart' as admin_finance;
import '../../features/admin/expenses_screen.dart' as admin_expenses;
import '../../features/admin/financial_documents_screen.dart'
    as admin_financial_docs;
import '../../features/admin/billing_gst_screen.dart' as admin_billing_gst;
import '../../features/admin/disputes_list_screen.dart' as admin_disputes;
import '../../features/admin/dispute_detail_screen.dart';
import '../../features/admin/legal_logs_screen.dart' as admin_legal_logs;
import '../../features/admin/legal_documents_screen.dart' as admin_legal_docs;
import '../../features/admin/legal_document_edit_screen.dart'
    as admin_legal_doc_edit;
import '../../features/admin/trust_score_history_screen.dart'
    as admin_trust_history;
import '../../features/admin/adjust_trust_score_screen.dart'
    as admin_adjust_trust;
import '../../features/admin/master_data/warranty_claim_categories_screen.dart';
import '../../features/admin/brand_kit_screen.dart';
import '../../features/admin/ads_screen.dart';
import '../../features/admin/app_updates_screen.dart';
import '../../features/admin/send_push_screen.dart';
import '../../features/admin/strikes_list_screen.dart';
import '../../features/admin/audit_logs_screen.dart';
import '../../features/admin/job_evidence_list_screen.dart';
import '../../features/admin/job_evidence_view_screen.dart';
import '../../features/admin/platform_dashboard_screen.dart';
import '../../features/admin/fraud_alerts_screen.dart';
import '../../features/admin/fraud_alert_detail_screen.dart';
// Legal pages (keep)
import '../../features/web/privacy_policy_screen.dart';
import '../../features/web/data_deletion_screen.dart';

// New public web experience
import '../../features/web_public/pages/home/home_page.dart';
import '../../features/web_public/pages/shop/store_page.dart';
import '../../features/web_public/pages/shop/store_category_page.dart';
import '../../features/web_public/pages/shop/store_cart_page.dart';
import '../../features/web_public/pages/shop/store_checkout_page.dart';
import '../../features/web_public/pages/shop/product_detail_page.dart';
import '../../features/web_public/pages/calculator/calculator_page.dart';
import '../../features/seo/public/pages/seo_blog_detail_page.dart';
import '../../features/seo/public/pages/seo_landing_page_screen.dart';
import '../../features/seo/public/pages/services_cities_page.dart';
import '../../features/seo/public/pages/services_hub_page.dart';
import '../../features/seo/services/seo_route_guard.dart';
import '../../features/web_public/pages/static/services_page.dart';
import '../../features/web_public/pages/static/about_page.dart';
import '../../features/web_public/pages/static/connect_page.dart';
import '../../features/web_public/pages/static/contact_page.dart';
import '../../features/web_public/pages/static/public_support_page.dart';
import '../../features/admin/support_tickets_list_screen.dart';
import '../../features/admin/support_ticket_detail_screen.dart';
import '../../features/customer/account/customer_account_hub_screen.dart';
import '../../features/customer/account/customer_order_detail_screen.dart';
import '../../features/customer/account/customer_orders_screen.dart';
import '../../features/customer/chat_page.dart';
import '../../features/customer/rate_page.dart';
import '../../features/marketplace/presentation/marketplace_home_screen.dart';
import '../../features/marketplace/presentation/marketplace_search_screen.dart';
import '../../features/marketplace/presentation/marketplace_category_screen.dart';
import '../../features/marketplace/presentation/marketplace_product_detail_screen.dart';
import '../../features/marketplace/presentation/marketplace_cart_screen.dart';
import '../../features/marketplace/presentation/marketplace_checkout_screen.dart';
import '../../features/marketplace/presentation/marketplace_payment_result_screen.dart';
import '../../features/marketplace/presentation/marketplace_orders_screen.dart';
import '../../features/marketplace/presentation/marketplace_order_detail_screen.dart';
import '../../features/marketplace/presentation/marketplace_rfq_detail_screen.dart';
import '../../features/marketplace/presentation/marketplace_rfq_new_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_hub_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_listings_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_listing_editor_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_published_manage_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_order_requests_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_request_detail_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_shipments_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_shipment_detail_screen.dart';
import '../../features/marketplace/presentation/seller/marketplace_seller_payouts_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_home_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_products_queue_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_product_review_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_catalog_products_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_catalog_product_edit_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_pricing_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_orders_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_order_detail_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_rfq_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_cod_rules_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_inward_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_qc_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_dispatch_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_payouts_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_sellers_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_audit_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_taxonomy_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_subcategories_screen.dart';
import '../../features/admin/marketplace/admin_marketplace_attributes_screen.dart';
import '../../features/shop/admin/admin_shop_hub_screen.dart';
import '../../features/shop/admin/admin_shop_categories_screen.dart';
import '../../features/shop/admin/admin_shop_subcategories_screen.dart';
import '../../features/shop/admin/admin_shop_attribute_editor_screen.dart';
import '../../features/shop/admin/admin_shop_attributes_screen.dart';
import '../../features/shop/admin/admin_shop_brands_screen.dart';
import '../../features/shop/admin/admin_shop_bulk_import_screen.dart';
import '../../features/shop/admin/admin_shop_product_import_screen.dart';
import '../../features/shop/admin/admin_shop_product_editor_screen.dart';
import '../../features/shop/admin/admin_shop_products_screen.dart';
import '../../features/shop/admin/admin_shop_subcategory_editor_screen.dart';
import '../../features/shop/admin/admin_shop_inventory_orders_screen.dart';
import '../../features/shop/admin/erp/admin_shop_customers_screen.dart';
import '../../features/shop/admin/erp/admin_shop_purchases_screen.dart';
import '../../features/shop/admin/erp/admin_shop_quotations_screen.dart';
import '../../features/shop/admin/erp/admin_shop_reports_screen.dart';
import '../../features/shop/admin/erp/admin_shop_suppliers_screen.dart';
import '../../features/calculator/admin/admin_calculator_hub_screen.dart';
import '../../features/calculator/admin/admin_calculator_crud_screens.dart';
import '../../features/shop/presentation/shop_home_screen.dart';
import '../../features/shop/presentation/shop_category_screen.dart';
import '../../features/shop/presentation/shop_product_detail_screen.dart';
import '../../features/shop/presentation/shop_cart_checkout_screens.dart';
import '../../features/calculator/presentation/calculator_screens.dart';
import 'navigator_key.dart';

export 'navigator_key.dart' show rootNavigatorKey;

/// Notifies GoRouter when auth state changes so redirect runs (e.g. after logout).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen(
      (_) => notifyListeners(),
    );
  }
  StreamSubscription<User?>? _sub;
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final _authRefreshNotifier = _AuthRefreshNotifier();

/// Production go_router config: role-based routes, redirect guard, deep links.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  refreshListenable: _authRefreshNotifier,
  initialLocation: RouteNames.publicHome,
  observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
  redirect: RouteGuards.redirect,
  routes: [
    // Public Web Experience (NEW)
    GoRoute(
      path: RouteNames.publicHome,
      name: 'publicHome',
      pageBuilder: (c, s) => _publicPage(s, const HomePage()),
    ),
    GoRoute(
      path: RouteNames.publicStore,
      name: 'publicStore',
      pageBuilder: (c, s) {
        final qp = s.uri.queryParameters;
        return _publicPage(
          s,
          StorePage(
            key: ValueKey('store-${s.uri.query}'),
            categorySlug: qp['category'],
            subcategorySlug: qp['subcategory'],
            brandSlug: qp['brand'],
            initialQuery: qp['q'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/store/category/:slug',
      name: 'publicStoreCategory',
      pageBuilder: (c, s) {
        final slug = s.pathParameters['slug'] ?? '';
        return _publicPage(s, StoreCategoryPage(categorySlug: slug));
      },
    ),
    GoRoute(
      path: RouteNames.publicCart,
      name: 'publicCart',
      pageBuilder: (c, s) => _publicPage(s, const StoreCartPage()),
    ),
    GoRoute(
      path: RouteNames.publicCheckout,
      name: 'publicCheckout',
      pageBuilder: (c, s) => _publicPage(s, const StoreCheckoutPage()),
    ),
    GoRoute(
      path: RouteNames.publicProductDetail,
      name: 'publicProductDetail',
      pageBuilder: (c, s) {
        final slug = s.pathParameters['slug'] ?? '';
        return _publicPage(s, ProductDetailPage(productSlug: slug));
      },
    ),
    GoRoute(
      path: RouteNames.publicCalculatorList,
      name: 'publicCalculatorList',
      pageBuilder: (c, s) => _publicPage(s, const CalculatorPage()),
    ),
    GoRoute(
      path: RouteNames.publicCalculatorDetail,
      name: 'publicCalculatorDetail',
      pageBuilder: (c, s) {
        final slug = s.pathParameters['slug'] ?? '';
        return _publicPage(s, CalculatorPage(initialFamilySlug: slug));
      },
    ),
    GoRoute(
      path: RouteNames.publicServices,
      name: 'publicServices',
      pageBuilder: (c, s) => _publicPage(s, const ServicesPage()),
    ),
    GoRoute(
      path: RouteNames.publicServicesInstallations,
      name: 'publicServicesInstallations',
      pageBuilder: (c, s) => _publicPage(s, const ServicesHubPage()),
    ),
    GoRoute(
      path: RouteNames.publicServicesCities,
      name: 'publicServicesCities',
      pageBuilder: (c, s) => _publicPage(s, const ServicesCitiesPage()),
    ),
    GoRoute(
      path: RouteNames.publicBlogDetail,
      name: 'publicBlogDetail',
      pageBuilder: (c, s) {
        final slug = s.pathParameters['slug'] ?? '';
        return _publicPage(s, SeoBlogDetailPage(slug: slug));
      },
    ),
    GoRoute(
      path: RouteNames.publicSeoLandingPattern,
      name: 'publicSeoLanding',
      pageBuilder: (c, s) {
        final citySlug = s.pathParameters['citySlug'] ?? '';
        final serviceSlug = s.pathParameters['serviceSlug'] ?? '';
        if (!SeoRouteGuard.isPotentialLandingPath(citySlug, serviceSlug)) {
          return _publicPage(s, const ServicesHubPage());
        }
        return _publicPage(s, SeoLandingPageScreen(citySlug: citySlug, serviceSlug: serviceSlug));
      },
    ),
    GoRoute(
      path: RouteNames.publicConnect,
      name: 'publicConnect',
      pageBuilder: (c, s) => _publicPage(s, const ConnectPage()),
    ),
    GoRoute(
      path: RouteNames.publicAbout,
      name: 'publicAbout',
      pageBuilder: (c, s) => _publicPage(s, const AboutPage()),
    ),
    GoRoute(
      path: RouteNames.publicContact,
      name: 'publicContact',
      pageBuilder: (c, s) => _publicPage(s, const ContactPage()),
    ),

    // Legal pages (required)
    GoRoute(
      path: RouteNames.webPrivacyPolicy,
      name: 'webPrivacyPolicy',
      pageBuilder: (c, s) => _page(s, const PrivacyPolicyScreen()),
    ),
    GoRoute(
      path: RouteNames.webDataDeletion,
      name: 'webDataDeletion',
      pageBuilder: (c, s) => _page(s, const DataDeletionScreen()),
    ),

    // Auth (moved to /splash)
    GoRoute(
      path: RouteNames.splash,
      name: 'splash',
      pageBuilder: (c, s) => _page(s, const SplashScreen()),
    ),
    GoRoute(
      path: RouteNames.appWalkthrough,
      name: 'appWalkthrough',
      pageBuilder: (c, s) => _page(s, const AppWalkthroughScreen()),
    ),
    GoRoute(
      path: RouteNames.verifyRecord,
      pageBuilder: (c, s) {
        final recordId = s.uri.queryParameters['recordId'] ?? '';
        return _page(
          s,
          verify_screen.ServiceRecordVerifyScreen(recordId: recordId),
        );
      },
    ),
    GoRoute(
      path: RouteNames.legalMenu,
      pageBuilder: (c, s) => _page(s, const LegalMenuScreen()),
    ),
    GoRoute(
      path: RouteNames.settings,
      pageBuilder: (c, s) => _page(s, const SettingsScreen()),
    ),
    GoRoute(
      path: RouteNames.offers,
      pageBuilder: (c, s) {
        final jobId = s.uri.queryParameters['jobId'];
        return _page(s, OffersScreen(jobId: jobId));
      },
    ),
    GoRoute(
      path: RouteNames.supportHome,
      pageBuilder: (c, s) {
        if (kIsWeb && s.uri.queryParameters['role'] == null) {
          return _publicPage(s, const PublicSupportPage());
        }
        final role = s.uri.queryParameters['role'];
        return _page(s, SupportHomeScreen(role: role));
      },
    ),
    GoRoute(
      path: RouteNames.supportFaq,
      pageBuilder: (c, s) {
        final role = s.uri.queryParameters['role'];
        return _page(s, SupportFaqScreen(role: role));
      },
    ),
    GoRoute(
      path: RouteNames.supportCreateTicket,
      pageBuilder: (c, s) => _page(s, const SupportCreateTicketScreen()),
    ),
    GoRoute(
      path: RouteNames.supportTickets,
      pageBuilder: (c, s) => _page(s, const SupportTicketsScreen()),
    ),
    GoRoute(
      path: '/legal/:documentId',
      pageBuilder: (c, s) {
        final docId = s.pathParameters['documentId'] ?? '';
        final title = s.extra is String ? s.extra as String? : null;
        return _page(
          s,
          LegalDocumentViewerScreen(documentId: docId, title: title),
        );
      },
    ),
    GoRoute(
      path: RouteNames.phoneEntry,
      name: 'phone',
      pageBuilder: (c, s) => _page(s, const PhoneEntryScreen()),
    ),
    GoRoute(
      path: RouteNames.otpVerify,
      name: 'otp',
      pageBuilder: (c, s) {
        final verificationId = s.extra is String ? s.extra as String : '';
        return _page(s, OtpVerifyScreen(verificationId: verificationId));
      },
    ),
    GoRoute(
      path: RouteNames.serviceAreaPicker,
      name: 'serviceArea',
      pageBuilder: (c, s) => _page(s, const ServiceAreaPickerScreen()),
    ),
    GoRoute(
      path: RouteNames.serviceAreaDetails,
      name: 'serviceAreaDetails',
      pageBuilder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : <String, dynamic>{};
        final lat = (extra['latitude'] is num)
            ? (extra['latitude'] as num).toDouble()
            : 0.0;
        final lng = (extra['longitude'] is num)
            ? (extra['longitude'] as num).toDouble()
            : 0.0;
        final radius = (extra['radiusKm'] is num)
            ? (extra['radiusKm'] as num).toDouble()
            : 10.0;
        final addressLabel = extra['addressLabel'] is String
            ? extra['addressLabel'] as String
            : '';
        final city = extra['city'] is String ? extra['city'] as String : '';
        return _page(
          s,
          ServiceAreaDetailsScreen(
            latitude: lat,
            longitude: lng,
            radiusKm: radius,
            addressLabel: addressLabel,
            city: city,
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.roleChoice,
      name: 'roleChoice',
      pageBuilder: (c, s) {
        final extra = s.extra;
        ServiceAreaResult serviceArea = const ServiceAreaResult(
          latitude: 0,
          longitude: 0,
          radiusKm: 10,
          fullName: '',
          email: '',
          buildingApartment: '',
          houseFlatShopNumber: '',
          landmark: '',
        );
        if (extra is ServiceAreaResult) {
          serviceArea = extra;
        } else if (extra is Map<String, dynamic>) {
          final sa = extra['serviceArea'];
          serviceArea = sa is ServiceAreaResult
              ? sa
              : ServiceAreaResult.fromMap(
                  sa is Map<String, dynamic> ? sa : null,
                );
        }
        final fromCompletedFlow =
            extra is Map<String, dynamic> &&
            (extra['fromCompletedFlow'] as bool? ?? false);
        return _page(
          s,
          RoleChoiceScreen(
            serviceArea: serviceArea,
            fromCompletedFlow: fromCompletedFlow,
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.login,
      name: 'login',
      pageBuilder: (c, s) => _page(s, const LoginScreen()),
    ),
    GoRoute(
      path: RouteNames.successAnimation,
      name: 'success',
      pageBuilder: (c, s) {
        final data = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : <String, dynamic>{};
        return _page(
          s,
          SuccessAnimationScreen(
            successType:
                data['successType'] as SuccessType? ?? SuccessType.loginSuccess,
            nextRoute: data['nextRoute'] as String? ?? RouteNames.login,
            extra: data['extra'],
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.registerDealer,
      name: 'registerDealer',
      pageBuilder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>?
            : null;
        return _page(
          s,
          RegisterDealerScreen(
            initialServiceArea: extra?['serviceArea'] as ServiceAreaResult?,
            fromPhone: extra?['fromPhone'] as bool? ?? false,
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.registerTechnician,
      name: 'registerTechnician',
      pageBuilder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>?
            : null;
        return _page(
          s,
          RegisterTechnicianScreen(
            initialServiceArea: extra?['serviceArea'] as ServiceAreaResult?,
            fromPhone: extra?['fromPhone'] as bool? ?? false,
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.registerCustomer,
      name: 'registerCustomer',
      pageBuilder: (c, s) => _page(s, const RegisterCustomerScreen()),
    ),
    GoRoute(
      path: RouteNames.bosTrialSignup,
      name: 'bosTrialSignup',
      pageBuilder: (c, s) => _page(s, const BosTrialSignupScreen()),
    ),
    GoRoute(
      path: RouteNames.bosPublicChat,
      name: 'bosPublicChat',
      pageBuilder: (c, s) => _page(s, const BosPublicChatScreen()),
    ),
    GoRoute(
      path: RouteNames.adminAiOsOnboarding,
      name: 'adminAiOsOnboarding',
      pageBuilder: (c, s) => _page(s, const AdminAiOsOnboardingScreen()),
    ),
    GoRoute(
      path: RouteNames.pendingApproval,
      name: 'pendingApproval',
      pageBuilder: (c, s) => _page(s, const PendingApprovalScreen()),
    ),
    GoRoute(
      path: RouteNames.adminHome,
      name: 'adminHome',
      pageBuilder: (c, s) => _page(s, const AdminHomeScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerHome,
      name: 'dealerHome',
      pageBuilder: (c, s) => _page(s, const DealerHomeScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerNotifications,
      pageBuilder: (c, s) =>
          _page(s, const NotificationsScreen(isDealer: true)),
    ),
    GoRoute(
      path: RouteNames.dealerDraftJobs,
      pageBuilder: (c, s) => _page(s, const DealerDraftJobsScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianHome,
      name: 'technicianHome',
      pageBuilder: (c, s) => _page(s, const TechnicianHomeScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianNotifications,
      pageBuilder: (c, s) =>
          _page(s, const NotificationsScreen(isDealer: false)),
    ),
    // Admin placeholders
    GoRoute(
      path: RouteNames.adminPendingApprovals,
      pageBuilder: (c, s) => _page(s, const PendingApprovalsScreen()),
    ),
    GoRoute(
      path: '/admin/pending-approvals/detail/:id',
      pageBuilder: (c, s) => _page(
        s,
        PendingApprovalDetailScreen(uid: s.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: RouteNames.adminProfileApprovals,
      pageBuilder: (c, s) => _page(s, const ProfileApprovalsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMasterData,
      pageBuilder: (c, s) => _page(s, const MasterDataHomeScreen()),
    ),
    GoRoute(
      path: RouteNames.adminJobTypes,
      pageBuilder: (c, s) => _page(s, const JobTypesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminSectors,
      pageBuilder: (c, s) => _page(s, const SectorsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminSectorSubOptions,
      pageBuilder: (c, s) => _page(s, const SectorSubOptionsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminSkills,
      pageBuilder: (c, s) => _page(s, const SkillsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminIndustryTypes,
      pageBuilder: (c, s) => _page(s, const IndustryTypesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminIndustrySubOptions,
      pageBuilder: (c, s) => _page(s, const IndustrySubOptionsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminRateMatrix,
      pageBuilder: (c, s) => _page(s, const RateMatrixScreen()),
    ),
    GoRoute(
      path: RouteNames.adminDefaultWarranty,
      pageBuilder: (c, s) => _page(s, const DefaultWarrantyScreen()),
    ),
    GoRoute(
      path: RouteNames.adminWiringTypes,
      pageBuilder: (c, s) => _page(s, const WiringTypesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminWiringRateConfig,
      pageBuilder: (c, s) => _page(s, const WiringRateConfigScreen()),
    ),
    GoRoute(
      path: RouteNames.adminPlatformChargeConfig,
      pageBuilder: (c, s) => _page(s, const PlatformChargeConfigScreen()),
    ),
    GoRoute(
      path: RouteNames.adminJobLimitConfig,
      pageBuilder: (c, s) => _page(s, const JobLimitConfigScreen()),
    ),
    GoRoute(
      path: RouteNames.adminTravelExpenseConfig,
      pageBuilder: (c, s) => _page(s, const TravelExpenseConfigScreen()),
    ),
    GoRoute(
      path: RouteNames.adminRejectionReasons,
      pageBuilder: (c, s) => _page(s, const RejectionReasonsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminKyc,
      pageBuilder: (c, s) => _page(s, const admin_kyc.AdminKycScreen()),
    ),
    GoRoute(
      path: RouteNames.adminDealersList,
      pageBuilder: (c, s) => _page(s, const AdminDealersListScreen()),
    ),
    GoRoute(
      path: RouteNames.adminTechniciansList,
      pageBuilder: (c, s) => _page(s, const AdminTechniciansListScreen()),
    ),
    GoRoute(
      path: RouteNames.adminJobsList,
      pageBuilder: (c, s) => _page(s, const AdminJobsListScreen()),
    ),
    GoRoute(
      path: '/admin/jobs/:jobId',
      pageBuilder: (c, s) => _page(
        s,
        AdminJobDetailScreen(jobId: s.pathParameters['jobId'] ?? ''),
      ),
      routes: [
        GoRoute(
          path: 'chat',
          pageBuilder: (c, s) {
            final jobId = s.pathParameters['jobId'] ?? '';
            return _page(
              s,
              shared_chat.ChatScreen(
                jobId: jobId,
                backRoute: RouteNames.adminJobDetail(jobId),
              ),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.adminWarrantyClaims,
      pageBuilder: (c, s) => _page(s, const AdminWarrantyClaimsListScreen()),
      routes: [
        GoRoute(
          path: ':claimId',
          pageBuilder: (c, s) => _page(
            s,
            AdminWarrantyClaimDetailScreen(
              claimId: s.pathParameters['claimId'] ?? '',
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.adminEscrowApprovals,
      pageBuilder: (c, s) => _page(s, const AdminEscrowApprovalsScreen()),
      routes: [
        GoRoute(
          path: ':jobId',
          pageBuilder: (c, s) => _page(
            s,
            AdminEscrowSettlementScreen(jobId: s.pathParameters['jobId'] ?? ''),
          ),
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.adminServiceCompletionRecords,
      pageBuilder: (c, s) => _page(
        s,
        const admin_service_records.AdminServiceCompletionRecordsScreen(),
      ),
      routes: [
        GoRoute(
          path: 'view/:jobId',
          pageBuilder: (c, s) {
            final jobId = s.pathParameters['jobId'] ?? '';
            return _page(
              s,
              service_record.ServiceCompletionRecordScreen(
                jobId: jobId,
                allowDownloadAndPrint: true,
                backRoute: RouteNames.adminServiceCompletionRecords,
              ),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.adminFinance,
      pageBuilder: (c, s) =>
          _page(s, const admin_finance.FinanceDashboardScreen()),
    ),
    GoRoute(
      path: RouteNames.adminExpenses,
      pageBuilder: (c, s) =>
          _page(s, const admin_expenses.AdminExpensesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminFinancialDocuments,
      pageBuilder: (c, s) =>
          _page(s, const admin_financial_docs.AdminFinancialDocumentsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminBillingGst,
      pageBuilder: (c, s) =>
          _page(s, const admin_billing_gst.BillingGstScreen()),
    ),
    GoRoute(
      path: RouteNames.adminDisputes,
      pageBuilder: (c, s) => _page(
        s,
        admin_disputes.AdminDisputesListScreen(
          initialJobId: s.extra is String ? s.extra as String? : null,
        ),
      ),
      routes: [
        GoRoute(
          path: ':disputeId',
          pageBuilder: (c, s) => _page(
            s,
            AdminDisputeDetailScreen(
              disputeId: s.pathParameters['disputeId'] ?? '',
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.adminLegalLogs,
      pageBuilder: (c, s) =>
          _page(s, const admin_legal_logs.AdminLegalLogsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminLegalDocuments,
      pageBuilder: (c, s) =>
          _page(s, const admin_legal_docs.AdminLegalDocumentsScreen()),
    ),
    GoRoute(
      path: '/admin/legal-documents/edit/:documentId',
      pageBuilder: (c, s) {
        final docId = s.pathParameters['documentId'] ?? '';
        final title = s.extra is String ? s.extra as String? : null;
        return _page(
          s,
          admin_legal_doc_edit.AdminLegalDocumentEditScreen(
            documentId: docId,
            title: title,
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.adminTrustScoreHistory,
      pageBuilder: (c, s) =>
          _page(s, const admin_trust_history.AdminTrustScoreHistoryScreen()),
    ),
    GoRoute(
      path: '/admin/trust-score-history/:uid',
      pageBuilder: (c, s) {
        final uid = s.pathParameters['uid'] ?? '';
        return _page(
          s,
          admin_trust_history.AdminTrustScoreHistoryScreen(
            userId: uid.isEmpty ? null : uid,
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.adminAdjustTrustScore,
      pageBuilder: (c, s) {
        final prefill = s.extra is String ? s.extra as String? : null;
        return _page(
          s,
          admin_adjust_trust.AdminAdjustTrustScoreScreen(
            prefillUserId: prefill,
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.adminWarrantyClaimCategories,
      pageBuilder: (c, s) => _page(s, const WarrantyClaimCategoriesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminOverrideLevel,
      pageBuilder: (c, s) => _page(s, const AdminOverrideLevelScreen()),
    ),
    GoRoute(
      path: RouteNames.adminPenaltyStatus,
      pageBuilder: (c, s) => _page(s, const AdminPenaltyStatusScreen()),
    ),
    GoRoute(
      path: RouteNames.adminStrikes,
      pageBuilder: (c, s) => _page(s, const AdminStrikesListScreen()),
    ),
    GoRoute(
      path: '/admin/strikes/technician/:uid',
      pageBuilder: (c, s) => _page(s, const AdminStrikesListScreen()),
    ),
    GoRoute(
      path: RouteNames.adminAuditLogs,
      pageBuilder: (c, s) => _page(s, const AdminAuditLogsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminJobEvidence,
      pageBuilder: (c, s) => _page(s, const AdminJobEvidenceListScreen()),
    ),
    GoRoute(
      path: RouteNames.adminSupportTickets,
      pageBuilder: (c, s) => _page(s, const AdminSupportTicketsListScreen()),
      routes: [
        GoRoute(
          path: ':ticketId',
          pageBuilder: (c, s) => _page(
            s,
            AdminSupportTicketDetailScreen(
              ticketId: s.pathParameters['ticketId'] ?? '',
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.adminFraudAlerts,
      pageBuilder: (c, s) => _page(s, const AdminFraudAlertsScreen()),
      routes: [
        GoRoute(
          path: ':alertId',
          pageBuilder: (c, s) => _page(
            s,
            AdminFraudAlertDetailScreen(
              alertId: s.pathParameters['alertId'] ?? '',
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/admin/job-evidence/:jobId',
      pageBuilder: (c, s) {
        final jobId = s.pathParameters['jobId'] ?? '';
        return _page(s, AdminJobEvidenceViewScreen(jobId: jobId));
      },
    ),
    GoRoute(
      path: RouteNames.adminPlatformDashboard,
      pageBuilder: (c, s) => _page(s, const AdminPlatformDashboardScreen()),
    ),
    GoRoute(
      path: RouteNames.adminBrandKit,
      pageBuilder: (c, s) => _page(s, const BrandKitScreen()),
    ),
    GoRoute(
      path: RouteNames.adminAds,
      pageBuilder: (c, s) => _page(s, const AdminAdsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminAppUpdates,
      pageBuilder: (c, s) => _page(s, const AdminAppUpdatesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminSendPush,
      pageBuilder: (c, s) => _page(s, const AdminSendPushScreen()),
    ),
    // Dealer placeholders
    GoRoute(
      path: RouteNames.dealerPostJob,
      pageBuilder: (c, s) => _page(s, const dealer_post_job.PostJobScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerMyJobs,
      pageBuilder: (c, s) => _page(
        s,
        dealer_my_jobs.MyJobsScreen(
          initialSearchQuery: s.uri.queryParameters['q'],
        ),
      ),
    ),
    GoRoute(
      path: '/dealer/jobs/:id',
      pageBuilder: (c, s) => _page(
        s,
        dealer_job_detail.JobDetailScreen(jobId: s.pathParameters['id'] ?? ''),
      ),
      routes: [
        GoRoute(
          path: 'bidding',
          pageBuilder: (c, s) => _page(
            s,
            dealer_bidding.DealerBiddingScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'track',
          pageBuilder: (c, s) => _page(
            s,
            dealer_track.TrackTechnicianScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'rate',
          pageBuilder: (c, s) => _page(
            s,
            dealer_rate.DealerRateTechnicianScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'chat',
          pageBuilder: (c, s) => _page(
            s,
            shared_chat.ChatScreen(
              jobId: s.pathParameters['id'] ?? '',
              backRoute: '/dealer/jobs/${s.pathParameters['id']}',
            ),
          ),
        ),
        GoRoute(
          path: 'pay',
          pageBuilder: (c, s) {
            final id = s.pathParameters['id'] ?? '';
            final amount =
                (s.extra is Map ? (s.extra as Map)['amount'] : null)
                    as double? ??
                0.0;
            return _page(
              s,
              dealer_payment.PaymentScreen(jobId: id, amount: amount),
            );
          },
        ),
        GoRoute(
          path: 'warranty-claim',
          pageBuilder: (c, s) => _page(
            s,
            dealer_warranty_form.WarrantyClaimFormScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'warranty-claims',
          pageBuilder: (c, s) => _page(
            s,
            dealer_job_warranty.DealerJobWarrantyClaimsScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'dispute',
          pageBuilder: (c, s) => _page(
            s,
            dealer_dispute_form.JobDisputeFormScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'service-record',
          pageBuilder: (c, s) {
            final id = s.pathParameters['id'] ?? '';
            return _page(
              s,
              service_record.ServiceCompletionRecordScreen(
                jobId: id,
                allowDownloadAndPrint: true,
                backRoute: '/dealer/jobs/$id',
              ),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.dealerWarrantyClaims,
      pageBuilder: (c, s) =>
          _page(s, const dealer_warranty_list.WarrantyClaimsListScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerUnderWarrantyJobs,
      pageBuilder: (c, s) =>
          _page(s, const dealer_under_warranty.DealerUnderWarrantyJobsScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerServiceCompletionRecords,
      pageBuilder: (c, s) => _page(
        s,
        const dealer_service_records.ServiceCompletionRecordsScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.dealerDocuments,
      pageBuilder: (c, s) =>
          _page(s, const dealer_documents.DealerDocumentsScreen()),
    ),
    GoRoute(
      path: '/dealer/warranty-claims/:claimId',
      pageBuilder: (c, s) => _page(
        s,
        dealer_warranty_detail.WarrantyClaimDetailScreen(
          claimId: s.pathParameters['claimId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.dealerProfile,
      pageBuilder: (c, s) => _page(s, const dealer.DealerProfileScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerEditProfile,
      pageBuilder: (c, s) =>
          _page(s, const dealer_edit.DealerEditProfileScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerWallet,
      pageBuilder: (c, s) => _page(s, const dealer_wallet.DealerWalletScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerKyc,
      pageBuilder: (c, s) => _page(s, const dealer_kyc.DealerKycScreen()),
    ),
    GoRoute(
      path: RouteNames.dealerSettlementAccount,
      pageBuilder: (c, s) => _page(
        s,
        const settlement.SettlementAccountScreen(
          backRoute: RouteNames.dealerProfile,
        ),
      ),
    ),
    // Technician placeholders
    GoRoute(
      path: RouteNames.technicianMyJobs,
      pageBuilder: (c, s) =>
          _page(s, const tech_my_jobs.TechnicianMyJobsScreen()),
    ),
    GoRoute(
      path: '/technician/jobs/:id',
      pageBuilder: (c, s) => _page(
        s,
        tech_job_detail.TechnicianJobDetailScreen(
          jobId: s.pathParameters['id'] ?? '',
        ),
      ),
      routes: [
        GoRoute(
          path: 'bidding',
          pageBuilder: (c, s) => _page(
            s,
            tech_bidding.TechnicianBiddingScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'execute',
          pageBuilder: (c, s) => _page(
            s,
            tech_execution.JobExecutionScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'finish',
          pageBuilder: (c, s) => _page(
            s,
            tech_finish_job.FinishJobScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'material-return',
          pageBuilder: (c, s) => _page(
            s,
            tech_material_return.MaterialReturnScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'rate',
          pageBuilder: (c, s) => _page(
            s,
            tech_rate.TechnicianRateDealerScreen(
              jobId: s.pathParameters['id'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'chat',
          pageBuilder: (c, s) => _page(
            s,
            shared_chat.ChatScreen(
              jobId: s.pathParameters['id'] ?? '',
              backRoute: '/technician/jobs/${s.pathParameters['id']}',
            ),
          ),
        ),
        GoRoute(
          path: 'service-record',
          pageBuilder: (c, s) {
            final id = s.pathParameters['id'] ?? '';
            return _page(
              s,
              service_record.ServiceCompletionRecordScreen(
                jobId: id,
                allowDownloadAndPrint: false,
                backRoute: '/technician/jobs/$id',
              ),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/technician/warranty-claims/:claimId',
      pageBuilder: (c, s) => _page(
        s,
        tech_warranty_detail.TechnicianWarrantyClaimDetailScreen(
          claimId: s.pathParameters['claimId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.technicianPaymentReceipts,
      pageBuilder: (c, s) => _page(
        s,
        const tech_payment_receipts.TechnicianPaymentReceiptsScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.technicianPayoutHistory,
      pageBuilder: (c, s) =>
          _page(s, const tech_payout_history.PayoutHistoryScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianProfile,
      pageBuilder: (c, s) => _page(s, const tech.TechnicianProfileScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianEditProfile,
      pageBuilder: (c, s) =>
          _page(s, const tech_edit.TechnicianEditProfileScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianEditSkills,
      pageBuilder: (c, s) => _page(s, const TechnicianSkillsEditScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianEditServiceArea,
      pageBuilder: (c, s) => _page(s, const TechnicianServiceAreaEditScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianWallet,
      pageBuilder: (c, s) =>
          _page(s, const tech_wallet.TechnicianWalletScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianKyc,
      pageBuilder: (c, s) => _page(s, const tech_kyc.TechnicianKycScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianSettlementAccount,
      pageBuilder: (c, s) => _page(
        s,
        const settlement.SettlementAccountScreen(
          backRoute: RouteNames.technicianHome,
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.technicianIncomingJob,
      pageBuilder: (c, s) =>
          _page(s, IncomingJobScreen(jobId: s.uri.queryParameters['jobId'])),
    ),
    GoRoute(
      path: RouteNames.technicianWarrantyClaims,
      pageBuilder: (c, s) => _page(s, const TechnicianWarrantyClaimsScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianUnderWarrantyJobs,
      pageBuilder: (c, s) => _page(
        s,
        const tech_under_warranty.TechnicianUnderWarrantyJobsScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.technicianDisputes,
      pageBuilder: (c, s) => _page(s, const TechnicianDisputesScreen()),
    ),
    GoRoute(
      path: RouteNames.technicianQuickStart,
      pageBuilder: (c, s) => _page(s, const TechnicianQuickStartScreen()),
    ),
    GoRoute(
      path: RouteNames.customerRate,
      pageBuilder: (c, s) => _page(
        s,
        CustomerRatePage(
          jobId: s.uri.queryParameters['jobId'],
          token: s.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.customerChat,
      pageBuilder: (c, s) => _page(
        s,
        CustomerChatPage(
          jobId: s.uri.queryParameters['jobId'],
          token: s.uri.queryParameters['token'],
        ),
      ),
    ),
    // --- Marketplace (B2B extension; does not alter legacy job/warranty routes)
    GoRoute(
      path: RouteNames.marketplaceHome,
      pageBuilder: (c, s) => _page(s, const MarketplaceHomeScreen()),
    ),
    GoRoute(
      path: RouteNames.marketplaceSearch,
      pageBuilder: (c, s) => _page(s, const MarketplaceSearchScreen()),
    ),
    GoRoute(
      path: '/marketplace/category/:categoryId',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceCategoryScreen(
          categoryId: s.pathParameters['categoryId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/marketplace/p/:productId',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceProductDetailScreen(
          productId: s.pathParameters['productId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.marketplaceCart,
      pageBuilder: (c, s) => _page(s, const MarketplaceCartScreen()),
    ),
    GoRoute(
      path: RouteNames.marketplaceCheckout,
      pageBuilder: (c, s) => _page(s, const MarketplaceCheckoutScreen()),
    ),
    GoRoute(
      path: RouteNames.marketplacePaymentResult,
      pageBuilder: (c, s) => _page(
        s,
        MarketplacePaymentResultScreen(
          orderId: s.uri.queryParameters['orderId'] ?? '',
          method: s.uri.queryParameters['method'] ?? '',
          paymentVerified: s.uri.queryParameters['verified'] == '1',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.marketplaceOrders,
      pageBuilder: (c, s) => _page(s, const MarketplaceOrdersScreen()),
    ),
    GoRoute(
      path: '/marketplace/orders/:orderId',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceOrderDetailScreen(
          orderId: s.pathParameters['orderId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.marketplaceRfqNew,
      pageBuilder: (c, s) => _page(s, const MarketplaceRfqNewScreen()),
    ),
    GoRoute(
      path: '/marketplace/rfq/:rfqId',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceRfqDetailScreen(rfqId: s.pathParameters['rfqId'] ?? ''),
      ),
    ),
    GoRoute(
      path: RouteNames.marketplaceSellerHub,
      pageBuilder: (c, s) => _page(s, const MarketplaceSellerHubScreen()),
    ),
    GoRoute(
      path: RouteNames.marketplaceSellerListings,
      pageBuilder: (c, s) => _page(s, const MarketplaceSellerListingsScreen()),
    ),
    GoRoute(
      path: RouteNames.marketplaceSellerListingNew,
      pageBuilder: (c, s) =>
          _page(s, const MarketplaceSellerListingEditorScreen()),
    ),
    GoRoute(
      path: '/marketplace/seller/listings/:listingId/edit',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceSellerListingEditorScreen(
          listingId: s.pathParameters['listingId'],
        ),
      ),
    ),
    GoRoute(
      path: '/marketplace/seller/listings/:listingId/manage',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceSellerPublishedManageScreen(
          listingId: s.pathParameters['listingId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.marketplaceSellerRequests,
      pageBuilder: (c, s) =>
          _page(s, const MarketplaceSellerOrderRequestsScreen()),
    ),
    GoRoute(
      path: '/marketplace/seller/order-requests/:requestId',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceSellerRequestDetailScreen(
          requestId: s.pathParameters['requestId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.marketplaceSellerShipments,
      pageBuilder: (c, s) => _page(s, const MarketplaceSellerShipmentsScreen()),
    ),
    GoRoute(
      path: '/marketplace/seller/shipments/:shipmentId',
      pageBuilder: (c, s) => _page(
        s,
        MarketplaceSellerShipmentDetailScreen(
          shipmentId: s.pathParameters['shipmentId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.marketplaceSellerPayouts,
      pageBuilder: (c, s) => _page(s, const MarketplaceSellerPayoutsScreen()),
    ),
    GoRoute(
      path: '/admin/marketplace/taxonomy/:categoryId/subs/:subcategoryId/attrs',
      pageBuilder: (c, s) => _page(
        s,
        AdminMarketplaceAttributesScreen(
          categoryId: s.pathParameters['categoryId'] ?? '',
          subcategoryId: s.pathParameters['subcategoryId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/admin/marketplace/taxonomy/:categoryId/subs',
      pageBuilder: (c, s) => _page(
        s,
        AdminMarketplaceSubcategoriesScreen(
          categoryId: s.pathParameters['categoryId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceTaxonomy,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceTaxonomyScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceHome,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceHomeScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceProductsQueue,
      pageBuilder: (c, s) =>
          _page(s, const AdminMarketplaceProductsQueueScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceCatalogProducts,
      pageBuilder: (c, s) =>
          _page(s, const AdminMarketplaceCatalogProductsScreen()),
    ),
    GoRoute(
      path: '/admin/marketplace/catalog/products/:catalogProductId/edit',
      pageBuilder: (c, s) => _page(
        s,
        AdminMarketplaceCatalogProductEditScreen(
          productId: s.pathParameters['catalogProductId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/admin/marketplace/products/:listingId/review',
      pageBuilder: (c, s) => _page(
        s,
        AdminMarketplaceProductReviewScreen(
          listingId: s.pathParameters['listingId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.adminMarketplacePricing,
      pageBuilder: (c, s) => _page(s, const AdminMarketplacePricingScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceOrders,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceOrdersScreen()),
    ),
    GoRoute(
      path: '/admin/marketplace/orders/:orderId/detail',
      pageBuilder: (c, s) => _page(
        s,
        AdminMarketplaceOrderDetailScreen(
          orderId: s.pathParameters['orderId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceRfq,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceRfqScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceCodRules,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceCodRulesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceInward,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceInwardScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceQc,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceQcScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceDispatch,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceDispatchScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplacePayouts,
      pageBuilder: (c, s) => _page(s, const AdminMarketplacePayoutsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceSellers,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceSellersScreen()),
    ),
    GoRoute(
      path: RouteNames.adminMarketplaceAudit,
      pageBuilder: (c, s) => _page(s, const AdminMarketplaceAuditScreen()),
    ),

    // Admin — Supabase Shop
    GoRoute(
      path: RouteNames.adminShopHome,
      pageBuilder: (c, s) => _page(s, const AdminShopHubScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopCategories,
      pageBuilder: (c, s) => _page(s, const AdminShopCategoriesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopSubCategories,
      pageBuilder: (c, s) => _page(s, const AdminShopSubCategoriesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopSubCategoryCreate,
      pageBuilder: (c, s) => _page(s, const AdminShopSubCategoryEditorScreen()),
    ),
    GoRoute(
      path: '/admin/shop/sub-categories/new/:categoryId',
      pageBuilder: (c, s) => _page(
        s,
        AdminShopSubCategoryEditorScreen(
          initialCategoryId: s.pathParameters['categoryId'],
        ),
      ),
    ),
    GoRoute(
      path: '/admin/shop/sub-categories/:subCategoryId/edit',
      pageBuilder: (c, s) => _page(
        s,
        AdminShopSubCategoryEditorScreen(
          subCategoryId: s.pathParameters['subCategoryId'],
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.adminShopAttributeMaster,
      pageBuilder: (c, s) => _page(s, const AdminShopAttributeMasterScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopAttributeCreate,
      pageBuilder: (c, s) => _page(s, const AdminShopAttributeEditorScreen()),
    ),
    GoRoute(
      path: '/admin/shop/attribute-master/:attributeId/edit',
      pageBuilder: (c, s) => _page(
        s,
        AdminShopAttributeEditorScreen(
          attributeId: s.pathParameters['attributeId'],
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.adminShopAttributeGroups,
      pageBuilder: (c, s) => _page(s, const AdminShopAttributeGroupsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopBrands,
      pageBuilder: (c, s) => _page(s, const AdminShopBrandsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopBulkImport,
      pageBuilder: (c, s) => _page(s, const AdminShopBulkImportScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopProductImport,
      pageBuilder: (c, s) => _page(s, const AdminShopProductImportScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopProducts,
      pageBuilder: (c, s) => _page(s, const AdminShopProductsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopProductCreate,
      pageBuilder: (c, s) => _page(s, const AdminShopProductEditorScreen()),
    ),
    GoRoute(
      path: '/admin/shop/products/new/:subCategoryId',
      pageBuilder: (c, s) => _page(
        s,
        AdminShopProductEditorScreen(
          initialSubCategoryId: s.pathParameters['subCategoryId'],
        ),
      ),
    ),
    GoRoute(
      path: '/admin/shop/products/:productId/edit',
      pageBuilder: (c, s) => _page(
        s,
        AdminShopProductEditorScreen(
          productId: s.pathParameters['productId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.adminShopInventory,
      pageBuilder: (c, s) => _page(s, const AdminShopInventoryScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopPurchases,
      pageBuilder: (c, s) => _page(s, const AdminShopPurchasesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopSuppliers,
      pageBuilder: (c, s) => _page(s, const AdminShopSuppliersScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopCustomers,
      pageBuilder: (c, s) => _page(s, const AdminShopCustomersScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopQuotations,
      pageBuilder: (c, s) => _page(s, const AdminShopQuotationsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopReports,
      pageBuilder: (c, s) => _page(s, const AdminShopReportsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminShopOrders,
      pageBuilder: (c, s) => _page(s, const AdminShopOrdersScreen()),
    ),

    // Admin — Calculator
    GoRoute(
      path: RouteNames.adminCalculatorHome,
      pageBuilder: (c, s) => _page(s, const AdminCalculatorHubScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorFamilies,
      pageBuilder: (c, s) => _page(s, const AdminCalculatorFamiliesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorFamilyCreate,
      pageBuilder: (c, s) =>
          _page(s, const AdminCalculatorFamilyEditorScreen()),
    ),
    GoRoute(
      path: '/admin/calculator/families/:familyId/edit',
      pageBuilder: (c, s) => _page(
        s,
        AdminCalculatorFamilyEditorScreen(
          familyId: s.pathParameters['familyId'],
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorQuestionGroups,
      pageBuilder: (c, s) =>
          _page(s, const AdminCalculatorQuestionGroupsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorOptions,
      pageBuilder: (c, s) => _page(s, const AdminCalculatorOptionsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorTemplates,
      pageBuilder: (c, s) => _page(s, const AdminCalculatorFamiliesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorQuestions,
      pageBuilder: (c, s) => _page(s, const AdminCalculatorOptionsScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorRules,
      pageBuilder: (c, s) =>
          _page(s, const AdminCalculatorFamilyRulesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorRuleProducts,
      pageBuilder: (c, s) =>
          _page(s, const AdminCalculatorFamiliesScreen()),
    ),
    GoRoute(
      path: RouteNames.adminCalculatorQuotationBuilder,
      pageBuilder: (c, s) =>
          _page(s, const AdminCalculatorFamiliesScreen()),
    ),

    // User — Shop
    GoRoute(
      path: RouteNames.shopHome,
      pageBuilder: (c, s) => _page(s, const ShopHomeScreen()),
    ),
    GoRoute(
      path: '/shop/category/:categoryId',
      pageBuilder: (c, s) => _page(
        s,
        ShopCategoryScreen(categoryId: s.pathParameters['categoryId'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/shop/product/:productId',
      pageBuilder: (c, s) => _page(
        s,
        ShopProductDetailScreen(productId: s.pathParameters['productId'] ?? ''),
      ),
    ),
    GoRoute(
      path: RouteNames.shopCart,
      pageBuilder: (c, s) => _page(s, const ShopCartScreen()),
    ),
    GoRoute(
      path: RouteNames.shopCheckout,
      pageBuilder: (c, s) => _page(s, const ShopCheckoutScreen()),
    ),
    GoRoute(
      path: RouteNames.shopOrders,
      pageBuilder: (c, s) => _page(s, const ShopOrdersScreen()),
    ),

    GoRoute(
      path: RouteNames.accountHome,
      pageBuilder: (c, s) => _page(s, const CustomerAccountHubScreen()),
    ),
    GoRoute(
      path: RouteNames.accountOrders,
      pageBuilder: (c, s) => _page(s, const CustomerOrdersScreen()),
    ),
    GoRoute(
      path: '/account/orders/:orderId',
      pageBuilder: (c, s) => _page(
        s,
        CustomerOrderDetailScreen(orderId: s.pathParameters['orderId'] ?? ''),
      ),
    ),

    // User — Calculator
    GoRoute(
      path: RouteNames.calculatorHome,
      pageBuilder: (c, s) => _page(s, const CalculatorHomeScreen()),
    ),
    GoRoute(
      path: '/app/calculator/template/:templateId',
      pageBuilder: (c, s) => _page(
        s,
        CalculatorTemplateScreen(
          templateId: s.pathParameters['templateId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.calculatorQuotations,
      pageBuilder: (c, s) => _page(s, const CalculatorQuotationsScreen()),
    ),
    GoRoute(
      path: '/app/calculator/quotations/:quotationId',
      pageBuilder: (c, s) => _page(
        s,
        CalculatorQuotationDetailScreen(
          quotationId: s.pathParameters['quotationId'] ?? '',
        ),
      ),
    ),
  ],
);

CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    routerTransitionPage(state, child);

CustomTransitionPage<void> _publicPage(GoRouterState state, Widget child) =>
    publicTransitionPage(state, child);

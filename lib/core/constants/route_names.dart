/// Route path constants for go_router. Single source of truth.
abstract final class RouteNames {
  // Public Web Experience (new web_public module)
  static const String publicHome = '/';
  static const String publicStore = '/store';
  static String publicStoreCategory(String slug) => '/store/category/$slug';
  static const String publicCart = '/store/cart';
  static const String publicCheckout = '/store/checkout';
  static const String publicProductDetail = '/product/:slug';
  static const String publicCalculatorList = '/calculator';
  static const String publicCalculatorDetail = '/calculator/:slug';
  static const String publicServices = '/services';
  // Dynamic SEO services hub (service list + city picker)
  static const String publicServicesInstallations = '/services/installations';
  static const String publicServicesCities = '/services/cities';
  static const String publicBlogDetail = '/blog/:slug';
  static String publicBlog(String slug) => '/blog/$slug';
  static String publicSeoLanding(String citySlug, String serviceSlug) => '/$citySlug/$serviceSlug';
  static const String publicSeoLandingPattern = '/:citySlug/:serviceSlug';
  static const String publicConnect = '/connect';
  static const String publicAbout = '/about';
  static const String publicContact = '/contact';
  
  // Legal pages (required)
  static const String webPrivacyPolicy = '/privacy-policy';
  static const String webDataDeletion = '/data-deletion';

  // Auth
  static const String splash = '/splash';
  static const String appWalkthrough = '/walkthrough';
  static const String phoneEntry = '/phone';
  static const String otpVerify = '/otp';
  static const String serviceAreaPicker = '/service-area';
  static const String serviceAreaDetails = '/service-area/details';
  static const String roleChoice = '/role-choice';
  static const String login = '/login';
  static const String registerDealer = '/register/dealer';
  static const String registerTechnician = '/register/technician';
  static const String registerCustomer = '/register/customer';
  static const String pendingApproval = '/pending-approval';
  static const String successAnimation = '/success';
  /// Public verification page for service completion record (no auth). Use ?recordId=xxx
  static const String verifyRecord = '/verify';

  /// Legal documents (shared: dealer & technician). Menu and viewer.
  static const String legalMenu = '/legal';
  static String legalDocumentView(String documentId) => '/legal/$documentId';

  // Support & settings (shared)
  static const String settings = '/settings';
  static const String supportHome = '/support';
  static const String supportFaq = '/support/faq';
  static const String supportCreateTicket = '/support/create-ticket';
  static const String supportTickets = '/support/tickets';
  static const String offers = '/offers';
  static String supportHomeForRole(String role) => '$supportHome?role=$role';
  static String supportFaqForRole(String role) => '$supportFaq?role=$role';

  // Admin
  static const String adminHome = '/admin';
  static const String adminPendingApprovals = '/admin/pending-approvals';
  static String adminPendingApprovalDetail(String uid) => '/admin/pending-approvals/detail/$uid';
  static const String adminProfileApprovals = '/admin/profile-approvals';
  static const String adminMasterData = '/admin/master';
  static const String adminJobTypes = '/admin/master/job-types';
  static const String adminSectors = '/admin/master/sectors';
  static const String adminSectorSubOptions = '/admin/master/sector-sub-options';
  static const String adminSkills = '/admin/master/skills';
  static const String adminIndustryTypes = '/admin/master/industry-types';
  static const String adminIndustrySubOptions = '/admin/master/industry-sub-options';
  static const String adminRateMatrix = '/admin/master/rate-matrix';
  static const String adminDefaultWarranty = '/admin/master/default-warranty';
  static const String adminWiringTypes = '/admin/master/wiring-types';
  static const String adminWiringRateConfig = '/admin/master/wiring-rate-config';
  static const String adminPlatformChargeConfig = '/admin/master/platform-charge-config';
  static const String adminJobLimitConfig = '/admin/master/job-limit-config';
  static const String adminTravelExpenseConfig = '/admin/master/travel-expense-config';
  static const String adminRejectionReasons = '/admin/master/rejection-reasons';
  static const String adminKyc = '/admin/kyc';
  static const String adminDealersList = '/admin/dealers';
  static const String adminTechniciansList = '/admin/technicians';
  static const String adminJobsList = '/admin/jobs';
  static String adminJobDetail(String jobId) => '/admin/jobs/$jobId';
  static String adminJobChat(String jobId) => '/admin/jobs/$jobId/chat';
  static const String adminOverrideLevel = '/admin/override-level';
  static const String adminPenaltyStatus = '/admin/penalty-status';
  static const String adminBrandKit = '/admin/brand-kit';
  static const String adminAds = '/admin/ads';
  static const String adminWarrantyClaims = '/admin/warranty-claims';
  static String adminWarrantyClaimDetail(String claimId) => '/admin/warranty-claims/$claimId';
  static const String adminEscrowApprovals = '/admin/escrow-approvals';
  static String adminEscrowApprovalDetail(String jobId) => '/admin/escrow-approvals/$jobId';
  static const String adminWarrantyClaimCategories = '/admin/master/warranty-claim-categories';
  static const String adminServiceCompletionRecords = '/admin/service-completion-records';
  static String adminServiceCompletionRecordView(String jobId) => '/admin/service-completion-records/view/$jobId';
  static const String adminFinance = '/admin/finance';
  static const String adminExpenses = '/admin/expenses';
  static const String adminFinancialDocuments = '/admin/financial-documents';
  static const String adminBillingGst = '/admin/billing-gst';
  static const String adminDisputes = '/admin/disputes';
  static String adminDisputeDetail(String disputeId) => '/admin/disputes/$disputeId';
  static const String adminLegalLogs = '/admin/legal-logs';
  static const String adminLegalDocuments = '/admin/legal-documents';
  static String adminLegalDocumentEdit(String documentId) => '/admin/legal-documents/edit/$documentId';
  static const String adminTrustScoreHistory = '/admin/trust-score-history';
  static String adminTrustScoreHistoryForUser(String uid) => '/admin/trust-score-history/$uid';
  static const String adminAdjustTrustScore = '/admin/adjust-trust-score';
  static const String adminStrikes = '/admin/strikes';
  static String adminStrikeHistoryForTechnician(String uid) => '/admin/strikes/technician/$uid';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminJobEvidence = '/admin/job-evidence';
  static String adminJobEvidenceView(String jobId) => '/admin/job-evidence/$jobId';
  static const String adminPlatformDashboard = '/admin/platform-dashboard';
  static const String adminFraudAlerts = '/admin/fraud-alerts';
  static const String adminSupportTickets = '/admin/support-tickets';
  static String adminSupportTicketDetail(String ticketId) => '/admin/support-tickets/$ticketId';
  static const String adminAppUpdates = '/admin/app-updates';
  static const String adminSendPush = '/admin/send-push';

  // Dealer
  static const String dealerHome = '/dealer';
  static const String dealerNotifications = '/dealer/notifications';
  static const String dealerPostJob = '/dealer/post-job';
  static const String dealerDraftJobs = '/dealer/drafts';
  static const String dealerMyJobs = '/dealer/jobs';
  static const String dealerJobDetail = '/dealer/jobs/:id';
  static const String dealerTrackTechnician = '/dealer/jobs/:id/track';
  static const String dealerBidding = '/dealer/jobs/:id/bidding';
  static const String dealerProfile = '/dealer/profile';
  static const String dealerEditProfile = '/dealer/profile/edit';
  static const String dealerKyc = '/dealer/kyc';
  static const String dealerSettlementAccount = '/dealer/settlement-account';
  static const String dealerWallet = '/dealer/wallet';
  static const String dealerRateTechnician = '/dealer/jobs/:id/rate';
  static const String dealerChat = '/dealer/jobs/:id/chat';
  static const String dealerWarrantyClaims = '/dealer/warranty-claims';
  static const String dealerUnderWarrantyJobs = '/dealer/under-warranty-jobs';
  static String dealerWarrantyClaimForm(String jobId) => '/dealer/jobs/$jobId/warranty-claim';
  static String dealerWarrantyClaimDetail(String claimId) => '/dealer/warranty-claims/$claimId';
  static String dealerJobWarrantyClaims(String jobId) => '/dealer/jobs/$jobId/warranty-claims';
  static String dealerJobDispute(String jobId) => '/dealer/jobs/$jobId/dispute';
  static String dealerServiceRecord(String jobId) => '/dealer/jobs/$jobId/service-record';
  static const String dealerServiceCompletionRecords = '/dealer/service-completion-records';
  static const String dealerDocuments = '/dealer/documents';

  // Technician
  static const String technicianHome = '/technician';
  static const String technicianNotifications = '/technician/notifications';
  static const String technicianIncomingJob = '/technician/incoming';
  static const String technicianBidding = '/technician/jobs/:id/bidding';
  static const String technicianMyJobs = '/technician/jobs';
  static const String technicianJobDetail = '/technician/jobs/:id';
  static const String technicianJobExecution = '/technician/jobs/:id/execute';
  static const String technicianFinishJob = '/technician/jobs/:id/finish';
  static const String technicianProfile = '/technician/profile';
  static const String technicianEditProfile = '/technician/profile/edit';
  static const String technicianEditSkills = '/technician/profile/edit/skills';
  static const String technicianEditServiceArea = '/technician/profile/edit/service-area';
  static const String technicianKyc = '/technician/kyc';
  static const String technicianSettlementAccount = '/technician/settlement-account';
  static const String technicianWallet = '/technician/wallet';
  static const String technicianRateDealer = '/technician/jobs/:id/rate';
  static const String technicianChat = '/technician/jobs/:id/chat';
  static const String technicianWarrantyClaims = '/technician/warranty-claims';
  static const String technicianUnderWarrantyJobs = '/technician/under-warranty-jobs';
  static const String technicianDisputes = '/technician/disputes';
  static String technicianWarrantyClaimDetail(String claimId) => '/technician/warranty-claims/$claimId';
  static String technicianServiceRecord(String jobId) => '/technician/jobs/$jobId/service-record';
  static const String technicianPaymentReceipts = '/technician/payment-receipts';
  static const String technicianPayoutHistory = '/technician/payout-history';
  static const String technicianQuickStart = '/technician/quick-start';
  // Customer (web)
  static const String customerRate = '/rate';
  static const String customerChat = '/chat';

  // --- Marketplace (B2B hub; isolated from job routes) ---
  static const String marketplaceHome = '/marketplace';
  static const String marketplaceSearch = '/marketplace/search';
  static String marketplaceCategory(String categoryId) => '/marketplace/category/$categoryId';
  static String marketplaceProduct(String productId) => '/marketplace/p/$productId';
  static const String marketplaceCart = '/marketplace/cart';
  static const String marketplaceCheckout = '/marketplace/checkout';
  static const String marketplacePaymentResult = '/marketplace/payment-result';
  static const String marketplaceOrders = '/marketplace/orders';
  static String marketplaceOrderDetail(String orderId) => '/marketplace/orders/$orderId';
  static String marketplaceRfqDetail(String rfqId) => '/marketplace/rfq/$rfqId';
  static const String marketplaceRfqNew = '/marketplace/rfq/new';

  static const String marketplaceSellerHub = '/marketplace/seller';
  static const String marketplaceSellerListings = '/marketplace/seller/listings';
  static const String marketplaceSellerListingNew = '/marketplace/seller/listings/new';
  static String marketplaceSellerListingEdit(String listingId) => '/marketplace/seller/listings/$listingId/edit';
  static String marketplaceSellerListingManage(String listingId) => '/marketplace/seller/listings/$listingId/manage';
  static const String marketplaceSellerRequests = '/marketplace/seller/order-requests';
  static String marketplaceSellerRequestDetail(String requestId) => '/marketplace/seller/order-requests/$requestId';
  static const String marketplaceSellerShipments = '/marketplace/seller/shipments';
  static String marketplaceSellerShipment(String shipmentId) => '/marketplace/seller/shipments/$shipmentId';
  static const String marketplaceSellerPayouts = '/marketplace/seller/payouts';

  static const String adminMarketplaceHome = '/admin/marketplace';
  static const String adminMarketplaceTaxonomy = '/admin/marketplace/taxonomy';
  static String adminMarketplaceTaxonomySubs(String categoryId) => '/admin/marketplace/taxonomy/$categoryId/subs';
  static String adminMarketplaceTaxonomyAttrs(String categoryId, String subcategoryId) =>
      '/admin/marketplace/taxonomy/$categoryId/subs/$subcategoryId/attrs';
  static const String adminMarketplaceProductsQueue = '/admin/marketplace/products/queue';
  static String adminMarketplaceProductReview(String productId) => '/admin/marketplace/products/$productId/review';
  static const String adminMarketplaceCatalogProducts = '/admin/marketplace/catalog/products';
  static String adminMarketplaceCatalogProductEdit(String catalogProductId) =>
      '/admin/marketplace/catalog/products/$catalogProductId/edit';
  static const String adminMarketplacePricing = '/admin/marketplace/pricing';
  static const String adminMarketplaceOrders = '/admin/marketplace/orders';
  static String adminMarketplaceOrderDetail(String orderId) => '/admin/marketplace/orders/$orderId/detail';
  static const String adminMarketplaceRfq = '/admin/marketplace/rfq';
  static const String adminMarketplaceCodRules = '/admin/marketplace/cod-rules';
  static const String adminMarketplaceInward = '/admin/marketplace/inward';
  static const String adminMarketplaceQc = '/admin/marketplace/qc';
  static const String adminMarketplaceDispatch = '/admin/marketplace/dispatch';
  static const String adminMarketplacePayouts = '/admin/marketplace/payouts';
  static const String adminMarketplaceSellers = '/admin/marketplace/sellers';
  static const String adminMarketplaceAudit = '/admin/marketplace/audit';

  // Admin — Supabase Shop
  static const String adminShopHome = '/admin/shop';
  static const String adminShopCategories = '/admin/shop/categories';
  static const String adminShopSubCategories = '/admin/shop/sub-categories';
  static const String adminShopSubCategoryCreate = '/admin/shop/sub-categories/new';
  static String adminShopSubCategoryCreateInCategory(String categoryId) =>
      '/admin/shop/sub-categories/new/$categoryId';
  static String adminShopSubCategoryEdit(String subCategoryId) =>
      '/admin/shop/sub-categories/$subCategoryId/edit';

  static String? parseAdminShopSubCategoryEditId(String route) {
    const prefix = '$adminShopSubCategories/';
    const suffix = '/edit';
    if (!route.startsWith(prefix) || !route.endsWith(suffix) || route.contains('/new')) return null;
    final id = route.substring(prefix.length, route.length - suffix.length);
    return id.isEmpty ? null : id;
  }

  static String? parseAdminShopSubCategoryCreateCategoryId(String route) {
    const prefix = '$adminShopSubCategoryCreate/';
    if (!route.startsWith(prefix)) return null;
    return route.substring(prefix.length);
  }
  static const String adminShopAttributeMaster = '/admin/shop/attribute-master';
  static const String adminShopAttributeCreate = '/admin/shop/attribute-master/new';
  static String adminShopAttributeEdit(String attributeId) => '/admin/shop/attribute-master/$attributeId/edit';

  static bool isAdminShopAttributeEditorRoute(String route) =>
      route == adminShopAttributeCreate || parseAdminShopAttributeEditId(route) != null;

  static String? parseAdminShopAttributeEditId(String route) {
    const prefix = '$adminShopAttributeMaster/';
    const suffix = '/edit';
    if (!route.startsWith(prefix) || !route.endsWith(suffix)) return null;
    final id = route.substring(prefix.length, route.length - suffix.length);
    if (id.isEmpty || id == 'new') return null;
    return id;
  }
  static const String adminShopAttributeGroups = '/admin/shop/attribute-groups';
  static const String adminShopBrands = '/admin/shop/brands';
  static const String adminShopBulkImport = '/admin/shop/bulk-import';
  static const String adminShopProductImport = '/admin/shop/product-import';
  static const String adminShopProducts = '/admin/shop/products';
  static const String adminShopProductCreate = '/admin/shop/products/new';
  static String adminShopProductCreateInSubCategory(String subCategoryId) =>
      '/admin/shop/products/new/$subCategoryId';

  static String? parseAdminShopProductCreateSubCategoryId(String route) {
    const prefix = '$adminShopProductCreate/';
    if (!route.startsWith(prefix)) return null;
    return route.substring(prefix.length);
  }
  static String adminShopProductEdit(String productId) => '/admin/shop/products/$productId/edit';

  static String? parseAdminShopProductEditId(String route) {
    const prefix = '$adminShopProducts/';
    const suffix = '/edit';
    if (!route.startsWith(prefix) || !route.endsWith(suffix) || route.contains('/new')) return null;
    final id = route.substring(prefix.length, route.length - suffix.length);
    return id.isEmpty ? null : id;
  }
  static const String adminShopInventory = '/admin/shop/inventory';
  static const String adminShopPurchases = '/admin/shop/purchases';
  static const String adminShopSuppliers = '/admin/shop/suppliers';
  static const String adminShopCustomers = '/admin/shop/customers';
  static const String adminShopQuotations = '/admin/shop/quotations';
  static const String adminShopReports = '/admin/shop/reports';
  static const String adminShopOrders = '/admin/shop/orders';

  // Admin — Calculator
  static const String adminCalculatorHome = '/admin/calculator';
  static const String adminCalculatorFamilies = '/admin/calculator/families';
  static const String adminCalculatorFamilyCreate = '/admin/calculator/families/new';
  static String adminCalculatorFamilyEdit(String familyId) =>
      '/admin/calculator/families/$familyId/edit';
  static String? parseAdminCalculatorFamilyEditId(String route) {
    const prefix = '$adminCalculatorFamilies/';
    const suffix = '/edit';
    if (!route.startsWith(prefix) ||
        !route.endsWith(suffix) ||
        route.contains('/new')) {
      return null;
    }
    final id = route.substring(prefix.length, route.length - suffix.length);
    return id.isEmpty ? null : id;
  }
  static const String adminCalculatorQuestionGroups =
      '/admin/calculator/question-groups';
  static const String adminCalculatorOptions = '/admin/calculator/options';
  static const String adminCalculatorTemplates = '/admin/calculator/templates';
  static const String adminCalculatorQuestions = '/admin/calculator/questions';
  static const String adminCalculatorRules = '/admin/calculator/rules';
  static const String adminCalculatorRuleProducts = '/admin/calculator/rule-products';
  static const String adminCalculatorQuotationBuilder = '/admin/calculator/quotation-builder';

  // Admin — SEO Engine
  static const String adminSeoHome = '/admin/seo';
  static const String adminSeoCities = '/admin/seo/cities';
  static const String adminSeoCityCreate = '/admin/seo/cities/new';
  static String adminSeoCityEdit(String cityId) => '/admin/seo/cities/$cityId/edit';
  static const String adminSeoServices = '/admin/seo/services';
  static const String adminSeoServiceCreate = '/admin/seo/services/new';
  static String adminSeoServiceEdit(String serviceId) => '/admin/seo/services/$serviceId/edit';
  static const String adminSeoBlogPosts = '/admin/seo/blogs';
  static const String adminSeoBlogCreate = '/admin/seo/blogs/new';
  static String adminSeoBlogEdit(String blogId) => '/admin/seo/blogs/$blogId/edit';

  // Admin — AI Business OS
  static const String adminAiOsHome = '/admin/ai-os';
  static const String adminAiOsHowToUse = '/admin/ai-os/how-to-use';
  static const String adminAiOsCrm = '/admin/ai-os/crm';
  static const String adminAiOsLeads = '/admin/ai-os/leads';
  static const String adminAiOsCalendar = '/admin/ai-os/calendar';
  static const String adminAiOsWhatsapp = '/admin/ai-os/whatsapp';
  static const String adminAiOsVoice = '/admin/ai-os/voice';
  static const String adminAiOsCampaigns = '/admin/ai-os/campaigns';
  static const String adminAiOsKnowledge = '/admin/ai-os/knowledge';
  static const String adminAiOsProposals = '/admin/ai-os/proposals';
  static const String adminAiOsQuotations = '/admin/ai-os/quotations';
  static const String adminAiOsMarketing = '/admin/ai-os/marketing';
  static const String adminAiOsEstimator = '/admin/ai-os/estimator';
  static const String adminAiOsTickets = '/admin/ai-os/tickets';
  static const String adminAiOsProjects = '/admin/ai-os/projects';
  static const String adminAiOsReports = '/admin/ai-os/reports';
  static const String adminAiOsBilling = '/admin/ai-os/billing';
  static const String adminAiOsMarketplace = '/admin/ai-os/marketplace';
  static const String adminAiOsSettings = '/admin/ai-os/settings';
  static const String adminAiOsAcceptInvite = '/admin/ai-os/accept-invite';
  static const String adminAiOsOnboarding = '/admin/ai-os/onboarding';

  /// Public AI Business OS trial signup (Firebase + tenant bootstrap).
  static const String bosTrialSignup = '/ai-os/trial';
  static const String bosPublicChat = '/ai-os/chat';

  // User — Supabase Shop
  static const String shopHome = '/shop';
  static String shopCategory(String categoryId) => '/shop/category/$categoryId';
  static String shopProduct(String productId) => '/shop/product/$productId';
  static const String shopCart = '/shop/cart';
  static const String shopCheckout = '/shop/checkout';
  static const String shopOrders = '/shop/orders';

  // Customer account (shop + ecommerce — web + mobile)
  static const String accountHome = '/account';
  static const String accountOrders = '/account/orders';
  static String accountOrderDetail(String orderId) => '/account/orders/$orderId';
  static const String accountProfile = '/account/profile';

  // User — Calculator
  /// Authenticated in-app calculator (separate from public `/calculator` marketing routes).
  static const String calculatorHome = '/app/calculator';
  static String calculatorTemplate(String templateId) =>
      '/app/calculator/template/$templateId';
  static const String calculatorQuotations = '/app/calculator/quotations';
  static String calculatorQuotationDetail(String quotationId) =>
      '/app/calculator/quotations/$quotationId';
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../features/admin/admin_home_screen.dart';
import '../../../features/calculator/admin/admin_calculator_crud_screens.dart';
import '../../../features/calculator/admin/admin_calculator_hub_screen.dart';
import '../../../features/shop/admin/admin_shop_attribute_editor_screen.dart';
import '../../../features/shop/admin/admin_shop_attributes_screen.dart';
import '../../../features/shop/admin/admin_shop_brands_screen.dart';
import '../../../features/shop/admin/admin_shop_bulk_import_screen.dart';
import '../../../features/shop/admin/admin_shop_categories_screen.dart';
import '../../../features/shop/admin/admin_shop_hub_screen.dart';
import '../../../features/shop/admin/admin_shop_inventory_orders_screen.dart';
import '../../../features/shop/admin/admin_shop_product_editor_screen.dart';
import '../../../features/shop/admin/admin_shop_product_import_screen.dart';
import '../../../features/shop/admin/admin_shop_products_screen.dart';
import '../../../features/shop/admin/admin_shop_subcategories_screen.dart';
import '../../../features/shop/admin/admin_shop_subcategory_editor_screen.dart';
import '../../../features/shop/admin/erp/admin_shop_customers_screen.dart';
import '../../../features/shop/admin/erp/admin_shop_purchases_screen.dart';
import '../../../features/shop/admin/erp/admin_shop_quotations_screen.dart';
import '../../../features/shop/admin/erp/admin_shop_reports_screen.dart';
import '../../../features/shop/admin/erp/admin_shop_suppliers_screen.dart';
import '../../../features/seo/admin/admin_seo_blog_editor_screen.dart';
import '../../../features/seo/admin/admin_seo_blog_posts_screen.dart';
import '../../../features/seo/admin/admin_seo_cities_screen.dart';
import '../../../features/seo/admin/admin_seo_city_editor_screen.dart';
import '../../../features/seo/admin/admin_seo_hub_screen.dart';
import '../../../features/seo/admin/admin_seo_service_editor_screen.dart';
import '../../../features/seo/admin/admin_seo_services_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_accept_invite_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_billing_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_calendar_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_onboarding_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_campaigns_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_crm_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_estimator_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_how_to_use_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_hub_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_knowledge_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_leads_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_marketing_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_marketplace_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_projects_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_proposals_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_quotations_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_reports_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_settings_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_tickets_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_voice_screen.dart';
import '../../../features/ai_business_os/admin/admin_ai_os_whatsapp_screen.dart';

/// Deferred admin bundle — shop + calculator admin screens (web only).
Widget buildAdminScreen(GoRouterState state) {
  final path = state.uri.path;
  final params = state.pathParameters;

  switch (path) {
    case RouteNames.adminHome:
      return const AdminHomeScreen();
    case RouteNames.adminShopHome:
      return const AdminShopHubScreen();
    case RouteNames.adminShopCategories:
      return const AdminShopCategoriesScreen();
    case RouteNames.adminShopSubCategories:
      return const AdminShopSubCategoriesScreen();
    case RouteNames.adminShopSubCategoryCreate:
      return const AdminShopSubCategoryEditorScreen();
    case RouteNames.adminShopAttributeMaster:
      return const AdminShopAttributeMasterScreen();
    case RouteNames.adminShopAttributeCreate:
      return const AdminShopAttributeEditorScreen();
    case RouteNames.adminShopAttributeGroups:
      return const AdminShopAttributeGroupsScreen();
    case RouteNames.adminShopBrands:
      return const AdminShopBrandsScreen();
    case RouteNames.adminShopBulkImport:
      return const AdminShopBulkImportScreen();
    case RouteNames.adminShopProductImport:
      return const AdminShopProductImportScreen();
    case RouteNames.adminShopProducts:
      return const AdminShopProductsScreen();
    case RouteNames.adminShopProductCreate:
      return const AdminShopProductEditorScreen();
    case RouteNames.adminShopInventory:
      return const AdminShopInventoryScreen();
    case RouteNames.adminShopPurchases:
      return const AdminShopPurchasesScreen();
    case RouteNames.adminShopSuppliers:
      return const AdminShopSuppliersScreen();
    case RouteNames.adminShopCustomers:
      return const AdminShopCustomersScreen();
    case RouteNames.adminShopQuotations:
      return const AdminShopQuotationsScreen();
    case RouteNames.adminShopReports:
      return const AdminShopReportsScreen();
    case RouteNames.adminShopOrders:
      return const AdminShopOrdersScreen();
    case RouteNames.adminCalculatorHome:
      return AdminCalculatorHubScreen();
    case RouteNames.adminCalculatorFamilies:
      return const AdminCalculatorFamiliesScreen();
    case RouteNames.adminCalculatorFamilyCreate:
      return const AdminCalculatorFamilyEditorScreen();
    case RouteNames.adminCalculatorQuestionGroups:
      return const AdminCalculatorQuestionGroupsScreen();
    case RouteNames.adminCalculatorOptions:
      return const AdminCalculatorOptionsScreen();
    case RouteNames.adminCalculatorTemplates:
      return const AdminCalculatorFamiliesScreen();
    case RouteNames.adminCalculatorQuestions:
      return const AdminCalculatorOptionsScreen();
    case RouteNames.adminCalculatorRules:
      return const AdminCalculatorFamilyRulesScreen();
    case RouteNames.adminCalculatorRuleProducts:
      return const AdminCalculatorFamiliesScreen();
    case RouteNames.adminCalculatorQuotationBuilder:
      return const AdminCalculatorFamiliesScreen();
    case RouteNames.adminSeoHome:
      return const AdminSeoHubScreen();
    case RouteNames.adminSeoCities:
      return const AdminSeoCitiesScreen();
    case RouteNames.adminSeoCityCreate:
      return const AdminSeoCityEditorScreen();
    case RouteNames.adminSeoServices:
      return const AdminSeoServicesScreen();
    case RouteNames.adminSeoServiceCreate:
      return const AdminSeoServiceEditorScreen();
    case RouteNames.adminSeoBlogPosts:
      return const AdminSeoBlogPostsScreen();
    case RouteNames.adminSeoBlogCreate:
      return const AdminSeoBlogEditorScreen();
    case RouteNames.adminAiOsHome:
      return const AdminAiOsHubScreen();
    case RouteNames.adminAiOsHowToUse:
      return const AdminAiOsHowToUseScreen();
    case RouteNames.adminAiOsCrm:
      return const AdminAiOsCrmScreen();
    case RouteNames.adminAiOsLeads:
      return AdminAiOsLeadsScreen(
        focusLeadId: state.uri.queryParameters['lead'],
      );
    case RouteNames.adminAiOsCalendar:
      return const AdminAiOsCalendarScreen();
    case RouteNames.adminAiOsWhatsapp:
      return const AdminAiOsWhatsappScreen();
    case RouteNames.adminAiOsVoice:
      return const AdminAiOsVoiceScreen();
    case RouteNames.adminAiOsCampaigns:
      return const AdminAiOsCampaignsScreen();
    case RouteNames.adminAiOsKnowledge:
      return const AdminAiOsKnowledgeScreen();
    case RouteNames.adminAiOsProposals:
      return const AdminAiOsProposalsScreen();
    case RouteNames.adminAiOsQuotations:
      return const AdminAiOsQuotationsScreen();
    case RouteNames.adminAiOsMarketing:
      return const AdminAiOsMarketingScreen();
    case RouteNames.adminAiOsEstimator:
      return const AdminAiOsEstimatorScreen();
    case RouteNames.adminAiOsTickets:
      return const AdminAiOsTicketsScreen();
    case RouteNames.adminAiOsProjects:
      return const AdminAiOsProjectsScreen();
    case RouteNames.adminAiOsReports:
      return const AdminAiOsReportsScreen();
    case RouteNames.adminAiOsBilling:
      return const AdminAiOsBillingScreen();
    case RouteNames.adminAiOsMarketplace:
      return const AdminAiOsMarketplaceScreen();
    case RouteNames.adminAiOsSettings:
      return const AdminAiOsSettingsScreen();
    case RouteNames.adminAiOsAcceptInvite:
      return AdminAiOsAcceptInviteScreen(
        token: state.uri.queryParameters['token'],
      );
    case RouteNames.adminAiOsOnboarding:
      return const AdminAiOsOnboardingScreen();
  }

  final blogId = params['blogId'];
  if (blogId != null &&
      path.contains('/admin/seo/blogs/') &&
      path.endsWith('/edit')) {
    return AdminSeoBlogEditorScreen(blogId: blogId);
  }

  final cityId = params['cityId'];
  if (cityId != null &&
      path.contains('/admin/seo/cities/') &&
      path.endsWith('/edit')) {
    return AdminSeoCityEditorScreen(cityId: cityId);
  }

  final serviceId = params['serviceId'];
  if (serviceId != null &&
      path.contains('/admin/seo/services/') &&
      path.endsWith('/edit')) {
    return AdminSeoServiceEditorScreen(serviceId: serviceId);
  }

  final categoryId = params['categoryId'];
  if (categoryId != null &&
      path.startsWith('/admin/shop/sub-categories/new/')) {
    return AdminShopSubCategoryEditorScreen(initialCategoryId: categoryId);
  }

  final subCategoryId = params['subCategoryId'];
  if (subCategoryId != null &&
      path.endsWith('/edit') &&
      path.contains('/sub-categories/')) {
    return AdminShopSubCategoryEditorScreen(subCategoryId: subCategoryId);
  }

  final attributeId = params['attributeId'];
  if (attributeId != null &&
      path.contains('/attribute-master/') &&
      path.endsWith('/edit')) {
    return AdminShopAttributeEditorScreen(attributeId: attributeId);
  }

  final subCatForProduct = params['subCategoryId'];
  if (subCatForProduct != null &&
      path.startsWith('/admin/shop/products/new/')) {
    return AdminShopProductEditorScreen(initialSubCategoryId: subCatForProduct);
  }

  final productId = params['productId'];
  if (productId != null &&
      path.contains('/products/') &&
      path.endsWith('/edit')) {
    return AdminShopProductEditorScreen(productId: productId);
  }

  final familyId = params['familyId'];
  if (familyId != null &&
      path.contains('/admin/calculator/families/') &&
      path.endsWith('/edit')) {
    return AdminCalculatorFamilyEditorScreen(familyId: familyId);
  }

  return const AdminHomeScreen();
}

import 'package:flutter/material.dart';

import '../../core/constants/route_names.dart';
import '../calculator/admin/admin_calculator_crud_screens.dart';
import '../calculator/admin/admin_calculator_hub_screen.dart';
import '../shop/admin/admin_shop_attribute_editor_screen.dart';
import '../shop/admin/admin_shop_attributes_screen.dart';
import '../shop/admin/admin_shop_brands_screen.dart';
import '../shop/admin/admin_shop_bulk_import_screen.dart';
import '../shop/admin/admin_shop_product_import_screen.dart';
import '../shop/admin/admin_shop_categories_screen.dart';
import '../shop/admin/admin_shop_hub_screen.dart';
import '../shop/admin/admin_shop_inventory_orders_screen.dart';
import '../shop/admin/erp/admin_shop_customers_screen.dart';
import '../shop/admin/erp/admin_shop_purchases_screen.dart';
import '../shop/admin/erp/admin_shop_quotations_screen.dart';
import '../shop/admin/erp/admin_shop_reports_screen.dart';
import '../shop/admin/erp/admin_shop_suppliers_screen.dart';
import '../shop/admin/admin_shop_product_editor_screen.dart';
import '../shop/admin/admin_shop_products_screen.dart';
import '../shop/admin/admin_shop_subcategory_editor_screen.dart';
import '../shop/admin/admin_shop_subcategories_screen.dart';
import '../seo/admin/admin_seo_blog_editor_screen.dart';
import '../seo/admin/admin_seo_blog_posts_screen.dart';
import '../seo/admin/admin_seo_cities_screen.dart';
import '../seo/admin/admin_seo_city_editor_screen.dart';
import '../seo/admin/admin_seo_hub_screen.dart';
import '../seo/admin/admin_seo_service_editor_screen.dart';
import '../seo/admin/admin_seo_services_screen.dart';
import '../ai_business_os/admin/admin_ai_os_accept_invite_screen.dart';
import '../ai_business_os/admin/admin_ai_os_billing_screen.dart';
import '../ai_business_os/admin/admin_ai_os_calendar_screen.dart';
import '../ai_business_os/admin/admin_ai_os_onboarding_screen.dart';
import '../ai_business_os/admin/admin_ai_os_campaigns_screen.dart';
import '../ai_business_os/admin/admin_ai_os_crm_screen.dart';
import '../ai_business_os/admin/admin_ai_os_estimator_screen.dart';
import '../ai_business_os/admin/admin_ai_os_how_to_use_screen.dart';
import '../ai_business_os/admin/admin_ai_os_hub_screen.dart';
import '../ai_business_os/admin/admin_ai_os_knowledge_screen.dart';
import '../ai_business_os/admin/admin_ai_os_leads_screen.dart';
import '../ai_business_os/admin/admin_ai_os_marketing_screen.dart';
import '../ai_business_os/admin/admin_ai_os_marketplace_screen.dart';
import '../ai_business_os/admin/admin_ai_os_projects_screen.dart';
import '../ai_business_os/admin/admin_ai_os_proposals_screen.dart';
import '../ai_business_os/admin/admin_ai_os_quotations_screen.dart';
import '../ai_business_os/admin/admin_ai_os_reports_screen.dart';
import '../ai_business_os/admin/admin_ai_os_settings_screen.dart';
import '../ai_business_os/admin/admin_ai_os_tickets_screen.dart';
import '../ai_business_os/admin/admin_ai_os_voice_screen.dart';
import '../ai_business_os/admin/admin_ai_os_whatsapp_screen.dart';

/// Right-hand panel content for Shop / Calculator admin (embedded mode).
class AdminModuleEmbeddedContent extends StatelessWidget {
  const AdminModuleEmbeddedContent({
    super.key,
    required this.route,
    this.onShopNavigate,
  });

  final String route;
  final ValueChanged<String>? onShopNavigate;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey(route),
      child: _screenForRoute(route, onShopNavigate: onShopNavigate),
    );
  }

  static Widget _screenForRoute(
    String route, {
    ValueChanged<String>? onShopNavigate,
  }) {
    const embedded = true;
    if (route == RouteNames.adminShopAttributeCreate) {
      return AdminShopAttributeEditorScreen(
        embedded: embedded,
        onNavigateRoute: onShopNavigate,
      );
    }
    final attributeEditId = RouteNames.parseAdminShopAttributeEditId(route);
    if (attributeEditId != null) {
      return AdminShopAttributeEditorScreen(
        attributeId: attributeEditId,
        embedded: embedded,
        onNavigateRoute: onShopNavigate,
      );
    }
    if (route == RouteNames.adminShopSubCategoryCreate ||
        RouteNames.parseAdminShopSubCategoryCreateCategoryId(route) != null) {
      return AdminShopSubCategoryEditorScreen(
        initialCategoryId: RouteNames.parseAdminShopSubCategoryCreateCategoryId(
          route,
        ),
        embedded: embedded,
        onNavigateRoute: onShopNavigate,
      );
    }
    final subEditId = RouteNames.parseAdminShopSubCategoryEditId(route);
    if (subEditId != null) {
      return AdminShopSubCategoryEditorScreen(
        subCategoryId: subEditId,
        embedded: embedded,
        onNavigateRoute: onShopNavigate,
      );
    }
    if (route == RouteNames.adminShopProductCreate ||
        RouteNames.parseAdminShopProductCreateSubCategoryId(route) != null) {
      return AdminShopProductEditorScreen(
        initialSubCategoryId:
            RouteNames.parseAdminShopProductCreateSubCategoryId(route),
        embedded: embedded,
        onNavigateRoute: onShopNavigate,
      );
    }
    final productEditId = RouteNames.parseAdminShopProductEditId(route);
    if (productEditId != null) {
      return AdminShopProductEditorScreen(
        productId: productEditId,
        embedded: embedded,
        onNavigateRoute: onShopNavigate,
      );
    }
    final familyEditId = RouteNames.parseAdminCalculatorFamilyEditId(route);
    if (familyEditId != null) {
      return AdminCalculatorFamilyEditorScreen(
        familyId: familyEditId,
        embedded: embedded,
        onNavigateRoute: onShopNavigate,
      );
    }
    if (route == RouteNames.adminSeoBlogCreate) {
      return const AdminSeoBlogEditorScreen();
    }
    final seoBlogEditId = _parseSeoBlogEditId(route);
    if (seoBlogEditId != null) {
      return AdminSeoBlogEditorScreen(blogId: seoBlogEditId);
    }
    if (route == RouteNames.adminSeoCityCreate) {
      return const AdminSeoCityEditorScreen();
    }
    if (route == RouteNames.adminSeoServiceCreate) {
      return const AdminSeoServiceEditorScreen();
    }
    final seoCityEditId = _parseSeoCityEditId(route);
    if (seoCityEditId != null) {
      return AdminSeoCityEditorScreen(cityId: seoCityEditId);
    }
    final seoServiceEditId = _parseSeoServiceEditId(route);
    if (seoServiceEditId != null) {
      return AdminSeoServiceEditorScreen(serviceId: seoServiceEditId);
    }
    switch (route) {
      case RouteNames.adminShopHome:
        return AdminShopHubScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminShopCategories:
        return const AdminShopCategoriesScreen(embedded: embedded);
      case RouteNames.adminShopSubCategories:
        return AdminShopSubCategoriesScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminShopAttributeMaster:
        return AdminShopAttributeMasterScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminShopAttributeGroups:
        return const AdminShopAttributeGroupsScreen(embedded: embedded);
      case RouteNames.adminShopBrands:
        return const AdminShopBrandsScreen(embedded: embedded);
      case RouteNames.adminShopBulkImport:
        return const AdminShopBulkImportScreen(embedded: embedded);
      case RouteNames.adminShopProductImport:
        return AdminShopProductImportScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminShopProducts:
        return AdminShopProductsScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminShopInventory:
        return const AdminShopInventoryScreen(embedded: embedded);
      case RouteNames.adminShopPurchases:
        return const AdminShopPurchasesScreen(embedded: embedded);
      case RouteNames.adminShopSuppliers:
        return const AdminShopSuppliersScreen(embedded: embedded);
      case RouteNames.adminShopCustomers:
        return const AdminShopCustomersScreen(embedded: embedded);
      case RouteNames.adminShopQuotations:
        return const AdminShopQuotationsScreen(embedded: embedded);
      case RouteNames.adminShopReports:
        return const AdminShopReportsScreen(embedded: embedded);
      case RouteNames.adminShopOrders:
        return const AdminShopOrdersScreen(embedded: embedded);
      case RouteNames.adminCalculatorHome:
        return AdminCalculatorHubScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminCalculatorFamilies:
        return AdminCalculatorFamiliesScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminCalculatorFamilyCreate:
        return AdminCalculatorFamilyEditorScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminCalculatorQuestionGroups:
        return AdminCalculatorQuestionGroupsScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminCalculatorOptions:
        return AdminCalculatorOptionsScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminCalculatorRules:
        return AdminCalculatorFamilyRulesScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      // Legacy bookmarks → new pages
      case RouteNames.adminCalculatorTemplates:
      case RouteNames.adminCalculatorRuleProducts:
      case RouteNames.adminCalculatorQuotationBuilder:
        return AdminCalculatorFamiliesScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminCalculatorQuestions:
        return AdminCalculatorOptionsScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminSeoHome:
        return AdminSeoHubScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminSeoCities:
        return AdminSeoCitiesScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminSeoServices:
        return AdminSeoServicesScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminSeoBlogPosts:
        return AdminSeoBlogPostsScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminAiOsHome:
        return const AdminAiOsHubScreen(embedded: embedded);
      case RouteNames.adminAiOsHowToUse:
        return AdminAiOsHowToUseScreen(
          embedded: embedded,
          onNavigateRoute: onShopNavigate,
        );
      case RouteNames.adminAiOsCrm:
        return const AdminAiOsCrmScreen(embedded: embedded);
      case RouteNames.adminAiOsLeads:
        return const AdminAiOsLeadsScreen(embedded: embedded);
      case RouteNames.adminAiOsCalendar:
        return const AdminAiOsCalendarScreen(embedded: embedded);
      case RouteNames.adminAiOsWhatsapp:
        return const AdminAiOsWhatsappScreen(embedded: embedded);
      case RouteNames.adminAiOsVoice:
        return const AdminAiOsVoiceScreen(embedded: embedded);
      case RouteNames.adminAiOsCampaigns:
        return const AdminAiOsCampaignsScreen(embedded: embedded);
      case RouteNames.adminAiOsKnowledge:
        return const AdminAiOsKnowledgeScreen(embedded: embedded);
      case RouteNames.adminAiOsProposals:
        return const AdminAiOsProposalsScreen(embedded: embedded);
      case RouteNames.adminAiOsQuotations:
        return const AdminAiOsQuotationsScreen(embedded: embedded);
      case RouteNames.adminAiOsMarketing:
        return const AdminAiOsMarketingScreen(embedded: embedded);
      case RouteNames.adminAiOsEstimator:
        return const AdminAiOsEstimatorScreen(embedded: embedded);
      case RouteNames.adminAiOsTickets:
        return const AdminAiOsTicketsScreen(embedded: embedded);
      case RouteNames.adminAiOsProjects:
        return const AdminAiOsProjectsScreen(embedded: embedded);
      case RouteNames.adminAiOsReports:
        return const AdminAiOsReportsScreen(embedded: embedded);
      case RouteNames.adminAiOsBilling:
        return const AdminAiOsBillingScreen(embedded: embedded);
      case RouteNames.adminAiOsMarketplace:
        return const AdminAiOsMarketplaceScreen(embedded: embedded);
      case RouteNames.adminAiOsSettings:
        return const AdminAiOsSettingsScreen(embedded: embedded);
      case RouteNames.adminAiOsAcceptInvite:
        return AdminAiOsAcceptInviteScreen(
          embedded: embedded,
          token: Uri.tryParse(route)?.queryParameters['token'],
        );
      case RouteNames.adminAiOsOnboarding:
        return AdminAiOsOnboardingScreen(embedded: embedded);
      default:
        return Center(child: Text('Unknown module route: $route'));
    }
  }

  static String? _parseSeoCityEditId(String route) {
    const prefix = '${RouteNames.adminSeoCities}/';
    if (!route.startsWith(prefix) || !route.endsWith('/edit')) return null;
    final id = route.substring(prefix.length, route.length - '/edit'.length);
    return id.isEmpty ? null : id;
  }

  static String? _parseSeoServiceEditId(String route) {
    const prefix = '${RouteNames.adminSeoServices}/';
    if (!route.startsWith(prefix) || !route.endsWith('/edit')) return null;
    final id = route.substring(prefix.length, route.length - '/edit'.length);
    return id.isEmpty ? null : id;
  }

  static String? _parseSeoBlogEditId(String route) {
    const prefix = '${RouteNames.adminSeoBlogPosts}/';
    if (!route.startsWith(prefix) || !route.endsWith('/edit')) return null;
    final id = route.substring(prefix.length, route.length - '/edit'.length);
    return id.isEmpty ? null : id;
  }
}

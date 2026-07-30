import 'package:flutter/material.dart';

import '../../../core/constants/route_names.dart';
import 'connect_module_sections.dart';

List<AdminNavSection> shopModuleSections() => [
      AdminNavSection(
        title: 'Shop hub',
        icon: Icons.shopping_bag_rounded,
        accent: const Color(0xFF059669),
        items: [
          AdminNavItem('Overview', 'Shopping dashboard', Icons.dashboard_rounded, RouteNames.adminShopHome, const Color(0xFF059669)),
          AdminNavItem('Categories', 'Top-level categories', Icons.category_rounded, RouteNames.adminShopCategories, const Color(0xFF2563EB)),
          AdminNavItem('Sub categories', 'Sub categories by parent', Icons.account_tree_rounded, RouteNames.adminShopSubCategories, const Color(0xFF0EA5E9)),
          AdminNavItem('Attribute master', 'Reusable attributes', Icons.tune_rounded, RouteNames.adminShopAttributeMaster, const Color(0xFF7C3AED)),
          AdminNavItem('Attribute groups', 'Group attributes for subcategories', Icons.view_module_rounded, RouteNames.adminShopAttributeGroups, const Color(0xFF8B5CF6)),
          AdminNavItem('Brands', 'Product brands', Icons.branding_watermark_rounded, RouteNames.adminShopBrands, const Color(0xFFF59E0B)),
          AdminNavItem('Bulk import & export', 'CSV upload, download, delete', Icons.upload_file_rounded, RouteNames.adminShopBulkImport, const Color(0xFF0F766E)),
          AdminNavItem('AI product import', 'URL, model, PDF → product', Icons.auto_awesome, RouteNames.adminShopProductImport, const Color(0xFF7C3AED)),
          AdminNavItem('Products', 'Product master (SKU)', Icons.inventory_2_rounded, RouteNames.adminShopProducts, const Color(0xFF10B981)),
          AdminNavItem('Inventory', 'FIFO stock & valuation', Icons.warehouse_rounded, RouteNames.adminShopInventory, const Color(0xFF64748B)),
          AdminNavItem('Purchases', 'Stock-in receipts', Icons.add_shopping_cart_rounded, RouteNames.adminShopPurchases, const Color(0xFF0D9488)),
          AdminNavItem('Suppliers', 'Vendor master', Icons.local_shipping_rounded, RouteNames.adminShopSuppliers, const Color(0xFF78716C)),
          AdminNavItem('Customers', 'CRM customers', Icons.people_outline_rounded, RouteNames.adminShopCustomers, const Color(0xFF6366F1)),
          AdminNavItem('Quotations', 'Shop quotes', Icons.request_quote_rounded, RouteNames.adminShopQuotations, const Color(0xFF8B5CF6)),
          AdminNavItem('Reports', 'GST & purchases', Icons.assessment_rounded, RouteNames.adminShopReports, const Color(0xFF475569)),
          AdminNavItem('Orders', 'Shop orders', Icons.receipt_long_rounded, RouteNames.adminShopOrders, const Color(0xFFEF4444)),
        ],
      ),
    ];

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../features/calculator/presentation/calculator_screens.dart';
import '../../../features/customer/account/customer_account_hub_screen.dart';
import '../../../features/customer/account/customer_order_detail_screen.dart';
import '../../../features/customer/account/customer_orders_screen.dart';
import '../../../features/customer/chat_page.dart';
import '../../../features/customer/rate_page.dart';
import '../../../features/shared/legal_document_viewer_screen.dart';
import '../../../features/shared/legal_menu_screen.dart';
import '../../../features/shared/service_record_verify_screen.dart'
    as verify_screen;
import '../../../features/shared/settings_screen.dart';
import '../../../features/shared/support_create_ticket_screen.dart';
import '../../../features/shared/support_faq_screen.dart';
import '../../../features/shared/support_tickets_screen.dart';

/// Deferred account / support / customer bundle (Firebase-backed, not on home).
Widget buildAccountScreen(GoRouterState state) {
  switch (state.uri.path) {
    case RouteNames.settings:
      return const SettingsScreen(embedInPublicShell: true);
    case RouteNames.legalMenu:
      return const LegalMenuScreen();
    case RouteNames.supportFaq:
      return SupportFaqScreen(role: state.uri.queryParameters['role']);
    case RouteNames.supportCreateTicket:
      return const SupportCreateTicketScreen();
    case RouteNames.supportTickets:
      return const SupportTicketsScreen();
    case RouteNames.verifyRecord:
      return verify_screen.ServiceRecordVerifyScreen(
        recordId: state.uri.queryParameters['recordId'] ?? '',
      );
    case RouteNames.customerRate:
      return CustomerRatePage(
        jobId: state.uri.queryParameters['jobId'],
        token: state.uri.queryParameters['token'],
      );
    case RouteNames.customerChat:
      return CustomerChatPage(
        jobId: state.uri.queryParameters['jobId'],
        token: state.uri.queryParameters['token'],
      );
    case RouteNames.accountHome:
      return const CustomerAccountHubScreen();
    case RouteNames.accountOrders:
      return const CustomerOrdersScreen();
    case RouteNames.calculatorHome:
      return const CalculatorHomeScreen();
    case RouteNames.calculatorQuotations:
      return const CalculatorQuotationsScreen();
    default:
      if (state.uri.path.startsWith('/account/orders/')) {
        return CustomerOrderDetailScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        );
      }
      if (state.uri.path.startsWith('/app/calculator/template/')) {
        return CalculatorTemplateScreen(
          templateId: state.pathParameters['templateId'] ?? '',
        );
      }
      if (state.uri.path.startsWith('/app/calculator/quotations/')) {
        return CalculatorQuotationDetailScreen(
          quotationId: state.pathParameters['quotationId'] ?? '',
        );
      }
      if (state.uri.path.startsWith('/legal/')) {
        return LegalDocumentViewerScreen(
          documentId: state.pathParameters['documentId'] ?? '',
          title: state.extra is String ? state.extra as String? : null,
        );
      }
      return const Scaffold(
        body: Center(child: Text('Unknown account route')),
      );
  }
}

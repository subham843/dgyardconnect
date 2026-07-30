import 'package:flutter/material.dart';

import '../../../core/constants/route_names.dart';
import 'connect_module_sections.dart';

List<AdminNavSection> aiBusinessOsModuleSections() => [
      AdminNavSection(
        title: 'AI Business OS',
        icon: Icons.psychology_rounded,
        accent: const Color(0xFF4F46E5),
        items: [
          AdminNavItem('Overview', 'Dashboard & KPIs', Icons.dashboard_rounded, RouteNames.adminAiOsHome, const Color(0xFF4F46E5)),
          AdminNavItem('How to use', 'हिंदी + English guide', Icons.help_outline_rounded, RouteNames.adminAiOsHowToUse, const Color(0xFF0F766E)),
          AdminNavItem('CRM', 'Contacts, Companies, Deals', Icons.people_rounded, RouteNames.adminAiOsCrm, const Color(0xFF0EA5E9)),
          AdminNavItem('Leads', 'Lead management & scoring', Icons.leaderboard_rounded, RouteNames.adminAiOsLeads, const Color(0xFFF59E0B)),
          AdminNavItem('Tasks', 'Calendar & due follow-ups', Icons.event_available_rounded, RouteNames.adminAiOsCalendar, const Color(0xFF0D9488)),
          AdminNavItem('Inbox', 'WA / Web / App / Social AI chat', Icons.chat_bubble_rounded, RouteNames.adminAiOsWhatsapp, const Color(0xFF10B981)),
          AdminNavItem('Voice', 'Call logs & recordings', Icons.phone_rounded, RouteNames.adminAiOsVoice, const Color(0xFF8B5CF6)),
          AdminNavItem('Campaigns', 'WA / SMS / Email campaigns', Icons.campaign_rounded, RouteNames.adminAiOsCampaigns, const Color(0xFFEC4899)),
          AdminNavItem('Knowledge', 'KB documents & collections', Icons.menu_book_rounded, RouteNames.adminAiOsKnowledge, const Color(0xFF6366F1)),
          AdminNavItem('Proposals', 'Client proposals', Icons.description_rounded, RouteNames.adminAiOsProposals, const Color(0xFF14B8A6)),
          AdminNavItem('Quotations', 'BOQ & quotations', Icons.request_quote_rounded, RouteNames.adminAiOsQuotations, const Color(0xFF3B82F6)),
          AdminNavItem('Marketing', 'Marketing automation', Icons.auto_awesome_rounded, RouteNames.adminAiOsMarketing, const Color(0xFFEF4444)),
          AdminNavItem('Estimator', 'Project estimation tool', Icons.calculate_rounded, RouteNames.adminAiOsEstimator, const Color(0xFF059669)),
          AdminNavItem('Tickets', 'Support & issues', Icons.confirmation_number_rounded, RouteNames.adminAiOsTickets, const Color(0xFFF97316)),
          AdminNavItem('Projects', 'Active projects', Icons.engineering_rounded, RouteNames.adminAiOsProjects, const Color(0xFF0891B2)),
          AdminNavItem('Reports', 'Analytics & insights', Icons.analytics_rounded, RouteNames.adminAiOsReports, const Color(0xFF7C3AED)),
          AdminNavItem('Billing', 'Plans & subscriptions', Icons.payments_rounded, RouteNames.adminAiOsBilling, const Color(0xFF64748B)),
          AdminNavItem('Marketplace', 'Apps & integrations', Icons.storefront_rounded, RouteNames.adminAiOsMarketplace, const Color(0xFF78716C)),
          AdminNavItem('Settings', 'Tenant & team config', Icons.settings_rounded, RouteNames.adminAiOsSettings, const Color(0xFF475569)),
        ],
      ),
    ];

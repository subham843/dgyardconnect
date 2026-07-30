import 'package:flutter/material.dart';

import '../../../core/constants/route_names.dart';

/// Existing Connect admin navigation (unchanged routes).
class AdminNavItem {
  const AdminNavItem(this.title, this.subtitle, this.icon, this.route, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
}

class AdminNavSection {
  const AdminNavSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    this.hubLabel,
    this.hubRoute,
    this.hubIcon,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<AdminNavItem> items;

  /// Expandable hub row (Shop / Calculator) — tap expands children; does not push a route.
  final String? hubLabel;
  final String? hubRoute;
  final IconData? hubIcon;

  bool get hasExpandableHub => hubRoute != null && hubLabel != null;
}

List<AdminNavSection> connectModuleSections() => [
      AdminNavSection(
        title: 'Queues',
        icon: Icons.pending_actions_rounded,
        accent: const Color(0xFF2563EB),
        items: [
          AdminNavItem('Pending approvals', 'Registration and profile approvals', Icons.pending_actions, RouteNames.adminPendingApprovals, const Color(0xFF2563EB)),
          AdminNavItem('KYC', 'Verify dealer and technician documents', Icons.verified_user, RouteNames.adminKyc, const Color(0xFF0EA5E9)),
          AdminNavItem('Disputes', 'Approve payment or refund', Icons.gavel, RouteNames.adminDisputes, const Color(0xFF7C3AED)),
          AdminNavItem('Escrow approvals', 'Release/transfer held amounts', Icons.lock_clock_rounded, RouteNames.adminEscrowApprovals, const Color(0xFF0EA5E9)),
          AdminNavItem('Warranty claims', 'Manage warranty claims', Icons.verified_user_outlined, RouteNames.adminWarrantyClaims, const Color(0xFF10B981)),
          AdminNavItem('Fraud alerts', 'Risk review queue', Icons.report, RouteNames.adminFraudAlerts, const Color(0xFFEF4444)),
          AdminNavItem('Support tickets', 'Help requests', Icons.support_agent_rounded, RouteNames.adminSupportTickets, const Color(0xFFF59E0B)),
          AdminNavItem('Marketplace hub', 'B2B catalog (Firebase)', Icons.storefront_rounded, RouteNames.adminMarketplaceHome, const Color(0xFF059669)),
        ],
      ),
      AdminNavSection(
        title: 'Users',
        icon: Icons.people_alt_rounded,
        accent: const Color(0xFF0EA5E9),
        items: [
          AdminNavItem('Dealers', 'View all dealers', Icons.store, RouteNames.adminDealersList, const Color(0xFF2563EB)),
          AdminNavItem('Technicians', 'View all technicians', Icons.engineering, RouteNames.adminTechniciansList, const Color(0xFF0EA5E9)),
          AdminNavItem('Jobs', 'View all jobs', Icons.work, RouteNames.adminJobsList, const Color(0xFFF59E0B)),
          AdminNavItem('Service records', 'Verify and download PDF', Icons.assignment_rounded, RouteNames.adminServiceCompletionRecords, const Color(0xFF10B981)),
          AdminNavItem('Job evidence locker', 'Tamper-proof evidence', Icons.folder_special, RouteNames.adminJobEvidence, const Color(0xFF7C3AED)),
        ],
      ),
      AdminNavSection(
        title: 'Trust & enforcement',
        icon: Icons.shield_rounded,
        accent: const Color(0xFF7C3AED),
        items: [
          AdminNavItem('Trust score history', 'History + adjustments', Icons.shield, RouteNames.adminTrustScoreHistory, const Color(0xFF7C3AED)),
          AdminNavItem('Adjust trust score', 'Apply delta with reason', Icons.tune, RouteNames.adminAdjustTrustScore, const Color(0xFF2563EB)),
          AdminNavItem('Override level', 'Manual level override', Icons.star, RouteNames.adminOverrideLevel, const Color(0xFFF59E0B)),
          AdminNavItem('Penalty & status', 'Penalty points', Icons.block, RouteNames.adminPenaltyStatus, const Color(0xFFEF4444)),
          AdminNavItem('Technician strikes', 'Strikes and blocks', Icons.warning_amber_rounded, RouteNames.adminStrikes, const Color(0xFFFB7185)),
          AdminNavItem('Audit logs', 'Admin action history', Icons.history_edu, RouteNames.adminAuditLogs, const Color(0xFF0EA5E9)),
        ],
      ),
      AdminNavSection(
        title: 'Finance & config',
        icon: Icons.tune_rounded,
        accent: const Color(0xFF10B981),
        items: [
          AdminNavItem('Finance', 'Revenue, invoices, GST', Icons.account_balance_wallet, RouteNames.adminFinance, const Color(0xFF10B981)),
          AdminNavItem('Master data', 'Job types, sectors, rates', Icons.settings_applications, RouteNames.adminMasterData, const Color(0xFF2563EB)),
          AdminNavItem('Platform dashboard', 'Real-time metrics', Icons.dashboard, RouteNames.adminPlatformDashboard, const Color(0xFF0EA5E9)),
          AdminNavItem('Legal logs', 'Terms acceptance', Icons.description, RouteNames.adminLegalLogs, const Color(0xFF64748B)),
          AdminNavItem('Legal documents', 'Edit policies', Icons.gavel, RouteNames.adminLegalDocuments, const Color(0xFF7C3AED)),
          AdminNavItem('Brand kit', 'Logo, colors, splash', Icons.palette, RouteNames.adminBrandKit, const Color(0xFFF472B6)),
          AdminNavItem('App updates', 'Force/optional updates', Icons.system_update_alt_rounded, RouteNames.adminAppUpdates, const Color(0xFFF59E0B)),
          AdminNavItem('Send push', 'Deep-link push', Icons.send_rounded, RouteNames.adminSendPush, const Color(0xFF2563EB)),
          AdminNavItem('Ads / Promotions', 'Dashboard ads', Icons.campaign, RouteNames.adminAds, const Color(0xFFFB7185)),
        ],
      ),
    ];

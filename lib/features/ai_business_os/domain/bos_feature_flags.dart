import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';

/// Plan-based module gating for AI Business OS Mega Menu.
class BosFeatureFlags {
  BosFeatureFlags._();

  static List<String> _modules = const ['all'];
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  static List<String> get modules => List.unmodifiable(_modules);

  static void setModules(List<String> modules) {
    _modules = modules.isEmpty ? const ['crm', 'leads', 'settings'] : List<String>.from(modules);
    _loaded = true;
  }

  static void clear() {
    _modules = const ['all'];
    _loaded = false;
  }

  static bool get _isSuperadmin =>
      SupabaseAuthService.instance.currentJwtIsSuperadmin;

  static bool allowsModule(String code) {
    if (_isSuperadmin) return true;
    if (!_loaded) return true; // until first load, do not hide nav
    final normalized = code.trim().toLowerCase();
    if (_modules.contains('all')) return true;
    return _modules.map((m) => m.toLowerCase()).contains(normalized);
  }

  /// Map Mega Menu route → plan module code. Null = always visible.
  static String? moduleCodeForRoute(String route) {
    switch (route) {
      case RouteNames.adminAiOsHome:
      case RouteNames.adminAiOsHowToUse:
      case RouteNames.adminAiOsSettings:
      case RouteNames.adminAiOsBilling:
      case RouteNames.adminAiOsAcceptInvite:
      case RouteNames.adminAiOsOnboarding:
        return null;
      case RouteNames.adminAiOsCrm:
        return 'crm';
      case RouteNames.adminAiOsLeads:
        return 'leads';
      case RouteNames.adminAiOsCalendar:
        return 'crm';
      case RouteNames.adminAiOsWhatsapp:
        return 'whatsapp';
      case RouteNames.adminAiOsVoice:
        return 'voice';
      case RouteNames.adminAiOsCampaigns:
        return 'campaigns';
      case RouteNames.adminAiOsKnowledge:
        return 'kb';
      case RouteNames.adminAiOsProposals:
        return 'proposals';
      case RouteNames.adminAiOsQuotations:
        return 'quotations';
      case RouteNames.adminAiOsMarketing:
        return 'marketing';
      case RouteNames.adminAiOsEstimator:
        return 'estimator';
      case RouteNames.adminAiOsTickets:
        return 'tickets';
      case RouteNames.adminAiOsProjects:
        return 'projects';
      case RouteNames.adminAiOsReports:
        return 'reports';
      case RouteNames.adminAiOsMarketplace:
        return 'marketplace';
      default:
        return null;
    }
  }

  static bool allowsRoute(String route) {
    final code = moduleCodeForRoute(route);
    if (code == null) return true;
    return allowsModule(code);
  }
}

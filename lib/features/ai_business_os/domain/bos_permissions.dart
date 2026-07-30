import '../../../core/supabase/supabase_auth_service.dart';
import 'bos_capabilities.dart';

/// CRM actions gated by `bos_role` (JWT claim / membership).
enum BosCrmAction {
  view,
  create,
  edit,
  assign,
  convert,
  manageMembers,
}

/// Role → capability permission helper for AI Business OS admin screens.
class BosPermissions {
  BosPermissions._();

  static String get role {
    final auth = SupabaseAuthService.instance;
    if (auth.currentJwtIsSuperadmin) return 'owner';
    final r = auth.activeBosRole?.trim().toLowerCase();
    if (r != null && r.isNotEmpty) return r;
    return 'viewer';
  }

  static Set<String> get capabilities => BosCapabilities.forRole(role);

  static bool has(String capability) {
    if (SupabaseAuthService.instance.currentJwtIsSuperadmin) return true;
    return capabilities.contains(capability);
  }

  static bool can(BosCrmAction action) {
    switch (action) {
      case BosCrmAction.view:
        return has(BosCap.crmView);
      case BosCrmAction.create:
      case BosCrmAction.edit:
        return has(BosCap.crmEdit);
      case BosCrmAction.assign:
      case BosCrmAction.convert:
        return has(BosCap.leadsManage);
      case BosCrmAction.manageMembers:
        return has(BosCap.membersManage);
    }
  }

  static bool get canView => can(BosCrmAction.view);
  static bool get canCreate => can(BosCrmAction.create);
  static bool get canEdit => can(BosCrmAction.edit);
  static bool get canAssign => can(BosCrmAction.assign);
  static bool get canConvert => can(BosCrmAction.convert);
  static bool get canManageMembers => can(BosCrmAction.manageMembers);
  static bool get canManageSettings => has(BosCap.settingsManage);
  static bool get canViewAudit => has(BosCap.auditView);
}

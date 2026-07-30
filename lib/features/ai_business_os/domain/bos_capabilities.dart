/// Fine-grained AI Business OS capabilities (role → set).
abstract final class BosCap {
  static const crmView = 'crm.view';
  static const crmEdit = 'crm.edit';
  static const leadsManage = 'leads.manage';
  static const dealsManage = 'deals.manage';
  static const ticketsManage = 'tickets.manage';
  static const membersManage = 'members.manage';
  static const settingsManage = 'settings.manage';
  static const auditView = 'audit.view';
  static const productsView = 'products.view';
  static const productsManage = 'products.manage';
  static const pricingManage = 'pricing.manage';
  static const inventoryAdjust = 'inventory.adjust';
  static const quotesManage = 'quotes.manage';
  static const reportsView = 'reports.view';

  static const all = <String>{
    crmView,
    crmEdit,
    leadsManage,
    dealsManage,
    ticketsManage,
    membersManage,
    settingsManage,
    auditView,
    productsView,
    productsManage,
    pricingManage,
    inventoryAdjust,
    quotesManage,
    reportsView,
  };
}

/// Static role → capability matrix for Phase A.
class BosCapabilities {
  BosCapabilities._();

  static const _viewOnly = <String>{
    BosCap.crmView,
    BosCap.productsView,
    BosCap.auditView,
    BosCap.reportsView,
  };

  static Set<String> forRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'owner':
      case 'admin':
        return Set<String>.from(BosCap.all);
      case 'sales':
        return {
          BosCap.crmView,
          BosCap.crmEdit,
          BosCap.leadsManage,
          BosCap.dealsManage,
          BosCap.quotesManage,
          BosCap.productsView,
          BosCap.reportsView,
          BosCap.auditView,
        };
      case 'agent':
        return {
          BosCap.crmView,
          BosCap.crmEdit,
          BosCap.ticketsManage,
          BosCap.productsView,
        };
      case 'viewer':
      default:
        return Set<String>.from(_viewOnly);
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../shop/data/supabase_repository_base.dart';

/// Who may open AI Business OS / CRM admin UI (beyond Firebase superadmin).
class BosAccess {
  BosAccess._();

  static final Map<String, bool> _cache = {};

  static void clearCache() => _cache.clear();

  /// Active `bos_tenant_members` row for this Firebase UID (or JWT already has bos claims).
  static Future<bool> hasActiveMembership([String? uid]) async {
    final id = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (id == null || id.isEmpty) return false;
    if (_cache.containsKey(id)) return _cache[id]!;

    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final auth = SupabaseAuthService.instance;
    if (auth.currentJwtIsSuperadmin) {
      return _remember(id, true);
    }
    final claimRole = auth.activeBosRole;
    final claimTenant = auth.activeBosTenantId;
    if (claimRole != null &&
        claimRole.isNotEmpty &&
        claimTenant != null &&
        claimTenant.isNotEmpty) {
      return _remember(id, true);
    }

    try {
      final c = await SupabaseRepositoryBase.clientWithAuth();
      if (c == null) return _remember(id, false);
      final row = await c
          .from('bos_tenant_members')
          .select('id')
          .eq('firebase_uid', id)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .limit(1)
          .maybeSingle();
      return _remember(id, row != null);
    } catch (_) {
      return _remember(id, false);
    }
  }

  static bool _remember(String uid, bool ok) {
    _cache[uid] = ok;
    return ok;
  }

  /// Full `/admin` for Firebase superadmin; bos members get `/admin` shell + `/admin/ai-os*` only.
  static Future<bool> canAccessAdminPath(
    String path, {
    required bool isFirebaseSuperadmin,
  }) async {
    if (isFirebaseSuperadmin) return true;
    if (!path.startsWith('/admin')) return false;
    final aiOsOnly = path == RouteNames.adminHome ||
        path == '/admin' ||
        path.startsWith('/admin/ai-os');
    if (!aiOsOnly) return false;
    return hasActiveMembership();
  }
}

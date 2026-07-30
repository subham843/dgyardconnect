import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../shop/data/supabase_repository_base.dart';
import '../domain/bos_models.dart';
import '../domain/bos_feature_flags.dart';

const _uuid = Uuid();

class BosRepository extends SupabaseRepositoryBase {
  static const String _kActiveBosTenantIdKey = 'bos_active_tenant_id';

  String? _cachedActiveTenantId;

  Future<String> get activeTenantId async {
    if (_cachedActiveTenantId != null) return _cachedActiveTenantId!;
    final prefs = await SharedPreferences.getInstance();
    _cachedActiveTenantId =
        prefs.getString(_kActiveBosTenantIdKey) ?? kBosDefaultTenantId;
    return _cachedActiveTenantId!;
  }

  Future<void> setActiveTenantId(String id) async {
    _cachedActiveTenantId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveBosTenantIdKey, id);
    await SupabaseAuthService.instance.setActiveBosTenant(id);
  }

  // â”€â”€ Tenants / members â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<BosTenant>> listTenants() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res =
        await client.from('bos_tenants').select().isFilter('deleted_at', null);
    return (res as List).map((r) => BosTenant.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<BosTenant?> getTenant(String tenantId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final res = await client
        .from('bos_tenants')
        .select()
        .eq('id', tenantId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    return res == null ? null : BosTenant.fromMap(SupabaseRepositoryBase.rowToMap(res));
  }

  Future<void> updateTenant(String tenantId, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_tenants').update(updates).eq('id', tenantId);
  }

  Future<List<BosTenantMember>> listMembers(String tenantId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_tenant_members')
        .select()
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List)
        .map((r) => BosTenantMember.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<void> writeAuditLog({
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? meta,
    String? tenantId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final tid = tenantId ?? await activeTenantId;
    final uid = SupabaseAuthService.instance.accessToken != null
        ? SupabaseAuthService.jwtClaim(SupabaseAuthService.instance.accessToken, 'sub')
        : null;
    try {
      await client.from('bos_audit_log').insert({
        'id': _uuid.v4(),
        'tenant_id': tid,
        'firebase_uid': uid,
        'action': action,
        'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
        'meta': meta ?? {},
      });
    } catch (_) {
      // Audit must not block primary mutations.
    }
  }

  Future<List<Map<String, dynamic>>> listAuditLog({int limit = 50}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_audit_log')
        .select()
        .eq('tenant_id', tid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<String> addMember({
    required String tenantId,
    required String firebaseUid,
    required String role,
    String? email,
    String? displayName,
    String? departmentId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final id = _uuid.v4();
    await client.from('bos_tenant_members').insert({
      'id': id,
      'tenant_id': tenantId,
      'firebase_uid': firebaseUid,
      'role': role,
      'email': email,
      'display_name': displayName,
      if (departmentId != null) 'department_id': departmentId,
      'is_active': true,
    });
    await writeAuditLog(
      action: 'member.add',
      entityType: 'bos_tenant_members',
      entityId: id,
      tenantId: tenantId,
      meta: {'firebase_uid': firebaseUid, 'role': role, 'department_id': departmentId},
    );
    return id;
  }

  Future<void> updateMemberRole(String memberId, String role) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client
        .from('bos_tenant_members')
        .update({'role': role}).eq('id', memberId);
    await writeAuditLog(
      action: 'member.role_update',
      entityType: 'bos_tenant_members',
      entityId: memberId,
      meta: {'role': role},
    );
  }

  Future<void> updateMemberDepartment(String memberId, String? departmentId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_tenant_members').update({
      'department_id': departmentId,
    }).eq('id', memberId);
    await writeAuditLog(
      action: 'member.department_set',
      entityType: 'bos_tenant_members',
      entityId: memberId,
      meta: {'department_id': departmentId},
    );
  }

  Future<void> deactivateMember(String memberId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_tenant_members').update({
      'is_active': false,
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', memberId);
    await writeAuditLog(
      action: 'member.deactivate',
      entityType: 'bos_tenant_members',
      entityId: memberId,
    );
  }

  Future<List<BosDepartment>> listDepartments({String? tenantId}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = tenantId ?? await activeTenantId;
    final res = await client
        .from('bos_departments')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('name');
    return (res as List)
        .map((r) => BosDepartment.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<String> createDepartment({
    required String name,
    String? code,
    String? tenantId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = tenantId ?? await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_departments').insert({
      'id': id,
      'tenant_id': tid,
      'name': name.trim(),
      'code': code?.trim(),
      'is_active': true,
    });
    await writeAuditLog(
      action: 'department.create',
      entityType: 'bos_departments',
      entityId: id,
      tenantId: tid,
      meta: {'name': name},
    );
    return id;
  }

  Future<void> updateDepartment(String departmentId, {required String name, String? code}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_departments').update({
      'name': name.trim(),
      if (code != null) 'code': code.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', departmentId);
    await writeAuditLog(
      action: 'department.update',
      entityType: 'bos_departments',
      entityId: departmentId,
      meta: {'name': name},
    );
  }

  Future<void> softDeleteDepartment(String departmentId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_departments').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', departmentId);
    await writeAuditLog(
      action: 'department.delete',
      entityType: 'bos_departments',
      entityId: departmentId,
    );
  }

  Future<List<BosTenantInvite>> listInvites({String? tenantId}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = tenantId ?? await activeTenantId;
    final res = await client
        .from('bos_tenant_invites')
        .select()
        .eq('tenant_id', tid)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List)
        .map((r) => BosTenantInvite.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  /// Creates invite and sends email (Resend when secrets set; else stub).
  Future<({BosTenantInvite invite, Map<String, dynamic> email})> createInvite({
    required String email,
    required String role,
    String? departmentId,
    String? tenantId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = tenantId ?? await activeTenantId;
    try {
      await client.rpc('bos_assert_user_limit', params: {'p_tenant_id': tid});
    } catch (e) {
      final msg = '$e';
      if (msg.contains('user_limit') || msg.contains('limit')) {
        throw Exception('User seat limit reached — upgrade your plan in Billing');
      }
      throw Exception(msg);
    }
    final id = _uuid.v4();
    final token = _uuid.v4().replaceAll('-', '');
    final uid = SupabaseAuthService.jwtClaim(
      SupabaseAuthService.instance.accessToken,
      'sub',
    );
    final row = {
      'id': id,
      'tenant_id': tid,
      'email': email.trim().toLowerCase(),
      'role': role,
      if (departmentId != null) 'department_id': departmentId,
      'token': token,
      'status': 'pending',
      'invited_by_uid': uid,
      'expires_at': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
    };
    await client.from('bos_tenant_invites').insert(row);
    await writeAuditLog(
      action: 'invite.create',
      entityType: 'bos_tenant_invites',
      entityId: id,
      tenantId: tid,
      meta: {'email': email, 'role': role},
    );
    Map<String, dynamic> emailResult = {};
    try {
      emailResult = await sendInviteEmail(id);
    } catch (e) {
      emailResult = {'ok': false, 'sim': true, 'error': '$e'};
    }
    final invite = BosTenantInvite.fromMap(
      row..['created_at'] = DateTime.now().toIso8601String(),
    );
    return (invite: invite, email: emailResult);
  }

  Future<Map<String, dynamic>> sendInviteEmail(String inviteId) async {
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final base = Uri.base.origin;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-invite-email')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'invite_id': inviteId,
        'tenant_id': tid,
        'accept_base_url': base,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<void> revokeInvite(String inviteId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_tenant_invites').update({
      'status': 'revoked',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', inviteId);
    await writeAuditLog(
      action: 'invite.revoke',
      entityType: 'bos_tenant_invites',
      entityId: inviteId,
    );
  }

  Future<Map<String, dynamic>> acceptInvite({required String token, required String email}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final res = await client.rpc('bos_accept_invite', params: {
      'p_token': token.trim(),
      'p_email': email.trim().toLowerCase(),
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'member_id': '$res'};
  }

  Future<Map<String, dynamic>> bootstrapTenant({
    required String companyName,
    String? slug,
    String? email,
    String? displayName,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final res = await client.rpc('bos_bootstrap_tenant', params: {
      'p_company_name': companyName.trim(),
      'p_slug': slug?.trim(),
      'p_email': email?.trim().toLowerCase(),
      'p_display_name': displayName?.trim(),
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    throw Exception('Bootstrap failed');
  }

  Future<Map<String, dynamic>> completeOnboarding({String catalogSeed = 'empty'}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final res = await client.rpc('bos_complete_onboarding', params: {
      'p_catalog_seed': catalogSeed,
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'onboarding_completed': true};
  }

  Future<bool> isOnboardingCompleted({String? tenantId}) async {
    final tid = tenantId ?? await activeTenantId;
    final tenant = await getTenant(tid);
    final settings = tenant?.settings;
    if (settings != null && settings['onboarding_completed'] == true) return true;
    final row = await getTenantSettingsRow(tid);
    final s = row?['settings'];
    if (s is Map && s['onboarding_completed'] == true) return true;
    return false;
  }

  Future<List<String>> getActivePlanFeatures() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return const ['crm', 'leads', 'settings'];
    final tid = await activeTenantId;
    final sub = await getSubscription(tid);
    String? planId = sub?.planId;
    if (planId == null || planId.isEmpty) {
      final tenant = await getTenant(tid);
      planId = tenant?.planId;
    }
    if (planId == null || planId.isEmpty) return const ['crm', 'leads', 'settings'];
    final res = await client.from('bos_plans').select().eq('id', planId).maybeSingle();
    if (res == null) return const ['crm', 'leads', 'settings'];
    final plan = BosPlan.fromMap(SupabaseRepositoryBase.rowToMap(res));
    final modules = plan.featureModules;
    if (modules.isEmpty) return const ['crm', 'leads', 'settings'];
    return modules;
  }

  Future<void> refreshFeatureFlags() async {
    final modules = await getActivePlanFeatures();
    BosFeatureFlags.setModules(modules);
  }

  Future<Map<String, dynamic>?> getTenantSettingsRow(String tenantId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final res = await client
        .from('bos_tenant_settings')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();
    return res == null ? null : SupabaseRepositoryBase.rowToMap(res);
  }

  Future<void> upsertTenantSettings({
    required String tenantId,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? apiKeysPlaceholder,
    Map<String, dynamic>? apiConfig,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_tenant_settings').upsert({
      'tenant_id': tenantId,
      if (settings != null) 'settings': settings,
      if (apiKeysPlaceholder != null) 'api_keys_placeholder': apiKeysPlaceholder,
      if (apiConfig != null) 'api_config': apiConfig,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getTenantApiConfig({String? tenantId}) async {
    final tid = tenantId ?? await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-tenant-secrets')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({'action': 'get', 'tenant_id': tid}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> upsertTenantApiConfig({
    Map<String, dynamic>? apiConfig,
    Map<String, dynamic>? apiSecrets,
    String? tenantId,
  }) async {
    final tid = tenantId ?? await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-tenant-secrets')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'action': 'upsert',
        'tenant_id': tid,
        if (apiConfig != null) 'api_config': apiConfig,
        if (apiSecrets != null) 'api_secrets': apiSecrets,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> superAdminPlatformStats() async {
    final mrr = await mrrOverview();
    final tenants = await listTenants();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    var users = 0;
    var aiMessages = 0;
    var voiceMinutes = 0;
    var apiCalls = 0;
    if (client != null) {
      final members = await client.from('bos_tenant_members').select('id').isFilter('deleted_at', null);
      users = (members as List).length;
      final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final events = await client
          .from('bos_usage_events')
          .select('metric, quantity')
          .gte('occurred_at', since);
      for (final e in events as List) {
        final m = '${e['metric']}';
        final q = (e['quantity'] as num?)?.toDouble() ?? 0;
        if (m == 'ai_messages') aiMessages += q.round();
        if (m == 'voice_minutes') voiceMinutes += q.round();
        if (m == 'api_calls') apiCalls += q.round();
      }
    }
    return {
      ...mrr,
      'companies_total': tenants.length,
      'companies_active': tenants.where((t) => t.status == 'active' || t.status == 'trial').length,
      'users_total': users,
      'usage_ai_messages_30d': aiMessages,
      'usage_voice_minutes_30d': voiceMinutes,
      'usage_api_calls_30d': apiCalls,
    };
  }

  // â”€â”€ Leads â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<BosLead>> listLeads({String? stage, String? score}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client
        .from('bos_leads')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    if (stage != null) qb = qb.eq('stage', stage);
    if (score != null) qb = qb.eq('score', score);
    final res = await qb.order('created_at', ascending: false);
    return (res as List).map((r) => BosLead.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createLead(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    try {
      await client.rpc('bos_assert_lead_limit', params: {'p_tenant_id': tid});
    } catch (e) {
      final msg = '$e';
      if (msg.contains('lead_limit') || msg.contains('limit')) {
        throw Exception('Lead limit reached — upgrade your plan in Billing');
      }
      throw Exception(msg);
    }
    final email = data['email'] as String?;
    final phone = data['phone'] as String?;
    final dupes = await findDuplicateLeads(email: email, phone: phone);
    if (dupes.isNotEmpty && data['allow_duplicate'] != true) {
      throw Exception(
        'Possible duplicate lead: ${dupes.first.displayName} (${dupes.first.id}). '
        'Pass allow_duplicate or merge.',
      );
    }
    final id = _uuid.v4();
    final row = Map<String, dynamic>.from(data)
      ..remove('allow_duplicate')
      ..addAll({
        'id': id,
        'tenant_id': tid,
        'source': data['source'] ?? 'manual',
        'stage': data['stage'] ?? 'new',
      });
    await client.from('bos_leads').insert(row);
    await writeAuditLog(
      action: 'lead.create',
      entityType: 'bos_leads',
      entityId: id,
      meta: {'stage': data['stage'] ?? 'new'},
    );
    // Fire-and-forget AI sales orchestrate (qualify + WA/voice + handover).
    unawaited(orchestrateLead(id).catchError((_) => <String, dynamic>{}));
    return id;
  }

  Future<List<BosActivity>> listDueTasks({DateTime? from, DateTime? to}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final start = (from ?? DateTime.now().subtract(const Duration(days: 7))).toIso8601String();
    final end = (to ?? DateTime.now().add(const Duration(days: 30))).toIso8601String();
    final res = await client
        .from('bos_activities')
        .select()
        .eq('tenant_id', tid)
        .not('due_at', 'is', null)
        .gte('due_at', start)
        .lte('due_at', end)
        .order('due_at');
    return (res as List)
        .map((r) => BosActivity.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<void> completeActivity(String activityId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_activities').update({
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', activityId);
  }

  Future<Map<String, dynamic>> mergeLeads({
    required String keepId,
    required String mergeId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final res = await client.rpc('bos_merge_leads', params: {
      'p_keep_id': keepId,
      'p_merge_id': mergeId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'ok': true};
  }

  Future<String> upsertPipelineStage({
    String? id,
    required String code,
    required String label,
    required int sortOrder,
    bool isWon = false,
    bool isLost = false,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final sid = id ?? _uuid.v4();
    await client.from('bos_pipeline_stages').upsert({
      'id': sid,
      'tenant_id': tid,
      'code': code.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_'),
      'label': label.trim(),
      'sort_order': sortOrder,
      'is_won': isWon,
      'is_lost': isLost,
    });
    return sid;
  }

  Future<void> deletePipelineStage(String stageId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_pipeline_stages').delete().eq('id', stageId);
  }

  Future<List<Map<String, dynamic>>> listAttachments({
    String? leadId,
    String? dealId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client
        .from('bos_attachments')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    if (leadId != null) qb = qb.eq('lead_id', leadId);
    if (dealId != null) qb = qb.eq('deal_id', dealId);
    final res = await qb.order('created_at', ascending: false);
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<String> addAttachmentMeta({
    required String filename,
    required String storagePath,
    String? mimeType,
    String? publicUrl,
    int? sizeBytes,
    String? leadId,
    String? dealId,
    String? contactId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_attachments').insert({
      'id': id,
      'tenant_id': tid,
      'filename': filename,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'public_url': publicUrl,
      'size_bytes': sizeBytes,
      'lead_id': leadId,
      'deal_id': dealId,
      'contact_id': contactId,
    });
    return id;
  }

  /// Register attachment metadata (external URL).
  Future<String> registerAttachmentLink({
    required String filename,
    required String url,
    String? leadId,
    String? dealId,
    String? mimeType,
  }) async {
    return addAttachmentMeta(
      filename: filename,
      storagePath: url,
      publicUrl: url,
      mimeType: mimeType,
      leadId: leadId,
      dealId: dealId,
    );
  }

  /// Upload bytes to `bos-attachments` and register metadata.
  Future<String> uploadAttachment({
    required Uint8List bytes,
    required String filename,
    String? mimeType,
    String? leadId,
    String? dealId,
    String? contactId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$tid/${_uuid.v4()}_$safe';
    final contentType = mimeType ?? 'application/octet-stream';
    await client.storage.from('bos-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
    String? signedUrl;
    try {
      signedUrl = await client.storage.from('bos-attachments').createSignedUrl(
            path,
            60 * 60 * 24 * 7,
          );
    } catch (_) {}
    return addAttachmentMeta(
      filename: filename,
      storagePath: path,
      publicUrl: signedUrl,
      mimeType: contentType,
      sizeBytes: bytes.length,
      leadId: leadId,
      dealId: dealId,
      contactId: contactId,
    );
  }

  /// AI sales agent: qualify + first touch + handover flag.
  Future<Map<String, dynamic>> orchestrateLead(String leadId) async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-sales-orchestrate')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({'lead_id': leadId, 'tenant_id': tid}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> runSalesFollowups({int limit = 25}) async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-sales-followups')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({'tenant_id': tid, 'limit': limit}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<List<BosLead>> listHandoverLeads() async {
    final leads = await listLeads();
    return leads
        .where(
          (l) =>
              l.handoverReady ||
              (l.score == 'hot' && l.stage != 'won' && l.stage != 'lost'),
        )
        .toList();
  }

  Future<Map<String, dynamic>> aiSalesStats() async {
    final base = await overviewStats();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return base;
    final tid = await activeTenantId;
    final convs = await client
        .from('bos_conversations')
        .select('id,channel')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final calls = await client
        .from('bos_voice_calls')
        .select('id,status,meta,duration_sec,direction')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final recipients = await client
        .from('bos_campaign_recipients')
        .select('id,status,delivery_status')
        .eq('tenant_id', tid);
    final events = await client
        .from('bos_outbound_events')
        .select('id,event_type,channel')
        .eq('tenant_id', tid);
    final leads = await listLeads();
    final now = DateTime.now();
    final pendingFollowUps = leads
        .where(
          (l) =>
              l.nextFollowUpAt != null &&
              l.nextFollowUpAt!.isBefore(now) &&
              l.stage != 'won' &&
              l.stage != 'lost',
        )
        .length;
    final handover = leads.where((l) => l.handoverReady || l.score == 'hot').length;
    final converted = leads.where((l) => l.stage == 'won').length;
    final qualified = leads.where((l) => l.stage == 'qualified' || l.score == 'hot').length;
    final callRows = calls as List;
    final convRows = convs as List;
    final recipRows = recipients as List;
    final eventRows = events as List;
    final sentLike = recipRows.where((r) {
      final s = '${r['delivery_status'] ?? r['status'] ?? ''}';
      return s == 'sent' || s == 'sent_sim' || s == 'queued' || s == 'delivered';
    }).length;
    final replied = eventRows.where((e) => e['event_type'] == 'replied').length;
    final delivered = recipRows.where((r) {
      final s = '${r['delivery_status'] ?? ''}';
      return s == 'delivered' || s == 'sent' || s == 'sent_sim';
    }).length;
    final followupOk = eventRows.where((e) => '${e['event_type']}'.contains('followup')).length;
    return {
      ...base,
      'ai_conversations': convRows.length,
      'ai_conversations_web': convRows.where((c) => c['channel'] == 'web' || c['channel'] == 'app').length,
      'ai_calls': callRows.length,
      'ai_calls_completed': callRows.where((c) => c['status'] == 'completed').length,
      'handover_ready': handover,
      'followups_pending': pendingFollowUps,
      'followups_done': followupOk,
      'leads_converted': converted,
      'leads_qualified': qualified,
      'conversion_rate': leads.isEmpty ? 0 : (converted / leads.length * 100).round(),
      'marketing_messages': sentLike,
      'marketing_delivery_rate': recipRows.isEmpty
          ? 0
          : (delivered / recipRows.length * 100).round(),
      'marketing_response_rate': sentLike == 0 ? 0 : (replied / sentLike * 100).round(),
    };
  }

  Future<void> updateLead(String leadId, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_leads').update(updates).eq('id', leadId);
    await writeAuditLog(
      action: 'lead.update',
      entityType: 'bos_leads',
      entityId: leadId,
      meta: updates,
    );
  }

  Future<void> setLeadDoNotCall(String leadId, bool value) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final row = await client.from('bos_leads').select('meta').eq('id', leadId).maybeSingle();
    final meta = row?['meta'] is Map
        ? Map<String, dynamic>.from(row!['meta'] as Map)
        : <String, dynamic>{};
    meta['do_not_call'] = value;
    await updateLead(leadId, {
      'meta': meta,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await addLeadActivity(
      leadId: leadId,
      activityType: value ? 'dnd_on' : 'dnd_off',
      subject: value ? 'Do not call enabled' : 'Do not call cleared',
      body: value
          ? 'Missed-call auto-callbacks will be skipped for this lead'
          : 'Auto-callbacks allowed again',
    );
  }

  Future<void> insertVoiceEventTestPing() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    await client.from('bos_voice_events').insert({
      'id': _uuid.v4(),
      'tenant_id': tid,
      'provider': 'test',
      'event_type': 'test_ping',
      'payload': {
        'note': 'Manual dogfood ping from Settings',
        'at': DateTime.now().toIso8601String(),
      },
    });
  }

  Future<void> assignLead({
    required String leadId,
    required String assigneeFirebaseUid,
    String? assignedBy,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final tid = await activeTenantId;
    await client.from('bos_leads').update({
      'owner_firebase_uid': assigneeFirebaseUid,
    }).eq('id', leadId);
    await client.from('bos_lead_assignments').insert({
      'id': _uuid.v4(),
      'tenant_id': tid,
      'lead_id': leadId,
      'assignee_firebase_uid': assigneeFirebaseUid,
      'assigned_by': assignedBy,
    });
    await writeAuditLog(
      action: 'lead.assign',
      entityType: 'bos_leads',
      entityId: leadId,
      meta: {'assignee': assigneeFirebaseUid},
    );
  }

  Future<void> softDeleteLead(String leadId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_leads').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', leadId);
  }

  Future<List<BosLead>> findDuplicateLeads({String? email, String? phone}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final filters = <String>[];
    if (email != null && email.isNotEmpty) filters.add('email.eq.$email');
    if (phone != null && phone.isNotEmpty) filters.add('phone.eq.$phone');
    if (filters.isEmpty) return [];
    final res = await client
        .from('bos_leads')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .or(filters.join(','));
    return (res as List).map((r) => BosLead.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  /// CSV header: full_name,email,phone,company_name,requirements
  Future<({int imported, int skipped})> importLeadsCsv(List<String> csvLines) async {
    if (csvLines.isEmpty) return (imported: 0, skipped: 0);
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return (imported: 0, skipped: 0);
    final tid = await activeTenantId;
    var imported = 0;
    var skipped = 0;
    for (final line in csvLines.skip(1)) {
      final parts = line.split(',').map((e) => e.trim()).toList();
      if (parts.isEmpty || parts.every((e) => e.isEmpty)) continue;
      final fullName = parts.isNotEmpty ? parts[0] : '';
      final email = parts.length > 1 ? parts[1] : '';
      final phone = parts.length > 2 ? parts[2] : '';
      final company = parts.length > 3 ? parts[3] : '';
      final requirements = parts.length > 4 ? parts[4] : '';
      if (fullName.isEmpty && email.isEmpty && phone.isEmpty) {
        skipped++;
        continue;
      }
      final dupes = await findDuplicateLeads(
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
      );
      if (dupes.isNotEmpty) {
        skipped++;
        continue;
      }
      await client.from('bos_leads').insert({
        'id': _uuid.v4(),
        'tenant_id': tid,
        'full_name': fullName.isEmpty ? null : fullName,
        'email': email.isEmpty ? null : email,
        'phone': phone.isEmpty ? null : phone,
        'company_name': company.isEmpty ? null : company,
        'requirements': requirements.isEmpty ? null : requirements,
        'source': 'csv',
        'stage': 'new',
      });
      imported++;
    }
    return (imported: imported, skipped: skipped);
  }

  Future<List<BosActivity>> listActivities({
    String? leadId,
    String? contactId,
    String? companyId,
    String? dealId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    if (companyId != null) {
      final contactIds =
          (await listContacts(companyId: companyId)).map((c) => c.id).toSet();
      final dealIds =
          (await listDeals(companyId: companyId)).map((d) => d.id).toSet();
      final all = await client
          .from('bos_activities')
          .select()
          .eq('tenant_id', tid)
          .order('created_at', ascending: false);
      return (all as List)
          .map((r) => BosActivity.fromMap(SupabaseRepositoryBase.rowToMap(r)))
          .where(
            (a) =>
                (a.contactId != null && contactIds.contains(a.contactId)) ||
                (a.dealId != null && dealIds.contains(a.dealId)),
          )
          .toList();
    }
    var qb = client.from('bos_activities').select().eq('tenant_id', tid);
    if (leadId != null) qb = qb.eq('lead_id', leadId);
    if (contactId != null) qb = qb.eq('contact_id', contactId);
    if (dealId != null) qb = qb.eq('deal_id', dealId);
    final res = await qb.order('created_at', ascending: false);
    return (res as List)
        .map((r) => BosActivity.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<String> addActivity({
    required String activityType,
    String? subject,
    String? body,
    String? leadId,
    String? contactId,
    String? dealId,
    String? createdBy,
    DateTime? dueAt,
    Map<String, dynamic>? meta,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_activities').insert({
      'id': id,
      'tenant_id': tid,
      'activity_type': activityType,
      'subject': subject,
      'body': body,
      'lead_id': leadId,
      'contact_id': contactId,
      'deal_id': dealId,
      'created_by': createdBy,
      if (dueAt != null) 'due_at': dueAt.toIso8601String(),
      if (meta != null && meta.isNotEmpty) 'meta': meta,
    });
    await writeAuditLog(
      action: 'activity.create',
      entityType: 'bos_activities',
      entityId: id,
      meta: {
        'type': activityType,
        if (leadId != null) 'lead_id': leadId,
        if (contactId != null) 'contact_id': contactId,
        if (dealId != null) 'deal_id': dealId,
      },
    );
    return id;
  }

  Future<List<BosActivity>> listLeadActivities(String leadId) =>
      listActivities(leadId: leadId);

  Future<String> addLeadActivity({
    required String leadId,
    required String activityType,
    String? subject,
    String? body,
    String? createdBy,
    Map<String, dynamic>? meta,
  }) =>
      addActivity(
        activityType: activityType,
        subject: subject,
        body: body,
        leadId: leadId,
        createdBy: createdBy,
        meta: meta,
      );

  Future<void> setLeadFollowUp(String leadId, DateTime? when) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_leads').update({
      'next_follow_up_at': when?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', leadId);
    await writeAuditLog(
      action: 'lead.follow_up',
      entityType: 'bos_leads',
      entityId: leadId,
      meta: {'next_follow_up_at': when?.toIso8601String()},
    );
    if (when != null) {
      await addActivity(
        activityType: 'follow_up',
        subject: 'Follow-up scheduled',
        body: when.toIso8601String(),
        leadId: leadId,
        dueAt: when,
      );
    }
  }

  Future<List<BosLead>> listLeadsOverdueFollowUp() async {
    final leads = await listLeads();
    final now = DateTime.now();
    return leads
        .where(
          (l) =>
              l.nextFollowUpAt != null &&
              l.nextFollowUpAt!.isBefore(now) &&
              l.stage != 'won' &&
              l.stage != 'lost',
        )
        .toList();
  }

  Future<List<BosContact>> listContacts({String? query, String? companyId}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client
        .from('bos_contacts')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    if (companyId != null) qb = qb.eq('company_id', companyId);
    final res = await qb.order('created_at', ascending: false);
    var list = (res as List)
        .map((r) => BosContact.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
    final q = query?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.displayName.toLowerCase().contains(q) ||
                (c.email?.toLowerCase().contains(q) ?? false) ||
                (c.phone?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  Future<BosContact?> getContact(String contactId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final res = await client
        .from('bos_contacts')
        .select()
        .eq('id', contactId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    return res == null ? null : BosContact.fromMap(SupabaseRepositoryBase.rowToMap(res));
  }

  Future<String> createContact(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_contacts').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
    });
    await writeAuditLog(action: 'contact.create', entityType: 'bos_contacts', entityId: id);
    return id;
  }

  Future<void> updateContact(String contactId, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_contacts').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', contactId);
    await writeAuditLog(
      action: 'contact.update',
      entityType: 'bos_contacts',
      entityId: contactId,
      meta: updates,
    );
  }

  Future<void> softDeleteContact(String contactId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_contacts').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', contactId);
    await writeAuditLog(action: 'contact.delete', entityType: 'bos_contacts', entityId: contactId);
  }

  Future<List<BosCompany>> listCompanies({String? query}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_companies')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    var list = (res as List)
        .map((r) => BosCompany.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
    final q = query?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                (c.industry?.toLowerCase().contains(q) ?? false) ||
                (c.email?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  Future<BosCompany?> getCompany(String companyId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final res = await client
        .from('bos_companies')
        .select()
        .eq('id', companyId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    return res == null ? null : BosCompany.fromMap(SupabaseRepositoryBase.rowToMap(res));
  }

  Future<String> createCompany(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_companies').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
    });
    await writeAuditLog(action: 'company.create', entityType: 'bos_companies', entityId: id);
    return id;
  }

  Future<void> updateCompany(String companyId, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_companies').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', companyId);
    await writeAuditLog(
      action: 'company.update',
      entityType: 'bos_companies',
      entityId: companyId,
      meta: updates,
    );
  }

  Future<void> softDeleteCompany(String companyId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_companies').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', companyId);
    await writeAuditLog(action: 'company.delete', entityType: 'bos_companies', entityId: companyId);
  }

  Future<List<BosActivity>> listContactActivities(String contactId) =>
      listActivities(contactId: contactId);

  Future<List<BosActivity>> listDealActivities(String dealId) =>
      listActivities(dealId: dealId);

  Future<List<BosActivity>> listCompanyActivities(String companyId) =>
      listActivities(companyId: companyId);

  Future<BosDeal?> getDeal(String dealId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final res = await client
        .from('bos_deals')
        .select()
        .eq('id', dealId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    return res == null ? null : BosDeal.fromMap(SupabaseRepositoryBase.rowToMap(res));
  }

  Future<void> softDeleteDeal(String dealId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_deals').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', dealId);
    await writeAuditLog(action: 'deal.delete', entityType: 'bos_deals', entityId: dealId);
  }

  Future<List<BosDeal>> listDeals({String? contactId, String? companyId, String? stage}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client
        .from('bos_deals')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    if (contactId != null) qb = qb.eq('contact_id', contactId);
    if (companyId != null) qb = qb.eq('company_id', companyId);
    if (stage != null) qb = qb.eq('stage', stage);
    final res = await qb.order('created_at', ascending: false);
    return (res as List).map((r) => BosDeal.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<List<BosTicket>> listTicketsForContact(String contactId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_tickets')
        .select()
        .eq('tenant_id', tid)
        .eq('contact_id', contactId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List).map((r) => BosTicket.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createDeal(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    final probability = data['probability'];
    final payload = Map<String, dynamic>.from(data)..remove('probability');
    if (probability != null) {
      final meta = Map<String, dynamic>.from(
        (payload['meta'] is Map) ? Map<String, dynamic>.from(payload['meta'] as Map) : {},
      );
      meta['probability'] = probability;
      payload['meta'] = meta;
    }
    await client.from('bos_deals').insert({
      ...payload,
      'id': id,
      'tenant_id': tid,
      'stage': payload['stage'] ?? 'qualification',
    });
    await writeAuditLog(action: 'deal.create', entityType: 'bos_deals', entityId: id);
    return id;
  }

  Future<void> updateDeal(String dealId, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final payload = Map<String, dynamic>.from(updates);
    if (payload.containsKey('probability')) {
      final existing = await client.from('bos_deals').select('meta').eq('id', dealId).maybeSingle();
      final meta = Map<String, dynamic>.from(
        (existing?['meta'] is Map) ? Map<String, dynamic>.from(existing!['meta'] as Map) : {},
      );
      meta['probability'] = payload.remove('probability');
      payload['meta'] = meta;
    }
    await client.from('bos_deals').update({
      ...payload,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', dealId);
    await writeAuditLog(action: 'deal.update', entityType: 'bos_deals', entityId: dealId, meta: updates);
  }

  Future<void> updateDealStage(String dealId, String stage) async {
    await updateDeal(dealId, {'stage': stage});
  }

  Future<List<BosPipelineStage>> listPipelineStages() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_pipeline_stages')
        .select()
        .eq('tenant_id', tid)
        .order('sort_order');
    final list = (res as List)
        .map((r) => BosPipelineStage.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
    if (list.isNotEmpty) return list;
    await ensureDefaultPipelineStages();
    final again = await client
        .from('bos_pipeline_stages')
        .select()
        .eq('tenant_id', tid)
        .order('sort_order');
    return (again as List)
        .map((r) => BosPipelineStage.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<void> ensureDefaultPipelineStages() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final tid = await activeTenantId;
    const defaults = [
      ('qualification', 'Qualification', 1, false, false),
      ('discovery', 'Discovery', 2, false, false),
      ('proposal', 'Proposal', 3, false, false),
      ('negotiation', 'Negotiation', 4, false, false),
      ('won', 'Won', 5, true, false),
      ('lost', 'Lost', 6, false, true),
    ];
    for (final d in defaults) {
      await client.from('bos_pipeline_stages').upsert({
        'tenant_id': tid,
        'code': d.$1,
        'label': d.$2,
        'sort_order': d.$3,
        'is_won': d.$4,
        'is_lost': d.$5,
      }, onConflict: 'tenant_id,code');
    }
  }

  /// Convert lead → company + contact (+ optional deal). Stage becomes `won` (= converted).
  Future<({String? companyId, String contactId, String? dealId})> convertLead({
    required String leadId,
    String? dealTitle,
    bool createDeal = true,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) {
      throw Exception('Not authenticated');
    }
    final tid = await activeTenantId;
    final leadRes =
        await client.from('bos_leads').select().eq('id', leadId).maybeSingle();
    if (leadRes == null) throw Exception('Lead not found');
    final lead = BosLead.fromMap(SupabaseRepositoryBase.rowToMap(leadRes));

    String? companyId = lead.companyId;
    if ((companyId == null || companyId.isEmpty) &&
        lead.companyName != null &&
        lead.companyName!.isNotEmpty) {
      companyId = _uuid.v4();
      await client.from('bos_companies').insert({
        'id': companyId,
        'tenant_id': tid,
        'name': lead.companyName!,
      });
    }

    final contactId = lead.contactId ?? _uuid.v4();
    if (lead.contactId == null) {
      await client.from('bos_contacts').insert({
        'id': contactId,
        'tenant_id': tid,
        'full_name': lead.fullName,
        'email': lead.email,
        'phone': lead.phone,
        'company_id': companyId,
      });
    }

    String? dealId;
    if (createDeal) {
      dealId = _uuid.v4();
      await client.from('bos_deals').insert({
        'id': dealId,
        'tenant_id': tid,
        'title': dealTitle ?? '${lead.displayName} deal',
        'contact_id': contactId,
        'company_id': companyId,
        'lead_id': leadId,
        'stage': 'qualification',
      });
    }

    await client.from('bos_leads').update({
      'contact_id': contactId,
      'company_id': companyId,
      'stage': 'won',
    }).eq('id', leadId);

    await addLeadActivity(
      leadId: leadId,
      activityType: 'converted',
      subject: createDeal ? 'Converted to customer + deal' : 'Converted to customer',
      body: dealTitle,
    );
    await writeAuditLog(
      action: 'lead.convert',
      entityType: 'bos_leads',
      entityId: leadId,
      meta: {'contact_id': contactId, 'company_id': companyId, 'deal_id': dealId},
    );
    return (companyId: companyId, contactId: contactId, dealId: dealId);
  }

  Future<void> convertLeadToDeal(String leadId, String dealTitle) async {
    await convertLead(leadId: leadId, dealTitle: dealTitle, createDeal: true);
  }

  Future<Map<String, dynamic>> overviewStats() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return {};
    final tid = await activeTenantId;
    final leads = await client
        .from('bos_leads')
        .select('stage,score')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final deals = await client
        .from('bos_deals')
        .select('stage')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final contacts = await client
        .from('bos_contacts')
        .select('id')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final companies = await client
        .from('bos_companies')
        .select('id')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final tickets = await client
        .from('bos_tickets')
        .select('status')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final leadRows = leads as List;
    final dealRows = deals as List;
    final ticketRows = tickets as List;
    final hotLeads = leadRows.where((l) => l['score'] == 'hot').length;
    final openDeals = dealRows
        .where((d) => d['stage'] != 'won' && d['stage'] != 'lost')
        .length;
    final openTickets = ticketRows
        .where((t) => t['status'] == 'open' || t['status'] == 'in_progress')
        .length;
    final byStage = <String, int>{};
    for (final l in leadRows) {
      final s = (l['stage'] as String?) ?? 'new';
      byStage[s] = (byStage[s] ?? 0) + 1;
    }
    return {
      'leads_total': leadRows.length,
      'leads_hot': hotLeads,
      'deals_open': openDeals,
      'deals_total': dealRows.length,
      'leads_by_stage': byStage,
      'customers_contacts': (contacts as List).length,
      'customers_companies': (companies as List).length,
      'customers_total': (contacts as List).length + (companies as List).length,
      'tickets_open': openTickets,
      'tickets_total': ticketRows.length,
    };
  }

  // â”€â”€ Phase 2+ modules â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<BosConversation>> listConversations({String? channel}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client
        .from('bos_conversations')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    if (channel != null && channel != 'all') {
      if (channel == 'social') {
        qb = qb.inFilter('channel', ['facebook', 'instagram']);
      } else {
        qb = qb.eq('channel', channel);
      }
    }
    final res = await qb.order('created_at', ascending: false);
    return (res as List)
        .map((r) => BosConversation.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<List<BosMessage>> listMessages(String conversationId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (res as List).map((r) => BosMessage.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createConversation(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_conversations').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'channel': data['channel'] ?? 'whatsapp',
    });
    return id;
  }

  Future<String> sendMessage({
    required String conversationId,
    required String body,
    String direction = 'outbound',
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_messages').insert({
      'id': id,
      'tenant_id': tid,
      'conversation_id': conversationId,
      'direction': direction,
      'body': body,
      'status': 'sent',
    });
    await client.from('bos_conversations').update({
      'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
    return id;
  }

  Future<void> linkConversationLead(String conversationId, String leadId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_conversations').update({
      'lead_id': leadId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  Future<List<BosCampaign>> listCampaigns() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_campaigns')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List).map((r) => BosCampaign.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createCampaign(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_campaigns').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'status': data['status'] ?? 'draft',
    });
    return id;
  }

  Future<({int imported, int skipped})> importCampaignRecipients(
    String campaignId,
    List<String> csvLines,
  ) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return (imported: 0, skipped: 0);
    final tid = await activeTenantId;
    var imported = 0;
    var skipped = 0;
    for (final line in csvLines.skip(1)) {
      final parts = line.split(',').map((e) => e.trim()).toList();
      if (parts.isEmpty || parts[0].isEmpty) {
        skipped++;
        continue;
      }
      await client.from('bos_campaign_recipients').insert({
        'id': _uuid.v4(),
        'tenant_id': tid,
        'campaign_id': campaignId,
        'phone': parts[0],
        'full_name': parts.length > 1 ? parts[1] : null,
        'email': parts.length > 2 ? parts[2] : null,
        'status': 'pending',
      });
      imported++;
    }
    return (imported: imported, skipped: skipped);
  }

  Future<List<BosKbDocument>> listKbDocuments({String? collection}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client
        .from('bos_kb_documents')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    if (collection != null) qb = qb.eq('collection', collection);
    final res = await qb.order('created_at', ascending: false);
    return (res as List)
        .map((r) => BosKbDocument.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<String> createKbDocument(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_kb_documents').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'collection': data['collection'] ?? 'general',
    });
    return id;
  }

  Future<List<BosQuotation>> listQuotations({String? dealId, String? leadId}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client
        .from('bos_quotations')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    if (dealId != null) qb = qb.eq('deal_id', dealId);
    if (leadId != null) qb = qb.eq('lead_id', leadId);
    final res = await qb.order('created_at', ascending: false);
    return (res as List).map((r) => BosQuotation.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  /// Draft quotation from a deal (single line = deal amount or placeholder).
  Future<String> createQuotationFromDeal(String dealId, {String? titleOverride}) async {
    final deal = await getDeal(dealId);
    if (deal == null) throw Exception('Deal not found');
    BosContact? contact;
    BosCompany? company;
    if (deal.contactId != null) contact = await getContact(deal.contactId!);
    if (deal.companyId != null) company = await getCompany(deal.companyId!);
    final amount = deal.amountPaise > 0 ? deal.amountPaise : 100000;
    final id = await createQuotation(
      title: titleOverride ?? 'Quote — ${deal.title}',
      dealId: deal.id,
      leadId: deal.leadId,
      contactId: deal.contactId,
      companyId: deal.companyId,
      customerName: contact?.displayName ?? company?.name,
      customerPhone: contact?.phone ?? company?.phone,
      notes: 'Created from CRM deal',
      lines: [
        {
          'category': 'services',
          'description': deal.title,
          'qty': 1,
          'unit': 'lot',
          'unit_price_paise': amount,
          'tax_percent': 18,
        },
      ],
    );
    await addActivity(
      activityType: 'quotation',
      subject: 'Quotation created',
      body: titleOverride ?? 'Quote — ${deal.title}',
      dealId: deal.id,
      contactId: deal.contactId,
    );
    await writeAuditLog(
      action: 'deal.quote_create',
      entityType: 'bos_deals',
      entityId: dealId,
      meta: {'quotation_id': id},
    );
    return id;
  }

  Future<String> createQuotation({
    required String title,
    required List<Map<String, dynamic>> lines,
    String? notes,
    String? dealId,
    String? leadId,
    String? contactId,
    String? companyId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    Map<String, dynamic>? boqMeta,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    final quoteNumber =
        'BQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    var subtotal = 0;
    var tax = 0;
    final prepared = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final qty = (line['qty'] as num?)?.toDouble() ?? 1;
      final unit = (line['unit_price_paise'] as num?)?.toInt() ?? 0;
      final taxPct = (line['tax_percent'] as num?)?.toDouble() ?? 18;
      final lineSub = (qty * unit).round();
      final lineTax = (lineSub * taxPct / 100).round();
      subtotal += lineSub;
      tax += lineTax;
      prepared.add({
        'id': _uuid.v4(),
        'tenant_id': tid,
        'quotation_id': id,
        'sort_order': i,
        'category': line['category'],
        'description': line['description'] ?? 'Item',
        'qty': qty,
        'unit': line['unit'] ?? 'nos',
        'unit_price_paise': unit,
        'tax_percent': taxPct,
        'line_total_paise': lineSub + lineTax,
      });
    }
    await client.from('bos_quotations').insert({
      'id': id,
      'tenant_id': tid,
      'quote_number': quoteNumber,
      'title': title,
      'status': 'draft',
      'deal_id': dealId,
      'lead_id': leadId,
      'contact_id': contactId,
      'company_id': companyId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'subtotal_paise': subtotal,
      'tax_paise': tax,
      'total_paise': subtotal + tax,
      'notes': notes,
      'boq_meta': {
        'line_count': lines.length,
        ...?boqMeta,
      },
      'valid_until': DateTime.now().add(const Duration(days: 15)).toIso8601String().substring(0, 10),
    });
    for (final row in prepared) {
      await client.from('bos_quotation_lines').insert(row);
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> listQuotationLines(String quotationId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_quotation_lines')
        .select()
        .eq('quotation_id', quotationId)
        .order('sort_order');
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<void> updateQuotationStatus(String quotationId, String status) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_quotations').update({'status': status}).eq('id', quotationId);
  }

  /// CCTV BOQ → cameras, NVR, switches, cable, storage, accessories, labour + GST.
  Future<String> createCctvBoqQuotation({
    required int cameras,
    required int nvrChannels,
    required int cableMeters,
    required int labourDays,
    int hddTb = 4,
    int accessoriesKits = 1,
    String cameraType = 'IP',
    String title = 'CCTV BOQ',
    String? dealId,
    String? leadId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? notes,
  }) async {
    final cameraPaise = cameraType.toUpperCase() == 'HD' ? 220000 : 350000;
    const nvrPaisePerCh = 75000;
    const switchPaise = 450000;
    const cablePaise = 2500;
    const storagePaisePerTb = 450000;
    const accessoryPaise = 150000;
    const labourPaise = 250000;
    final switchQty = (cameras / 8).ceil().clamp(1, 99);
    final nvrPaise = (nvrChannels * nvrPaisePerCh).clamp(800000, 5000000);
    final lines = <Map<String, dynamic>>[
      {
        'category': 'Cameras',
        'description': '$cameraType Camera',
        'qty': cameras,
        'unit_price_paise': cameraPaise,
      },
      {
        'category': 'NVR',
        'description': 'NVR $nvrChannels-ch',
        'qty': 1,
        'unit_price_paise': nvrPaise,
      },
      {
        'category': 'Network',
        'description': 'PoE / Network Switch',
        'qty': switchQty,
        'unit_price_paise': switchPaise,
      },
      {
        'category': 'Cabling',
        'description': 'Cat6 / Coax + conduit (m)',
        'qty': cableMeters,
        'unit_price_paise': cablePaise,
      },
      {
        'category': 'Storage',
        'description': 'Surveillance HDD ${hddTb}TB',
        'qty': hddTb,
        'unit_price_paise': storagePaisePerTb,
      },
      {
        'category': 'Accessories',
        'description': 'Power / connectors / junction kit',
        'qty': accessoriesKits,
        'unit_price_paise': accessoryPaise,
      },
      {
        'category': 'Labour',
        'description': 'Installation & commissioning (days)',
        'qty': labourDays,
        'unit_price_paise': labourPaise,
      },
    ];
    return createQuotation(
      title: title,
      lines: lines,
      notes: notes,
      dealId: dealId,
      leadId: leadId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      boqMeta: {
        'type': 'cctv',
        'cameras': cameras,
        'nvr_channels': nvrChannels,
        'camera_type': cameraType,
        'cable_meters': cableMeters,
        'labour_days': labourDays,
        'hdd_tb': hddTb,
      },
    );
  }

  /// Website / app estimate calculator (paise).
  Map<String, dynamic> computeWebsiteAppEstimate({
    required String estimateType,
    required int pages,
    required int platforms,
    bool ecommerce = false,
    bool adminPanel = true,
    bool seoPack = false,
  }) {
    final pagePaise = ecommerce ? 2200000 : 1500000;
    var websitePaise = pages * pagePaise;
    if (adminPanel) websitePaise += 8000000;
    if (ecommerce) websitePaise += 15000000;
    if (seoPack) websitePaise += 5000000;
    final appPaise = platforms * (ecommerce ? 32000000 : 25000000);
    final total = switch (estimateType) {
      'mobile_app' => appPaise,
      'both' => websitePaise + appPaise,
      _ => websitePaise,
    };
    return {
      'website_paise': estimateType == 'mobile_app' ? 0 : websitePaise,
      'app_paise': estimateType == 'website' ? 0 : appPaise,
      'total_paise': total,
      'answers': {
        'estimate_type': estimateType,
        'pages': pages,
        'platforms': platforms,
        'ecommerce': ecommerce,
        'admin_panel': adminPanel,
        'seo_pack': seoPack,
      },
    };
  }

  Future<String> createEstimateFromAnswers({
    required String title,
    required String estimateType,
    required Map<String, dynamic> computed,
    String? leadId,
    String? dealId,
  }) async {
    return createEstimate({
      'title': title,
      'estimate_type': estimateType,
      'answers': computed['answers'],
      'breakdown': {
        'website_paise': computed['website_paise'],
        'app_paise': computed['app_paise'],
      },
      'total_paise': computed['total_paise'],
      'lead_id': leadId,
      'deal_id': dealId,
      'status': 'draft',
    });
  }

  Future<String> convertEstimateToProposal(String estimateId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final row = await client.from('bos_estimates').select().eq('id', estimateId).maybeSingle();
    if (row == null) throw Exception('Estimate not found');
    final e = BosEstimate.fromMap(SupabaseRepositoryBase.rowToMap(row));
    final rupees = (e.totalPaise / 100).toStringAsFixed(0);
    final body = '''
# Proposal — ${e.title}

## Estimate type
${e.estimateType ?? 'website'}

## Investment
Approx. ₹$rupees (indicative)

## Breakdown
- Website: ₹${((e.breakdown?['website_paise'] as num?) ?? 0) / 100}
- App: ₹${((e.breakdown?['app_paise'] as num?) ?? 0) / 100}

## Answers
${e.answers}

## Next steps
1. Confirm scope & platforms
2. Sign-off on milestones
3. Kickoff workshop
''';
    final proposalId = await createProposal({
      'title': 'Proposal from ${e.title}',
      'body_markdown': body,
      'status': 'draft',
      'lead_id': e.leadId ?? row['lead_id'],
      'estimate_id': estimateId,
    });
    await client.from('bos_estimates').update({
      'proposal_id': proposalId,
      'status': 'converted',
    }).eq('id', estimateId);
    return proposalId;
  }

  Future<Map<String, dynamic>> draftProposalAi({
    String? dealId,
    String? leadId,
    String? quotationId,
    String? title,
  }) async {
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-proposal-draft')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tenant_id': tid,
        if (dealId != null) 'deal_id': dealId,
        if (leadId != null) 'lead_id': leadId,
        if (quotationId != null) 'quotation_id': quotationId,
        if (title != null) 'title': title,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<List<Map<String, dynamic>>> listProposalTemplates() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_proposal_templates')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('name');
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<void> updateProposal(String id, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_proposals').update(updates).eq('id', id);
  }

  Future<List<BosProposal>> listProposals() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_proposals')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List).map((r) => BosProposal.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createProposal(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_proposals').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'status': data['status'] ?? 'draft',
    });
    return id;
  }

  Future<List<BosEstimate>> listEstimates() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_estimates')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List).map((r) => BosEstimate.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createEstimate(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_estimates').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
    });
    return id;
  }

  Future<List<BosProject>> listProjects() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_projects')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List).map((r) => BosProject.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createProject(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_projects').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'status': data['status'] ?? 'planning',
    });
    return id;
  }

  Future<String> createProjectFromDeal(String dealId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final dealRes =
        await client.from('bos_deals').select().eq('id', dealId).maybeSingle();
    if (dealRes == null) throw Exception('Deal not found');
    final deal = BosDeal.fromMap(SupabaseRepositoryBase.rowToMap(dealRes));
    final projectId = await createProject({
      'name': deal.title,
      'deal_id': deal.id,
      'company_id': deal.companyId,
      'contact_id': deal.contactId,
      'status': 'planning',
    });
    final tid = await activeTenantId;
    final milestones = ['Kickoff', 'Supply / install', 'Handover'];
    for (var i = 0; i < milestones.length; i++) {
      await client.from('bos_project_milestones').insert({
        'id': _uuid.v4(),
        'tenant_id': tid,
        'project_id': projectId,
        'title': milestones[i],
        'sort_order': i,
        'due_date': DateTime.now().add(Duration(days: (i + 1) * 14)).toIso8601String().substring(0, 10),
      });
    }
    return projectId;
  }

  Future<void> updateProjectStatus(String projectId, String status) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_projects').update({'status': status}).eq('id', projectId);
  }

  Future<List<Map<String, dynamic>>> listProjectMilestones(String projectId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_project_milestones')
        .select()
        .eq('project_id', projectId)
        .order('sort_order');
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<String> addProjectMilestone({
    required String projectId,
    required String title,
    String? dueDate,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_project_milestones').insert({
      'id': id,
      'tenant_id': tid,
      'project_id': projectId,
      'title': title,
      'due_date': dueDate,
      'sort_order': 99,
    });
    return id;
  }

  Future<void> completeMilestone(String milestoneId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_project_milestones').update({
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', milestoneId);
  }

  Future<List<Map<String, dynamic>>> listProjectTasks(String projectId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_project_tasks')
        .select()
        .eq('project_id', projectId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<String> addProjectTask({
    required String projectId,
    required String title,
    String? milestoneId,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_project_tasks').insert({
      'id': id,
      'tenant_id': tid,
      'project_id': projectId,
      'milestone_id': milestoneId,
      'title': title,
      'status': 'todo',
    });
    return id;
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_project_tasks').update({'status': status}).eq('id', taskId);
  }

  Future<String> createTicketFull({
    required String subject,
    String? description,
    String priority = 'medium',
    String? projectId,
    String? contactId,
    String? assigneeFirebaseUid,
    int slaHours = 24,
  }) async {
    final due = DateTime.now().add(Duration(hours: slaHours));
    return createTicket({
      'subject': subject,
      'description': description,
      'priority': priority,
      'project_id': projectId,
      'contact_id': contactId,
      'assignee_firebase_uid': assigneeFirebaseUid,
      'sla_hours': slaHours,
      'sla_due_at': due.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> listTicketComments(String ticketId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_ticket_comments')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<void> addTicketComment(String ticketId, String body, {String? createdBy}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final tid = await activeTenantId;
    await client.from('bos_ticket_comments').insert({
      'id': _uuid.v4(),
      'tenant_id': tid,
      'ticket_id': ticketId,
      'body': body,
      'created_by': createdBy,
    });
  }

  Future<Map<String, dynamic>> completeVoiceCall(
    String callId, {
    String? outcome,
    DateTime? nextFollowUpAt,
    String? transcript,
    String? audioUrl,
    int? durationSec,
  }) async {
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-voice-complete')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'call_id': callId,
        if (outcome != null) 'outcome': outcome,
        if (nextFollowUpAt != null) 'next_follow_up_at': nextFollowUpAt.toIso8601String(),
        if (transcript != null) 'transcript': transcript,
        if (audioUrl != null && audioUrl.isNotEmpty) 'audio_url': audioUrl,
        if (durationSec != null) 'duration_sec': durationSec,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<String> generateVoiceScript(String leadId) async {
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-voice-script')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'lead_id': leadId}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return (body['script'] as String?)?.trim().isNotEmpty == true
        ? body['script'] as String
        : 'Hi, this is DG.YARD calling regarding your enquiry. Do you have two minutes?';
  }

  /// Queue outbound AI follow-up call for a lead (optional AI script generation).
  Future<String> queueFollowUpCall({
    required String leadId,
    String? phone,
    DateTime? scheduledAt,
    bool generateScript = true,
    String? scriptOverride,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final leadRes = await client.from('bos_leads').select().eq('id', leadId).maybeSingle();
    if (leadRes == null) throw Exception('Lead not found');
    final lead = BosLead.fromMap(SupabaseRepositoryBase.rowToMap(leadRes));
    final dial = (phone ?? lead.phone)?.trim();
    if (dial == null || dial.isEmpty) {
      throw Exception('Lead has no phone number');
    }
    var script = scriptOverride?.trim();
    if ((script == null || script.isEmpty) && generateScript) {
      try {
        script = await generateVoiceScript(leadId);
      } catch (_) {
        script = null;
      }
    }
    script ??=
        'Hi ${lead.displayName}, this is DG.YARD calling about ${lead.companyName ?? "your enquiry"}. '
        '${lead.requirements != null && lead.requirements!.isNotEmpty ? "You asked about: ${lead.requirements}. " : ""}'
        'Are you available for a quick follow-up?';

    final when = scheduledAt ?? lead.nextFollowUpAt ?? DateTime.now();
    final voiceProvider = await resolveActiveVoiceProvider();
    final id = await createVoiceCall({
      'phone': dial,
      'status': 'queued',
      'direction': 'outbound',
      'provider': voiceProvider,
      'script': script,
      'lead_id': leadId,
      'scheduled_at': when.toIso8601String(),
      'meta': {
        'source': 'follow_up',
        'scheduled_at': when.toIso8601String(),
        'voice_provider': voiceProvider,
      },
    });
    await addActivity(
      activityType: 'voice_queued',
      subject: 'AI call queued',
      body: script,
      leadId: leadId,
      dueAt: when,
      meta: {'call_id': id},
    );
    await writeAuditLog(
      action: 'voice.queue_follow_up',
      entityType: 'bos_voice_calls',
      entityId: id,
      meta: {'lead_id': leadId, 'scheduled_at': when.toIso8601String()},
    );
    // Dial now if due (Exotel when tenant secrets set; else stub).
    if (!when.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      try {
        await dialVoiceCall(id);
      } catch (_) {}
    }
    return id;
  }

  /// Active voice provider from tenant settings (api_config / ai_sales).
  Future<String> resolveActiveVoiceProvider() async {
    try {
      final cfg = await getTenantApiConfig();
      final apiCfg = cfg['api_config'];
      if (apiCfg is Map && apiCfg['voice'] is Map) {
        final p = '${(apiCfg['voice'] as Map)['provider'] ?? ''}'.trim();
        if (p.isNotEmpty) return p;
      }
      final ai = cfg['ai_sales'];
      if (ai is Map) {
        final p = '${ai['voice_provider'] ?? ''}'.trim();
        if (p.isNotEmpty) return p;
      }
    } catch (_) {}
    return 'stub';
  }

  /// Status callback URL for Twilio / Exotel console (copy into provider webhook).
  Future<String> voiceWebhookUrl({required String provider, bool inbound = false}) async {
    final tid = await activeTenantId;
    final base = SupabaseConfig.functionUrl('bos-voice-webhook');
    final q = StringBuffer('$base?tenant_id=$tid&provider=$provider');
    if (inbound) q.write('&inbound=1');
    return q.toString();
  }

  Future<Map<String, dynamic>> previewVoiceTts({
    required String text,
    String language = 'hi-IN',
  }) async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-voice-tts')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'tenant_id': tid,
        'text': text,
        'language': language,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<List<Map<String, dynamic>>> listVoiceEvents({int limit = 40}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    try {
      final res = await client
          .from('bos_voice_events')
          .select()
          .eq('tenant_id', tid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Complete calls stuck after Telnyx hangup when recording never arrived (~45s).
  Future<int> reconcilePendingVoiceCompletions() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return 0;
    final tid = await activeTenantId;
    final rows = await client
        .from('bos_voice_calls')
        .select('id,status,meta,recording_url')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .inFilter('status', ['queued', 'ringing', 'in_progress']);
    final now = DateTime.now();
    var n = 0;
    for (final r in rows as List) {
      final meta = r['meta'] is Map ? Map<String, dynamic>.from(r['meta'] as Map) : <String, dynamic>{};
      final pending = meta['pending_complete_at']?.toString();
      final hangup = meta['hangup_at']?.toString();
      DateTime? due;
      if (pending != null) due = DateTime.tryParse(pending);
      if (due == null && hangup != null) {
        final h = DateTime.tryParse(hangup);
        if (h != null) due = h.add(const Duration(seconds: 45));
      }
      if (due == null || due.isAfter(now)) continue;
      try {
        await completeVoiceCall(
          r['id'] as String,
          outcome: 'interested',
          audioUrl: (r['recording_url'] ?? meta['recording_url'] ?? meta['audio_url'])?.toString(),
        );
        n++;
      } catch (_) {}
    }
    return n;
  }

  Future<Map<String, dynamic>> voiceProviderHealth() async {
    final provider = await resolveActiveVoiceProvider();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) {
      return {'provider': provider, 'last_dial_live': null, 'last_webhook_age_sec': null};
    }
    final tid = await activeTenantId;
    final calls = await client
        .from('bos_voice_calls')
        .select('meta,created_at,provider')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(1);
    bool? lastLive;
    if ((calls as List).isNotEmpty) {
      final meta = calls.first['meta'] is Map
          ? Map<String, dynamic>.from(calls.first['meta'] as Map)
          : <String, dynamic>{};
      lastLive = meta['dial_sim'] != true;
    }
    int? webhookAgeSec;
    try {
      final ev = await client
          .from('bos_voice_events')
          .select('created_at')
          .eq('tenant_id', tid)
          .order('created_at', ascending: false)
          .limit(1);
      if ((ev as List).isNotEmpty) {
        final t = DateTime.tryParse('${ev.first['created_at']}');
        if (t != null) {
          webhookAgeSec = DateTime.now().difference(t).inSeconds;
        }
      }
    } catch (_) {}
    return {
      'provider': provider,
      'last_dial_live': lastLive,
      'last_webhook_age_sec': webhookAgeSec,
    };
  }

  /// Dial queued voice calls whose scheduled_at is due (missed-call callbacks, follow-ups).
  Future<Map<String, dynamic>> runDueVoiceCallbacks({int limit = 15}) async {
    final due = await listVoiceCalls(dueOnly: true);
    final targets = due.take(limit).toList();
    var dialed = 0;
    var stub = 0;
    var failed = 0;
    for (final c in targets) {
      try {
        final r = await dialVoiceCall(c.id);
        if (r['sim'] == true) {
          stub++;
        } else {
          dialed++;
        }
      } catch (_) {
        failed++;
      }
    }
    return {
      'due': targets.length,
      'dialed': dialed,
      'stub': stub,
      'failed': failed,
    };
  }

  Future<Map<String, dynamic>> voiceReadinessChecklist() async {
    final provider = await resolveActiveVoiceProvider();
    final tid = await activeTenantId;
    final row = await getTenantSettingsRow(tid);
    final apiCfg = row?['api_config'];
    final voiceCfg = apiCfg is Map ? apiCfg['voice'] : null;
    final number = voiceCfg is Map ? '${voiceCfg['number'] ?? ''}'.trim() : '';
    final greeting = voiceCfg is Map ? '${voiceCfg['inbound_greeting'] ?? ''}'.trim() : '';
    var secretsHint = '';
    var sarvamSet = false;
    var publicKeySet = false;
    try {
      final masked = await getTenantApiConfig(tenantId: tid);
      final secrets = masked['api_secrets_masked'];
      if (secrets is Map) {
        final voice = secrets['voice'];
        if (voice is Map && voice[provider] is Map) {
          final nested = Map<String, dynamic>.from(voice[provider] as Map);
          final parts = <String>[];
          for (final e in nested.entries) {
            if (e.value is Map && (e.value as Map)['set'] == true) {
              parts.add('${e.key}');
              if (e.key == 'public_key') publicKeySet = true;
            }
          }
          secretsHint = parts.join(', ');
        }
        final sarvam = secrets['sarvam'];
        if (sarvam is Map && sarvam['api_key'] is Map && (sarvam['api_key'] as Map)['set'] == true) {
          sarvamSet = true;
        }
      }
    } catch (_) {}
    final webhook = await voiceWebhookUrl(provider: provider == 'stub' ? 'telnyx' : provider);
    return {
      'provider': provider,
      'provider_ok': provider != 'stub',
      'number_ok': number.isNotEmpty,
      'number': number,
      'secrets_ok': secretsHint.isNotEmpty || provider == 'stub',
      'secrets_hint': secretsHint,
      'sarvam_ok': sarvamSet,
      'greeting_ok': greeting.isNotEmpty,
      'greeting_preview': greeting.isEmpty ? null : (greeting.length > 60 ? '${greeting.substring(0, 60)}…' : greeting),
      'webhook_url': webhook,
      'public_key_ok': publicKeySet,
    };
  }

  Future<void> softDeleteVoiceCall(String callId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_voice_calls').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
    await writeAuditLog(
      action: 'voice.soft_delete',
      entityType: 'bos_voice_calls',
      entityId: callId,
    );
  }

  Future<Map<String, dynamic>> verifyVoiceProvider({String? provider}) async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-voice-verify')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'tenant_id': tid,
        if (provider != null) 'provider': provider,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  /// Place outbound call via Edge (`bos-voice-dial`) — live when tenant secrets set.
  Future<Map<String, dynamic>> dialVoiceCall(String callId) async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-voice-dial')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({'call_id': callId, 'tenant_id': tid}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> generateMarketing({
    required String name,
    required String brief,
    String channel = 'content',
    String tone = 'professional',
    String? campaignId,
  }) async {
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-marketing-generate')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tenant_id': tid,
        'name': name,
        'brief': brief,
        'channel': channel,
        'tone': tone,
        if (campaignId != null) 'campaign_id': campaignId,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> billingAction(
    String action, {
    String? planId,
    String? status,
    int? amountPaise,
    bool markPaid = false,
    String? metric,
    String? invoiceId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('bos-billing')),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'action': action,
        'tenant_id': tid,
        if (planId != null) 'plan_id': planId,
        if (status != null) 'status': status,
        if (amountPaise != null) 'amount_paise': amountPaise,
        'mark_paid': markPaid,
        if (metric != null) 'metric': metric,
        if (invoiceId != null) 'invoice_id': invoiceId,
        if (razorpayOrderId != null) 'razorpay_order_id': razorpayOrderId,
        if (razorpayPaymentId != null) 'razorpay_payment_id': razorpayPaymentId,
        if (razorpaySignature != null) 'razorpay_signature': razorpaySignature,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> createBillingCheckout(String planId) =>
      billingAction('create_checkout', planId: planId);

  Future<Map<String, dynamic>> verifyBillingPayment({
    required String invoiceId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) =>
      billingAction(
        'verify_payment',
        invoiceId: invoiceId,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );

  Future<Map<String, dynamic>> usageSummary() => billingAction('usage_summary');

  Future<Map<String, dynamic>> mrrOverview() => billingAction('mrr_overview');

  Future<Map<String, dynamic>> fullAnalytics() async {
    final base = await overviewStats();
    final sales = await aiSalesStats();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return {...base, ...sales};
    final tid = await activeTenantId;
    final tickets = await client
        .from('bos_tickets')
        .select('status,priority')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final projects = await client
        .from('bos_projects')
        .select('status')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final campaigns = await client
        .from('bos_campaigns')
        .select('status,sent_count,failed_count')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final quotes = await client
        .from('bos_quotations')
        .select('status,total_paise')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    final usage = await client
        .from('bos_usage_events')
        .select('metric,quantity,occurred_at')
        .eq('tenant_id', tid)
        .gte('occurred_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
    final recipients = await client
        .from('bos_campaign_recipients')
        .select('delivery_status')
        .eq('tenant_id', tid);
    final voiceRows = await client
        .from('bos_voice_calls')
        .select('status,meta,duration_sec,direction')
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null);
    var voiceLive = 0;
    var voiceStub = 0;
    var voiceSttLive = 0;
    var voiceInbound = 0;
    var voiceDurationSum = 0;
    var voiceDurationN = 0;
    final voiceList = voiceRows as List;
    for (final r in voiceList) {
      final meta = r['meta'] is Map ? Map<String, dynamic>.from(r['meta'] as Map) : <String, dynamic>{};
      final sim = meta['dial_sim'] == true;
      if (sim) {
        voiceStub++;
      } else {
        voiceLive++;
      }
      if (meta['stt_provider'] != null && meta['stt_sim'] != true) voiceSttLive++;
      if (r['direction'] == 'inbound' || meta['inbound'] == true) voiceInbound++;
      final d = (r['duration_sec'] as num?)?.toInt();
      if (d != null && d > 0) {
        voiceDurationSum += d;
        voiceDurationN++;
      }
    }
    final ticketRows = tickets as List;
    final openTickets = ticketRows.where((t) => t['status'] == 'open' || t['status'] == 'in_progress').length;
    final projectRows = projects as List;
    final activeProjects = projectRows.where((p) => p['status'] == 'active').length;
    final campaignRows = campaigns as List;
    var campaignSent = 0;
    var campaignFailed = 0;
    for (final c in campaignRows) {
      campaignSent += (c['sent_count'] as num?)?.toInt() ?? 0;
      campaignFailed += (c['failed_count'] as num?)?.toInt() ?? 0;
    }
    final quoteRows = quotes as List;
    var quoteValue = 0;
    for (final q in quoteRows) {
      quoteValue += (q['total_paise'] as num?)?.toInt() ?? 0;
    }
    final usageTotals = <String, num>{};
    for (final u in usage as List) {
      final m = '${u['metric']}';
      usageTotals[m] = (usageTotals[m] ?? 0) + ((u['quantity'] as num?) ?? 1);
    }
    final deliveryBreakdown = <String, int>{};
    for (final r in recipients as List) {
      final s = '${r['delivery_status'] ?? 'unknown'}';
      deliveryBreakdown[s] = (deliveryBreakdown[s] ?? 0) + 1;
    }
    Map<String, dynamic>? platform;
    try {
      if (SupabaseAuthService.instance.currentJwtIsSuperadmin) {
        platform = await superAdminPlatformStats();
      }
    } catch (_) {}
    return {
      ...base,
      ...sales,
      'tickets_open': openTickets,
      'tickets_total': ticketRows.length,
      'projects_active': activeProjects,
      'projects_total': projectRows.length,
      'campaign_sends': campaignSent,
      'campaign_failed': campaignFailed,
      'quotation_value_paise': quoteValue,
      'usage_30d': usageTotals,
      'delivery_breakdown': deliveryBreakdown,
      'voice_total': voiceList.length,
      'voice_live': voiceLive,
      'voice_stub': voiceStub,
      'voice_stt_live': voiceSttLive,
      'voice_inbound': voiceInbound,
      'voice_avg_duration_sec':
          voiceDurationN == 0 ? 0 : (voiceDurationSum / voiceDurationN).round(),
      if (platform != null) 'platform': platform,
    };
  }

  Future<Map<String, int>> campaignDeliveryBreakdown(String campaignId) async {
    final rows = await listCampaignRecipients(campaignId);
    final out = <String, int>{};
    for (final r in rows) {
      final s = '${r['delivery_status'] ?? r['status'] ?? 'unknown'}';
      out[s] = (out[s] ?? 0) + 1;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> listOutboundEvents({String? campaignId, int limit = 50}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var q = client
        .from('bos_outbound_events')
        .select()
        .eq('tenant_id', tid);
    if (campaignId != null) q = q.eq('campaign_id', campaignId);
    final res = await q.order('created_at', ascending: false).limit(limit);
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<void> applyMarketplaceInstall(String itemId) async {
    final tid = await activeTenantId;
    await installMarketplaceItem(tid, itemId);
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final item = await client.from('bos_marketplace_items').select().eq('id', itemId).maybeSingle();
    if (item == null) return;
    final payload = item['payload'];
    if (payload is Map && payload['collection'] != null) {
      await createKbDocument({
        'title': '${item['name']} (installed)',
        'body': item['description'] ?? 'Installed from marketplace',
        'collection': payload['collection'],
        'is_active': true,
        'meta': {'from_marketplace': itemId},
      });
    }
  }

  Future<List<BosTicket>> listTickets() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_tickets')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List).map((r) => BosTicket.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<String> createTicket(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_tickets').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'status': data['status'] ?? 'open',
      'priority': data['priority'] ?? 'medium',
    });
    return id;
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_tickets').update({
      'status': status,
      if (status == 'resolved' || status == 'closed')
        'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
    await writeAuditLog(
      action: 'ticket.status',
      entityType: 'bos_tickets',
      entityId: ticketId,
      meta: {'status': status},
    );
  }

  Future<List<BosVoiceCall>> listVoiceCalls({
    String? status,
    bool dueOnly = false,
    bool hideStub = false,
    bool includeDeleted = false,
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    var qb = client.from('bos_voice_calls').select().eq('tenant_id', tid);
    if (!includeDeleted) qb = qb.isFilter('deleted_at', null);
    if (status != null) qb = qb.eq('status', status);
    final res = await qb.order('created_at', ascending: false);
    var list = (res as List).map((r) => BosVoiceCall.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
    if (hideStub) {
      list = list.where((c) => !c.dialSim).toList();
    }
    if (dueOnly) {
      final now = DateTime.now();
      list = list
          .where(
            (c) =>
                c.isOpen &&
                (c.scheduledAt == null || !c.scheduledAt!.isAfter(now)),
          )
          .toList();
    }
    return list;
  }

  Future<String> createVoiceCall(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_voice_calls').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'status': data['status'] ?? 'queued',
      'direction': data['direction'] ?? 'outbound',
    });
    return id;
  }

  Future<List<BosMarketingCampaign>> listMarketingCampaigns() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_marketing_campaigns')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (res as List)
        .map((r) => BosMarketingCampaign.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<String> createMarketingCampaign(Map<String, dynamic> data) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_marketing_campaigns').insert({
      ...data,
      'id': id,
      'tenant_id': tid,
      'status': data['status'] ?? 'draft',
    });
    return id;
  }

  Future<List<BosPlan>> listPlans() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_plans')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return (res as List).map((r) => BosPlan.fromMap(SupabaseRepositoryBase.rowToMap(r))).toList();
  }

  Future<BosSubscription?> getSubscription(String tenantId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final res = await client
        .from('bos_subscriptions')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res == null ? null : BosSubscription.fromMap(SupabaseRepositoryBase.rowToMap(res));
  }

  Future<List<Map<String, dynamic>>> listInvoices(String tenantId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_invoices')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<List<BosMarketplaceItem>> listMarketplaceItems() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_marketplace_items')
        .select()
        .eq('is_active', true);
    return (res as List)
        .map((r) => BosMarketplaceItem.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listInstalls(String tenantId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_marketplace_installs')
        .select('*, bos_marketplace_items(*)')
        .eq('tenant_id', tenantId);
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<void> installMarketplaceItem(String tenantId, String itemId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_marketplace_installs').upsert({
      'id': _uuid.v4(),
      'tenant_id': tenantId,
      'item_id': itemId,
      'installed_at': DateTime.now().toIso8601String(),
    });
  }

  static const defaultTenantId = kBosDefaultTenantId;

  String get aiQualifyLeadUrl => SupabaseConfig.functionUrl('bos-ai-qualify');
  String get whatsappReplyUrl => SupabaseConfig.functionUrl('bos-ai-reply');
  String get chatIngestUrl => SupabaseConfig.functionUrl('bos-chat-ingest');
  String get campaignRunUrl => SupabaseConfig.functionUrl('bos-campaign-run');
  String get campaignAiCopyUrl => SupabaseConfig.functionUrl('bos-campaign-ai-copy');
  String get kbReindexUrl => SupabaseConfig.functionUrl('bos-kb-reindex');
  String get whatsappWebhookUrl => SupabaseConfig.functionUrl('bos-whatsapp-webhook');

  Future<List<BosWaTemplate>> listWaTemplates() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_wa_templates')
        .select()
        .eq('tenant_id', tid)
        .isFilter('deleted_at', null)
        .order('name');
    return (res as List)
        .map((r) => BosWaTemplate.fromMap(SupabaseRepositoryBase.rowToMap(r)))
        .toList();
  }

  Future<String> createWaTemplate({
    required String name,
    required String body,
    String channel = 'whatsapp',
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) throw Exception('Not authenticated');
    final tid = await activeTenantId;
    final id = _uuid.v4();
    await client.from('bos_wa_templates').insert({
      'id': id,
      'tenant_id': tid,
      'name': name,
      'body': body,
      'channel': channel,
    });
    return id;
  }

  Future<int> addCampaignRecipientsFromSegment({
    required String campaignId,
    required String segmentPreset,
    required String channel,
  }) async {
    final leads = await listLeads();
    final filtered = leads.where((l) {
      if (l.stage == 'lost') return false;
      switch (segmentPreset) {
        case 'hot':
          return l.score == 'hot';
        case 'warm':
          return l.score == 'warm';
        case 'cold':
          return l.score == 'cold';
        case 'converted':
          return l.stage == 'won';
        case 'new_leads':
          return l.stage == 'new' || l.stage == 'contacted';
        default:
          return true;
      }
    }).toList();

    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return 0;
    final tid = await activeTenantId;
    var imported = 0;
    for (final l in filtered) {
      if (channel == 'email' && (l.email == null || l.email!.isEmpty)) continue;
      if ((channel == 'whatsapp' || channel == 'sms') &&
          (l.phone == null || l.phone!.isEmpty)) {
        continue;
      }
      await client.from('bos_campaign_recipients').insert({
        'id': _uuid.v4(),
        'tenant_id': tid,
        'campaign_id': campaignId,
        'phone': l.phone,
        'email': l.email,
        'full_name': l.fullName,
        'lead_id': l.id,
        'status': 'pending',
      });
      imported++;
    }
    return imported;
  }

  Future<Map<String, dynamic>> generateCampaignCopy({
    required String brief,
    required String channel,
    String? name,
    String tone = 'friendly',
  }) async {
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(campaignAiCopyUrl),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'tenant_id': tid,
        'brief': brief,
        'channel': channel,
        'name': name,
        'tone': tone,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  /// Public web/app chat (anon + Edge).
  Future<Map<String, dynamic>> ingestChatMessage({
    required String message,
    String channel = 'web',
    String? visitorId,
    String? name,
    String? phone,
    String? email,
    String? tenantId,
  }) async {
    final tid = tenantId ?? defaultTenantId;
    final res = await http.post(
      Uri.parse(chatIngestUrl),
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'tenant_id': tid,
        'channel': channel,
        'message': message,
        if (visitorId != null) 'visitor_id': visitorId,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(body['error'] ?? res.body);
    return Map<String, dynamic>.from(body as Map);
  }

  Future<List<Map<String, dynamic>>> listOptOuts() async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final tid = await activeTenantId;
    final res = await client
        .from('bos_opt_outs')
        .select()
        .eq('tenant_id', tid)
        .order('created_at', ascending: false);
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<void> addOptOut(
    String phone, {
    String reason = 'manual',
    String channel = 'voice',
  }) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    final tid = await activeTenantId;
    await client.from('bos_opt_outs').upsert({
      'tenant_id': tid,
      'phone': phone.trim(),
      'channel': channel,
      'reason': reason,
    });
    await writeAuditLog(
      action: 'opt_out.add',
      entityType: 'bos_opt_outs',
      meta: {'phone': phone.trim(), 'channel': channel, 'reason': reason},
    );
  }

  Future<void> removeOptOut(String id) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_opt_outs').delete().eq('id', id);
    await writeAuditLog(
      action: 'opt_out.remove',
      entityType: 'bos_opt_outs',
      entityId: id,
    );
  }

  Future<List<Map<String, dynamic>>> listCampaignRecipients(String campaignId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_campaign_recipients')
        .select()
        .eq('campaign_id', campaignId)
        .order('created_at');
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }

  Future<void> updateCampaign(String campaignId, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_campaigns').update(updates).eq('id', campaignId);
  }

  Future<Map<String, dynamic>> runCampaign(String campaignId) async {
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(campaignRunUrl),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'campaign_id': campaignId, 'tenant_id': tid}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body['error'] ?? res.body);
    }
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> aiReplyConversation(String conversationId) async {
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(whatsappReplyUrl),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'conversation_id': conversationId, 'tenant_id': tid}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body['error'] ?? res.body);
    }
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> ingestTestWhatsapp({
    required String phone,
    required String body,
  }) async {
    final tid = await activeTenantId;
    final res = await http.post(
      Uri.parse(whatsappWebhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tenant_id': tid,
        'test_phone': phone,
        'test_body': body,
      }),
    );
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<void> updateKbDocument(String docId, Map<String, dynamic> updates) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_kb_documents').update(updates).eq('id', docId);
  }

  Future<void> softDeleteKbDocument(String docId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;
    await client.from('bos_kb_documents').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', docId);
  }

  Future<Map<String, dynamic>> reindexKb({String? documentId, bool all = false}) async {
    final tid = await activeTenantId;
    final token = SupabaseAuthService.instance.accessToken;
    final res = await http.post(
      Uri.parse(kbReindexUrl),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tenant_id': tid,
        if (documentId != null) 'document_id': documentId,
        'reindex_all': all,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body['error'] ?? res.body);
    }
    return Map<String, dynamic>.from(body as Map);
  }

  Future<List<Map<String, dynamic>>> listKbChunks(String documentId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final res = await client
        .from('bos_kb_chunks')
        .select()
        .eq('document_id', documentId)
        .order('chunk_index');
    return (res as List).map((r) => SupabaseRepositoryBase.rowToMap(r)).toList();
  }
}

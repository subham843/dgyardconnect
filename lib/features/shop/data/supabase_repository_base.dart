import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

/// Base helpers for Supabase-backed shop/calculator repositories.
abstract class SupabaseRepositoryBase {
  static bool get isAvailable => SupabaseBootstrap.isInitialized;

  static SupabaseClient? get client => SupabaseBootstrap.clientOrNull;

  static Future<SupabaseClient?>? _clientWithAuthInFlight;

  /// Deduplicates concurrent auth sync (dashboard fires many parallel queries).
  static Future<SupabaseClient?> clientWithAuth() async {
    if (!isAvailable) return null;
    final pending = _clientWithAuthInFlight;
    if (pending != null) return pending;
    final future = _syncAndGetClient();
    _clientWithAuthInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_clientWithAuthInFlight, future)) {
        _clientWithAuthInFlight = null;
      }
    }
  }

  static Future<SupabaseClient?> _syncAndGetClient() async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    return client;
  }

  /// Call before shop catalog writes (RLS requires JWT app_role superadmin).
  static Future<void> ensureSuperadminWrite() async {
    await SupabaseAuthService.instance.ensureSuperadminWriteAccess();
  }

  static Map<String, dynamic> rowToMap(Map<String, dynamic> row) => Map<String, dynamic>.from(row);

  /// PostgREST embed: one-to-one returns a Map, one-to-many returns a List.
  static List<Map<String, dynamic>> embeddedRows(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => rowToMap(Map<String, dynamic>.from(e as Map))).toList();
    }
    if (value is Map) {
      return [rowToMap(Map<String, dynamic>.from(value))];
    }
    return [];
  }

  static String slugify(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

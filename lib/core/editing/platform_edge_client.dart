import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../supabase/supabase_auth_service.dart';
import '../supabase/supabase_bootstrap.dart';
import '../supabase/supabase_config.dart';

/// Invokes Supabase Edge Functions with Firebase-exchanged JWT (superadmin).
abstract final class PlatformEdgeClient {
  static Future<Map<String, dynamic>?> post(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    if (!SupabaseConfig.isConfigured) return null;
    final synced = await SupabaseAuthService.instance.syncSessionFromFirebase(roleMirror: 'superadmin');
    if (!synced) {
      debugPrint('PlatformEdgeClient: no Supabase session');
      return null;
    }
    final token = SupabaseAuthService.instance.accessToken ??
        SupabaseBootstrap.clientOrNull?.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;

    final url = SupabaseConfig.functionUrl(functionName);
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode(body),
      );
      if (res.statusCode >= 400) {
        debugPrint('PlatformEdgeClient $functionName: ${res.statusCode} ${res.body}');
        return jsonDecode(res.body) as Map<String, dynamic>? ?? {'error': res.body};
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('PlatformEdgeClient $functionName: $e');
      return null;
    }
  }
}

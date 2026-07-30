import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_config.dart';

/// Direct PostgREST reads with the anon key only (no user JWT).
abstract final class PublicRestClient {
  static Map<String, String> get _headers => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
      };

  static Future<List<Map<String, dynamic>>> select(
    String tableOrView, {
    String columns = '*',
    String? order,
    int? limit,
    Map<String, String>? eq,
    String? inFilter,
  }) async {
    final params = <String>['select=$columns'];
    if (order != null && order.isNotEmpty) params.add('order=$order');
    if (limit != null) params.add('limit=$limit');
    if (inFilter != null && inFilter.isNotEmpty) params.add(inFilter);
    eq?.forEach((col, val) {
      params.add('$col=eq.$val');
    });
    final uri = Uri.parse(
      '${SupabaseConfig.url}/rest/v1/$tableOrView?${params.join('&')}',
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Public REST $tableOrView failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }
}

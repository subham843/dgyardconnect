import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Initializes Supabase when configured. Safe to call when URL/key are empty.
abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> ensureInitialized() => init();

  static Future<void> init() async {
    if (_initialized) return;
    if (!SupabaseConfig.isConfigured) {
      debugPrint('Supabase: not configured (SUPABASE_URL / SUPABASE_ANON_KEY)');
      return;
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _initialized = true;
      debugPrint('Supabase: initialized');
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }
}

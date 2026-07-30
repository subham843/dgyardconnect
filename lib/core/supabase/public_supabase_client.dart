import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Anonymous Supabase client for public storefront reads.
///
/// Session persistence is disabled so it never picks up the admin/user JWT
/// from [Supabase.initialize].
abstract final class PublicSupabaseClient {
  static SupabaseClient? _client;

  static SupabaseClient get instance {
    _client ??= SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return _client!;
  }
}

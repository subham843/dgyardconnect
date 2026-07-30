/// Supabase configuration (permanent project defaults + optional --dart-define override).
abstract final class SupabaseConfig {
  /// Default project URL (used when SUPABASE_URL is not passed via --dart-define).
  static const String _defaultUrl = 'https://xtnfmrourhzspehvhrkz.supabase.co';

  /// Default anon / publishable key from Supabase Dashboard → Settings → API.
  static const String _defaultAnonKey = 'sb_publishable_a4RQmOWKCKXJNIBnyaquDw_l46BoO5B';

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _envFunctionsUrl = String.fromEnvironment('SUPABASE_FUNCTIONS_URL');

  static String get url => _envUrl.isNotEmpty ? _envUrl : _defaultUrl;

  static String get anonKey => _envAnonKey.isNotEmpty ? _envAnonKey : _defaultAnonKey;

  static String get functionsUrl => _envFunctionsUrl;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static String get exchangeTokenUrl => functionUrl('exchange-firebase-token');

  static String functionUrl(String name) {
    if (functionsUrl.isNotEmpty) {
      return '$functionsUrl/$name';
    }
    return '$url/functions/v1/$name';
  }
}

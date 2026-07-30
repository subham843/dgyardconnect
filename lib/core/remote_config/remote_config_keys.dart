/// Central place for Firebase Remote Config keys used by the app.
///
/// Keep keys stable to avoid breaking older app versions.
class RemoteConfigKeys {
  RemoteConfigKeys._();

  /// UI / theme
  static const String uiPrimaryColorHex = 'ui_primary_color_hex'; // e.g. "#1E88E5"

  /// App texts and banners (JSON map)
  /// Example: {"home_banner":"Big offer","home_heading":"Welcome"}
  static const String appTextsJson = 'app_texts_json';

  /// Feature flags (JSON map of bools)
  /// Example: {"enableChat":true,"enableAds":false,"marketplace_enabled":true}
  static const String featureFlagsJson = 'feature_flags_json';

  /// Update management
  static const String latestVersion = 'app_latest_version'; // e.g. "1.2.3"
  static const String minSupportedVersion = 'app_min_supported_version'; // e.g. "1.1.0"
  static const String updateSource = 'app_update_source'; // "apk" | "playstore"
  static const String updateTitle = 'app_update_title'; // e.g. "Update available"
  static const String updateMessage = 'app_update_message'; // short message (optional)
  static const String updateChangelog = 'app_update_changelog'; // multi-line supported
  static const String updateUrl = 'app_update_url'; // Play Store link or landing page
  static const String apkUrl = 'app_update_apk_url'; // direct APK link (required for apk source)
  static const String updateReleaseId = 'app_update_release_id'; // changes every publish
}


import 'package:firebase_analytics/firebase_analytics.dart';

/// Minimal analytics wrapper so we can safely call from UI.
/// No-op if Firebase isn't configured (FirebaseAnalytics will throw only if core not inited).
abstract final class AnalyticsService {
  static FirebaseAnalytics? _analytics;

  static FirebaseAnalytics get instance =>
      _analytics ??= FirebaseAnalytics.instance;

  static Future<void> logEvent(
    String name, {
    Map<String, Object?>? params,
  }) async {
    try {
      await instance.logEvent(
        name: name,
        parameters: params?.cast<String, Object>(),
      );
    } catch (_) {}
  }

  static Future<void> logScreen(String screenName) async {
    try {
      await instance.logScreenView(screenName: screenName);
    } catch (_) {}
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';

/// Web stub — FCM is mobile-only; keeps [main.dart] out of the FCM dependency graph.
abstract final class FcmService {
  static Future<bool> isDeepLinkLockActive() async => false;

  static void navigateFromInitialMessage(RemoteMessage message) {}

  static void navigateFromLaunchPayload(String payload) {}
}

import 'package:firebase_messaging/firebase_messaging.dart';

/// No-op on web — maps, ads, and FCM are mobile-only.
Future<void> initMobilePlatformServices() async {}

Future<void> handleLaunchFromNotification() async {}

RemoteMessage? pendingFcmMessage;
String? pendingFcmPayload;

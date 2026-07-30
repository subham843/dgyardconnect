import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'shared/services/fcm_service.dart';

Future<void> initMobilePlatformServices() async {
  await FcmService.init();
  await handleLaunchFromNotification();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('AdMob init: $e');
  }
  try {
    final mapsImpl = GoogleMapsFlutterPlatform.instance;
    if (mapsImpl is GoogleMapsFlutterAndroid) {
      await mapsImpl.initializeWithRenderer(AndroidMapRenderer.latest);
    }
  } catch (e) {
    debugPrint('Google Maps init: $e');
  }
}

Future<void> handleLaunchFromNotification() async {
  final fcmMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (fcmMessage != null) {
    // Navigation is scheduled from main() after runApp.
    pendingFcmMessage = fcmMessage;
  }
  final localLaunch = await FcmService.getNotificationLaunchPayload();
  if (localLaunch != null && localLaunch.isNotEmpty) {
    await FcmService.cancelJobNotification();
    pendingFcmPayload = localLaunch;
  }
}

RemoteMessage? pendingFcmMessage;
String? pendingFcmPayload;

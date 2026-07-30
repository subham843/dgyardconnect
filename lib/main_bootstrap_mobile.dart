import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'app.dart';
import 'core/bootstrap/firebase_bootstrap.dart';
import 'core/fonts/font_config_export.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'platform_init_mobile.dart' as platform;
import 'shared/services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureAppFonts();
  try {
    await FirebaseBootstrap.ensureInitialized();
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    await platform.initMobilePlatformServices();
  } catch (e) {
    debugPrint('Firebase not configured: $e — Run: flutterfire configure');
  }
  await SupabaseBootstrap.init();
  runApp(const App());
  _schedulePendingNotificationNavigation();
}

void _schedulePendingNotificationNavigation() {
  final fcmMessage = platform.pendingFcmMessage;
  final payload = platform.pendingFcmPayload;
  if (fcmMessage == null && (payload == null || payload.isEmpty)) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (fcmMessage != null) {
      FcmService.navigateFromInitialMessage(fcmMessage);
    } else if (payload != null && payload.isNotEmpty) {
      FcmService.navigateFromLaunchPayload(payload);
    }
  });
}

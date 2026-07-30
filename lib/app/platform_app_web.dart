import 'package:flutter/material.dart';

import '../core/remote_config/app_remote_config_controller_export.dart';
import '../shared/router/web_router_app.dart';

export 'web_material_app.dart' show buildWebMaterialApp;

/// Web shell — GoRouter home route loads immediately (no cold-start placeholder).
Widget buildPlatformApp({
  AppRemoteConfigController? remoteConfigController,
}) {
  return const WebRouterApp();
}

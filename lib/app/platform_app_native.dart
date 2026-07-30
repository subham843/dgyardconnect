import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/remote_config/app_remote_config_controller_export.dart';
import '../core/theme/app_theme_export.dart';
import '../core/update/update_gate_export.dart';
import '../shared/models/brand_kit_model.dart';
import '../shared/router/app_router.dart';
import '../shared/services/brand_kit_service.dart';
import '../shared/utils/brand_kit_web_utils.dart';
import '../shared/widgets/brand_kit_provider.dart';

/// Native shell — live Brand Kit stream + update gate.
Widget buildPlatformApp({
  AppRemoteConfigController? remoteConfigController,
}) {
  assert(remoteConfigController != null, 'remoteConfigController required on native');
  final rcController = remoteConfigController!;
  return StreamBuilder<BrandKitModel>(
    stream: BrandKitService.stream(),
    initialData: BrandKitService.instance.current ?? const BrandKitModel(),
    builder: (context, snapshot) {
      final baseKit = snapshot.data ?? const BrandKitModel();
      final rc = context.watch<AppRemoteConfigController>().config;

      final kit = (rc.primaryColorHex == null || rc.primaryColorHex!.isEmpty)
          ? baseKit
          : baseKit.copyWith(primaryColorHex: rc.primaryColorHex);

      updateFaviconAndIcons(kit);

      return BrandKitProvider(
        kit: kit,
        child: MaterialApp.router(
          title: kit.appName ?? AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(kit),
          routerConfig: appRouter,
          builder: (context, child) {
            final safe = SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: child ?? const SizedBox.shrink(),
            );
            return UpdateGate(
              controller: rcController,
              child: safe,
            );
          },
        ),
      );
    },
  );
}

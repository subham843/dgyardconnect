import 'package:firebase_auth/firebase_auth.dart';

import 'core/remote_config/app_remote_config_controller_export.dart';
import 'features/marketplace/state/marketplace_cart_controller.dart';
import 'features/shop/state/shop_cart_controller_export.dart';
import 'platform/data/platform_user_repository.dart';
import 'shared/services/brand_kit_service.dart';

abstract final class AppNativeBindings {
  static void init({
    required AppRemoteConfigController remoteConfigController,
    required ShopCartController shopCartController,
    required MarketplaceCartController? marketplaceCartController,
  }) {
    BrandKitService.instance.init();
    remoteConfigController.initAndFetch();
    marketplaceCartController?.attachToAuth();
    shopCartController.attachToAuth();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        PlatformUserRepository.instance.ensureProvisioned(
          firebaseUid: user.uid,
        );
      }
    });
  }
}

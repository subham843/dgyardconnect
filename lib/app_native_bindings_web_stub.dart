import 'core/remote_config/app_remote_config_controller_export.dart';
import 'features/marketplace/state/marketplace_cart_controller_export.dart';
import 'features/shop/state/shop_cart_controller_export.dart';

/// No-op on web — keeps Firebase Auth / Firestore provisioning out of main bundle.
abstract final class AppNativeBindings {
  static void init({
    required AppRemoteConfigController remoteConfigController,
    required ShopCartController shopCartController,
    required MarketplaceCartController? marketplaceCartController,
  }) {}
}

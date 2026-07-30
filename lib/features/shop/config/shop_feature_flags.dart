import 'package:flutter/foundation.dart';

import '../../../core/remote_config/app_remote_config.dart';

/// Remote Config keys for Supabase Shop module.
class ShopFeatureFlags {
  ShopFeatureFlags._();

  static const String rcKeyShopEnabled = 'supabase_shop_enabled';
  static const String rcKeyHideMarketplaceBuyer = 'hide_marketplace_buyer';

  /// Production default off; debug can enable for development.
  static bool isSupabaseShopEnabled(AppRemoteConfig config) {
    return config.isFeatureEnabled(
      rcKeyShopEnabled,
      defaultValue: kDebugMode,
    );
  }

  static bool hideMarketplaceBuyer(AppRemoteConfig config) {
    return config.isFeatureEnabled(
      rcKeyHideMarketplaceBuyer,
      defaultValue: false,
    );
  }
}

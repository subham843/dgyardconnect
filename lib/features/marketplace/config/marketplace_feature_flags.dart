import 'package:flutter/foundation.dart';

import '../../../core/remote_config/app_remote_config.dart';

/// Remote Config key: set inside [RemoteConfigKeys.featureFlagsJson], e.g. `{"marketplace_enabled":true}`.
class MarketplaceFeatureFlags {
  MarketplaceFeatureFlags._();

  static const String rcKeyEnabled = 'marketplace_enabled';

  /// Production default off; debug default on so the module is visible without RC setup.
  static bool isMarketplaceEnabled(AppRemoteConfig config) {
    return config.isFeatureEnabled(
      rcKeyEnabled,
      defaultValue: kDebugMode,
    );
  }
}

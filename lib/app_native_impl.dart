import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/platform_app_export.dart' as platform_app;
import 'app_native_bindings.dart';
import 'core/remote_config/app_remote_config_controller_export.dart';
import 'features/marketplace/state/marketplace_cart_controller_export.dart';
import 'features/shop/state/shop_cart_controller_export.dart';

/// Native/mobile [App] with Provider tree and cart controllers.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  AppRemoteConfigController? _remoteConfigController;
  MarketplaceCartController? _marketplaceCartController;
  ShopCartController? _shopCartController;

  @override
  void initState() {
    super.initState();
    _remoteConfigController = AppRemoteConfigController();
    _shopCartController = ShopCartController();
    _marketplaceCartController = MarketplaceCartController();
    AppNativeBindings.init(
      remoteConfigController: _remoteConfigController!,
      shopCartController: _shopCartController!,
      marketplaceCartController: _marketplaceCartController,
    );
  }

  @override
  void dispose() {
    _shopCartController?.dispose();
    _marketplaceCartController?.dispose();
    _remoteConfigController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _remoteConfigController),
        if (_marketplaceCartController != null)
          ChangeNotifierProvider.value(value: _marketplaceCartController!),
        ChangeNotifierProvider.value(value: _shopCartController),
      ],
      child: platform_app.buildPlatformApp(
        remoteConfigController: _remoteConfigController!,
      ),
    );
  }
}

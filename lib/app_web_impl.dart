import 'package:flutter/material.dart';

import 'app/platform_app_export.dart' as platform_app;

/// Web [App] — no Provider, carts, or remote config at startup.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => platform_app.buildPlatformApp();
}

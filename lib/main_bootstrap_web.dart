import 'package:flutter/material.dart';

import 'app.dart';
import 'core/fonts/font_config_export.dart';

/// Web cold-start — no Firebase, Supabase, or FCM on the critical path.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppFonts();
  runApp(const App());
}

import 'package:flutter/material.dart';

import '../core/bootstrap/web_post_paint.dart';
import '../shared/router/web_router_shell_bundle.dart' deferred as web_router_shell;

/// Minimal MaterialApp until the GoRouter shell chunk loads.
class WebColdStartApp extends StatefulWidget {
  const WebColdStartApp({super.key});

  @override
  State<WebColdStartApp> createState() => _WebColdStartAppState();
}

class _WebColdStartAppState extends State<WebColdStartApp> {
  Widget? _shell;

  @override
  void initState() {
    super.initState();
    scheduleAfterFirstFrame(_loadShell);
  }

  Future<void> _loadShell() async {
    try {
      await web_router_shell.loadLibrary();
      if (mounted) setState(() => _shell = web_router_shell.buildWebRouterShell());
    } catch (e, st) {
      debugPrint('WebColdStartApp: router shell failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = _shell;
    if (shell != null) return shell;
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF070A12),
        body: SizedBox.expand(),
      ),
    );
  }
}

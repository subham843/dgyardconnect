import 'package:flutter/material.dart';

import '../remote_config/app_remote_config_controller_export.dart';

/// Web stub — force-update gate is mobile-only.
class UpdateGate extends StatelessWidget {
  const UpdateGate({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final AppRemoteConfigController controller;

  @override
  Widget build(BuildContext context) => child;
}

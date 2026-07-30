import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AdminMarketplaceDispatchScreen extends StatelessWidget {
  const AdminMarketplaceDispatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Carrier labels, AWB capture, buyer tracking timeline. Events should feed notifications with `mp_` FCM types.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
        ),
      ),
    );
  }
}

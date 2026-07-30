import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AdminMarketplaceQcScreen extends StatelessWidget {
  const AdminMarketplaceQcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QC desk')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Category checklists, photo evidence, pass/fail with quarantine paths. Only QC-pass items advance to repack and D.G.Yard invoicing.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.45),
        ),
      ),
    );
  }
}

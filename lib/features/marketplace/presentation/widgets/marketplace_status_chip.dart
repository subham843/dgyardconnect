import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MarketplaceStatusChip extends StatelessWidget {
  const MarketplaceStatusChip({
    super.key,
    required this.label,
    this.tone = MarketplaceChipTone.neutral,
  });

  final String label;
  final MarketplaceChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      MarketplaceChipTone.success => (AppColors.success.withValues(alpha: 0.12), AppColors.success),
      MarketplaceChipTone.warning => (AppColors.warning.withValues(alpha: 0.18), const Color(0xFFB45309)),
      MarketplaceChipTone.error => (AppColors.error.withValues(alpha: 0.12), AppColors.error),
      MarketplaceChipTone.neutral => (AppColors.surfaceVariant, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

enum MarketplaceChipTone { neutral, success, warning, error }

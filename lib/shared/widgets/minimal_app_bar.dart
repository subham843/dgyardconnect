import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// App bar matching home screen sticky bar: gradient, glow, white text & icons.
class MinimalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MinimalAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.light = false,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool light;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 44);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final iconTextColor = light ? AppColors.textPrimary : Colors.white;
    final bottomBorderColor = light ? Colors.black.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.18);
    final shadowPrimary = light
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.35);
    final shadowSecondary = light
        ? AppColors.secondary.withValues(alpha: 0.10)
        : AppColors.secondary.withValues(alpha: 0.2);
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: shadowPrimary,
            blurRadius: light ? 24 : 28,
            spreadRadius: light ? -2 : -4,
          ),
          BoxShadow(
            color: shadowSecondary,
            blurRadius: light ? 34 : 40,
            spreadRadius: light ? -6 : -8,
          ),
          BoxShadow(
            color: light ? Colors.black.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.06),
            blurRadius: light ? 10 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: light
                ? [
                    AppColors.primary.withValues(alpha: 0.10),
                    AppColors.primaryLight.withValues(alpha: 0.08),
                    AppColors.secondary.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.95),
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.72),
                    AppColors.primaryLight.withValues(alpha: 0.65),
                    AppColors.secondary.withValues(alpha: 0.58),
                  ],
          ),
          border: Border(
            bottom: BorderSide(
              color: bottomBorderColor,
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (leading != null)
                IconTheme.merge(
                  data: IconThemeData(color: iconTextColor),
                  child: leading!,
                ),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: iconTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              if (actions != null && actions!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!
                      .map((a) => IconTheme.merge(
                            data: IconThemeData(color: iconTextColor),
                            child: a,
                          ))
                      .toList(),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/technician_ui_tokens.dart';

class TechnicianAvailabilityFab extends StatelessWidget {
  const TechnicianAvailabilityFab({
    super.key,
    required this.availabilityStatus,
    required this.isOnline,
    required this.onPressed,
  });

  final String availabilityStatus;
  final bool isOnline;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final status = availabilityStatus.trim().isEmpty ? 'offline' : availabilityStatus.trim();
    final accent = _statusAccent(status);
    final icon = status.toLowerCase() == 'busy'
        ? Icons.pause_rounded
        : (status.toLowerCase() == 'online' || isOnline)
            ? Icons.bolt_rounded
            : Icons.power_settings_new_rounded;

    return Tooltip(
      message: 'Start Job',
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.26),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            ...TechnicianUiTokens.shadowCard,
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent,
                        TechnicianUiTokens.accent,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _statusAccent(String status) {
  final s = status.toLowerCase();
  if (s == 'online') return TechnicianUiTokens.success;
  if (s == 'busy') return TechnicianUiTokens.warning;
  return TechnicianUiTokens.labelTertiary;
}

class TechnicianShellBottomNav extends StatelessWidget {
  const TechnicianShellBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    this.navKeys,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final Map<String, GlobalKey>? navKeys;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TechnicianUiTokens.rXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(TechnicianUiTokens.rXl),
                border: Border.all(color: TechnicianUiTokens.hairlineOnGlass),
                boxShadow: TechnicianUiTokens.shadowFloat,
              ),
              child: Row(
                children: [
                  _NavItem(
                    itemKey: navKeys?['nav_home'],
                    label: 'Home',
                    icon: Icons.grid_view_rounded,
                    selected: index == 0,
                    onTap: () => onChanged(0),
                  ),
                  _NavItem(
                    itemKey: navKeys?['nav_jobs'],
                    label: 'Jobs',
                    icon: Icons.work_outline_rounded,
                    selected: index == 1,
                    onTap: () => onChanged(1),
                  ),
                  const SizedBox(width: 56),
                  _NavItem(
                    itemKey: navKeys?['nav_earnings'],
                    label: 'Earnings',
                    icon: Icons.account_balance_wallet_outlined,
                    selected: index == 2,
                    onTap: () => onChanged(2),
                  ),
                  _NavItem(
                    itemKey: navKeys?['nav_profile'],
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    selected: index == 3,
                    onTap: () => onChanged(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.itemKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Key? itemKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: itemKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
          child: AnimatedContainer(
            duration: TechnicianUiTokens.motionFast,
            curve: TechnicianUiTokens.motionCurve,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
              color: Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 3,
                  child: Center(
                    child: AnimatedContainer(
                      duration: TechnicianUiTokens.motionFast,
                      curve: TechnicianUiTokens.motionCurve,
                      width: selected ? 20 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            AppColors.brandWarmLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: TechnicianUiTokens.motionFast,
                        curve: TechnicianUiTokens.motionCurve,
                        opacity: selected ? 1 : 0,
                        child: IgnorePointer(
                          child: Container(
                            width: 52,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.82),
                                  AppColors.brandWarmLight.withValues(alpha: 0.22),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        icon,
                        color: selected
                            ? AppColors.brandWarmLight
                            : TechnicianUiTokens.labelSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TechnicianUiTokens.textCaption2(
                    color: selected
                        ? AppColors.brandWarmLight
                        : TechnicianUiTokens.labelSecondary,
                  ).copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

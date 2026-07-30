import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/technician_ui_tokens.dart';
import '../../../shared/services/firestore_service.dart';

Future<void> showTechnicianAvailabilitySheet(
  BuildContext context,
  String uid, {
  required String current,
  required bool isOnline,
}) async {
  final currentKey = current.trim().isEmpty ? 'offline' : current.trim();

  Future<void> setStatus(String next) async {
    try {
      final online = next == 'online';
      await FirestoreService.users().doc(uid).update({
        'availabilityStatus': next,
        'online': online,
      });
    } catch (_) {}
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(TechnicianUiTokens.rXl)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TechnicianUiTokens.rXl),
              ),
              border: Border.all(color: TechnicianUiTokens.separator),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TechnicianUiTokens.labelTertiary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(TechnicianUiTokens.rPill),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Availability',
                        style: TechnicianUiTokens.textTitle2(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusAccent(currentKey).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(TechnicianUiTokens.rPill),
                          border: Border.all(color: TechnicianUiTokens.separator),
                        ),
                        child: Text(
                          _statusLabel(currentKey, isOnline: isOnline),
                          style: TechnicianUiTokens.textCaption1(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _AvailabilityTile(
                    title: 'Online',
                    subtitle: 'Get job requests and accept jobs',
                    icon: Icons.wifi_tethering_rounded,
                    accent: TechnicianUiTokens.success,
                    selected: currentKey == 'online',
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await setStatus('online');
                    },
                  ),
                  const SizedBox(height: 10),
                  _AvailabilityTile(
                    title: 'Pause',
                    subtitle: 'Temporarily stop job requests',
                    icon: Icons.pause_circle_filled_rounded,
                    accent: TechnicianUiTokens.warning,
                    selected: currentKey == 'busy',
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await setStatus('busy');
                    },
                  ),
                  const SizedBox(height: 10),
                  _AvailabilityTile(
                    title: 'Offline',
                    subtitle: 'Not available for work',
                    icon: Icons.power_settings_new_rounded,
                    accent: TechnicianUiTokens.labelTertiary,
                    selected: currentKey == 'offline',
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await setStatus('offline');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _statusLabel(String status, {required bool isOnline}) {
  final s = status.toLowerCase();
  if (s == 'busy') return 'Paused';
  if (s == 'online' || isOnline) return 'Online';
  return 'Offline';
}

Color _statusAccent(String status) {
  final s = status.toLowerCase();
  if (s == 'online') return TechnicianUiTokens.success;
  if (s == 'busy') return TechnicianUiTokens.warning;
  return TechnicianUiTokens.labelTertiary;
}

class _AvailabilityTile extends StatelessWidget {
  const _AvailabilityTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
        child: AnimatedContainer(
          duration: TechnicianUiTokens.motionFast,
          curve: TechnicianUiTokens.motionCurve,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TechnicianUiTokens.rMd),
            color: Colors.white.withValues(alpha: 0.65),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.45) : TechnicianUiTokens.separator,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? TechnicianUiTokens.shadowCard : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TechnicianUiTokens.rSm + 2),
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: TechnicianUiTokens.labelPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TechnicianUiTokens.textSubhead(),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent, size: 22)
              else
                Icon(Icons.chevron_right_rounded,
                    color: TechnicianUiTokens.labelTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_light_theme.dart';

const Color _kIconMuted = Color(0xFF64748B);
const double _kGlassRadius = 18;

class SupportHomeScreen extends StatelessWidget {
  const SupportHomeScreen({super.key, this.role});

  final String? role;
  static const _supportEmail = 'support@dgyard.com';

  @override
  Widget build(BuildContext context) {
    final home = Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _SupportGradientBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                        color: const Color(0xFF1E293B),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(RouteNames.publicHome);
                          }
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Help & Support',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _PressableSupportTile(
                        primary: false,
                        icon: Icons.quiz_rounded,
                        title: 'FAQ',
                        subtitle: 'Common questions and answers',
                        onTap: () => context.push(
                          role != null && role!.isNotEmpty
                              ? RouteNames.supportFaqForRole(role!)
                              : RouteNames.supportFaq,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PressableSupportTile(
                        primary: true,
                        icon: Icons.support_agent_rounded,
                        title: 'Create a ticket',
                        subtitle: 'Get help from our team',
                        onTap: () =>
                            context.push(RouteNames.supportCreateTicket),
                      ),
                      const SizedBox(height: 14),
                      _PressableSupportTile(
                        primary: false,
                        icon: Icons.confirmation_number_rounded,
                        title: 'My tickets',
                        subtitle: 'Track your support requests',
                        onTap: () => context.push(RouteNames.supportTickets),
                      ),
                      const SizedBox(height: 14),
                      _EmailSupportTile(
                        email: _supportEmail,
                        onTapMail: () async {
                          final uri = Uri(
                            scheme: 'mailto',
                            path: _supportEmail,
                            queryParameters: {'subject': 'Support request'},
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mail app not available on this device.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        onLongPressCopy: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: _supportEmail),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email copied to clipboard'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (role == 'technician') {
      return TechnicianLightScope(child: home);
    }
    return home;
  }
}

class _SupportGradientBackground extends StatelessWidget {
  const _SupportGradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF1F5F9),
            const Color(0xFFE8EEF2),
            const Color(0xFFF5F3F0).withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandWarm.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kGlassRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.brandWarm.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kGlassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(_kGlassRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PressableSupportTile extends StatefulWidget {
  const _PressableSupportTile({
    required this.primary,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool primary;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_PressableSupportTile> createState() => _PressableSupportTileState();
}

class _PressableSupportTileState extends State<_PressableSupportTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.primary ? AppColors.brandWarm : _kIconMuted;
    final titleSize = widget.primary ? 17.0 : 16.0;
    final titleWeight = widget.primary ? FontWeight.w700 : FontWeight.w600;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: _GlassPanel(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(_kGlassRadius),
              splashColor: Colors.white.withValues(alpha: 0.22),
              highlightColor: Colors.white.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 24, color: accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: titleWeight,
                              color: widget.primary
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF1E293B),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(
                                0xFF334155,
                              ).withValues(alpha: 0.6),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: const Color(0xFF64748B).withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailSupportTile extends StatefulWidget {
  const _EmailSupportTile({
    required this.email,
    required this.onTapMail,
    required this.onLongPressCopy,
  });

  final String email;
  final Future<void> Function() onTapMail;
  final Future<void> Function() onLongPressCopy;

  @override
  State<_EmailSupportTile> createState() => _EmailSupportTileState();
}

class _EmailSupportTileState extends State<_EmailSupportTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: _GlassPanel(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onTapMail(),
              onLongPress: () => widget.onLongPressCopy(),
              borderRadius: BorderRadius.circular(_kGlassRadius),
              splashColor: Colors.white.withValues(alpha: 0.22),
              highlightColor: Colors.white.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 24,
                      color: _kIconMuted,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email support',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.email,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(
                                0xFF334155,
                              ).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: const Color(0xFF64748B).withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

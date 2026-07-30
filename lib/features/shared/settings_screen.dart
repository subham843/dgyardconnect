import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/route_names.dart';
import '../../core/remote_config/app_remote_config_controller_export.dart';
import '../../core/update/app_update_config.dart';
import '../../features/customer/account/customer_account_shell.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/walkthrough_service.dart';

const _kSettingsBg = Color(0xFFFFFBF5);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.embedInPublicShell = false});

  /// When true on web, renders inside [CustomerAccountShell] (navbar + bottom bar).
  final bool embedInPublicShell;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;
  bool _smsEnabled = true;
  bool _loading = true;
  bool _deletingAccount = false;
  bool _loggingOut = false;
  late final Future<PackageInfo> _pkgFuture;

  static const _keyPushEnabled = 'prefs_push_enabled';

  @override
  void initState() {
    super.initState();
    _pkgFuture = _safePackageInfo();
    _load();
  }

  Future<PackageInfo> _safePackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return PackageInfo(
        appName: '',
        packageName: '',
        version: '0.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: null,
      );
    }
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pushPref = prefs.getBool(_keyPushEnabled);
      var push = pushPref ?? true;
      var sms = true;
      if (uid != null && FirestoreService.isAvailable) {
        final doc = await FirestoreService.users().doc(uid).get();
        final np = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
        if (np != null) {
          if (np['pushEnabled'] is bool) push = np['pushEnabled'] as bool;
          if (np['smsEnabled'] is bool) sms = np['smsEnabled'] as bool;
        }
      }
      if (!mounted) return;
      setState(() {
        _pushEnabled = push;
        _smsEnabled = sms;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _persist({bool? pushEnabled, bool? smsEnabled}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final push = pushEnabled ?? _pushEnabled;
    final sms = smsEnabled ?? _smsEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPushEnabled, push);
    } catch (_) {}

    if (uid != null && FirestoreService.isAvailable) {
      try {
        await FirestoreService.users().doc(uid).set({
          'notificationPrefs': {
            'pushEnabled': push,
            'smsEnabled': sms,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be signed out of your account on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      context.go(AuthPostLogin.postLogoutRoute());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out right now. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (kIsWeb) {
      context.go(RouteNames.publicHome);
      return;
    }
    Navigator.maybePop(context);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and related data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingAccount = true);
    try {
      await AuthService().deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );
      context.go(AuthPostLogin.postLogoutRoute());
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'For security, please login again and retry account deletion.'
          : (e.message ?? 'Unable to delete account right now.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete account right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<String?> _resolveRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return null;
    try {
      final doc = await FirestoreService.users().doc(uid).get();
      return (doc.data()?['role'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _replayWalkthrough() async {
    final role = await _resolveRole();
    if (!mounted) return;
    if (role == 'dealer') {
      await WalkthroughService.resetRoleHomeGuide('dealer');
      if (!mounted) return;
      context.go(RouteNames.dealerHome);
      return;
    }
    if (role == 'technician') {
      await WalkthroughService.resetRoleHomeGuide('technician');
      if (!mounted) return;
      context.go(RouteNames.technicianHome);
      return;
    }
    await WalkthroughService.resetGeneral();
    if (!mounted) return;
    context.go(RouteNames.appWalkthrough);
  }

  AppUpdateConfig _updateConfig(BuildContext context) {
    try {
      return Provider.of<AppRemoteConfigController>(context, listen: true).updateConfig;
    } catch (_) {
      return const AppUpdateConfig(
        latestVersion: '',
        minSupportedVersion: '',
        source: AppUpdateSource.unknown,
        releaseId: '',
        title: '',
        message: '',
        changelog: '',
        updateUrl: '',
        apkUrl: '',
      );
    }
  }

  Widget _settingsList(AppUpdateConfig updateCfg) {
    return ListView(
      shrinkWrap: widget.embedInPublicShell,
      physics: widget.embedInPublicShell ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(color: AppColors.brandWarmSoft),
            ),
          const _SectionTitle('Notifications'),
          _GlassCard(
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.brandWarmSoft,
                  title: 'Push notifications',
                  subtitle: 'Job updates, approvals, and alerts',
                  value: _pushEnabled,
                  onChanged: (v) {
                    setState(() => _pushEnabled = v);
                    _persist(pushEnabled: v);
                  },
                ),
                const Divider(height: 1),
                _SwitchRow(
                  icon: Icons.sms_rounded,
                  iconColor: AppColors.brandWarmSoft,
                  title: 'SMS notifications',
                  subtitle: 'OTP and important updates',
                  value: _smsEnabled,
                  onChanged: (v) {
                    setState(() => _smsEnabled = v);
                    _persist(smsEnabled: v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Preferences'),
          _GlassCard(
            child: Column(
              children: const [
                _ActionRow(
                  icon: Icons.language_rounded,
                  iconColor: Color(0xFFD97706),
                  title: 'Language',
                  subtitle: 'Hindi / English',
                ),
                Divider(height: 1),
                _ActionRow(
                  icon: Icons.slideshow_rounded,
                  iconColor: Color(0xFFD97706),
                  title: 'Replay home guide',
                  subtitle: 'See guided home hints again',
                  actionKey: 'replay',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Privacy & Security'),
          _GlassCard(
            child: Column(
              children: const [
                _ActionRow(
                  icon: Icons.privacy_tip_rounded,
                  iconColor: Color(0xFFCA8A04),
                  title: 'Privacy',
                  subtitle: 'Data usage and permissions',
                ),
                Divider(height: 1),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('App Info'),
          FutureBuilder<PackageInfo>(
            future: _pkgFuture,
            builder: (context, snap) {
              final info = snap.data;
              final version = info?.version ?? '—';
              final build = info?.buildNumber ?? '—';
              final latest = updateCfg.latestVersion.trim().isEmpty
                  ? '—'
                  : updateCfg.latestVersion.trim();
              final min = updateCfg.minSupportedVersion.trim().isEmpty
                  ? '—'
                  : updateCfg.minSupportedVersion.trim();
              return _GlassCard(
                child: _ActionRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF92400E),
                  title: 'App version',
                  subtitle: 'Installed: $version ($build)\nLatest: $latest   Min supported: $min',
                  showChevron: false,
                  subtitleMaxLines: 3,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Account'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3E6CC)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandWarmSoft.withValues(alpha: 0.09),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _loggingOut ? null : _logout,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log out',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              kIsWeb
                                  ? 'Return to the public website home page'
                                  : 'Sign out of your account on this device',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF7F1D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _loggingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Danger Zone'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _deletingAccount ? null : _deleteAccount,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete account',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Permanently remove your account and data',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF7F1D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _deletingAccount
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ),
          ),
              ],
            );
  }

  @override
  Widget build(BuildContext context) {
    final updateCfg = _updateConfig(context);
    if (!FirestoreService.isAvailable) {
      if (widget.embedInPublicShell && kIsWeb) {
        return CustomerAccountShell(
          activeTab: CustomerAccountTab.account,
          backFallback: RouteNames.accountHome,
          title: 'Settings',
          child: const Center(child: Text('Firebase is not configured.')),
        );
      }
      return Scaffold(
        backgroundColor: _kSettingsBg,
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    if (widget.embedInPublicShell && kIsWeb) {
      return CustomerAccountShell(
        activeTab: CustomerAccountTab.account,
        backFallback: RouteNames.accountHome,
        title: 'Settings',
        subtitle: 'Notifications, privacy, and account actions',
        child: _settingsList(updateCfg),
      );
    }

    return Scaffold(
      backgroundColor: _kSettingsBg,
      body: Column(
        children: [
          _SaffronHeader(onBack: _handleBack),
          Expanded(child: _settingsList(updateCfg)),
        ],
      ),
    );
  }
}

class _SaffronHeader extends StatelessWidget {
  const _SaffronHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandWarmLight, AppColors.brandWarmSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          color: Colors.white.withValues(alpha: 0.08),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              Expanded(
                child: Text(
                  'Settings',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF7C6A43),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3E6CC)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandWarmSoft.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.actionKey,
    this.showChevron = true,
    this.subtitleMaxLines = 1,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? actionKey;
  final bool showChevron;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_SettingsScreenState>();
    VoidCallback? effectiveOnTap;
    if (state != null && actionKey != null) {
      if (actionKey == 'replay') effectiveOnTap = state._replayWalkthrough;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: effectiveOnTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          _SaffronSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SaffronSwitch extends StatelessWidget {
  const _SaffronSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchTheme(
      data: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brandWarmSoft.withValues(alpha: 0.42)
              : const Color(0xFFE5E7EB),
        ),
        thumbColor: WidgetStateProperty.all(Colors.white),
        overlayColor: WidgetStateProperty.all(AppColors.brandWarmSoft.withValues(alpha: 0.12)),
        thumbIcon: WidgetStateProperty.all(null),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Switch.adaptive(
          value: value,
          activeTrackColor: AppColors.brandWarmSoft.withValues(alpha: 0.40),
          activeThumbColor: Colors.white,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

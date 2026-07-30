import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/firebase_auth_safe.dart';
import '../../../core/constants/route_names.dart';
import '../../../shared/services/auth_post_login.dart';
import '../../../shared/services/auth_service.dart';
import '../../web_public/v2/v2_animate_export.dart';
import '../../web_public/v2/v2_colors.dart';
import '../../web_public/v2/v2_font_styles.dart';
import '../../web_public/v2/v2_text.dart';
import '../../web_public/v2/v2_tokens.dart';
import 'customer_account_shell.dart';

class CustomerAccountHubScreen extends StatefulWidget {
  const CustomerAccountHubScreen({super.key});

  @override
  State<CustomerAccountHubScreen> createState() => _CustomerAccountHubScreenState();
}

class _CustomerAccountHubScreenState extends State<CustomerAccountHubScreen> {
  bool _loggingOut = false;

  String get _displayName {
    final u = FirebaseAuthSafe.currentUser;
    final name = u?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = u?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    final phone = u?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return 'Guest';
  }

  String get _subtitle {
    final u = FirebaseAuthSafe.currentUser;
    if (u == null) return 'Sign in to sync orders and quotations';
    final email = u.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    final phone = u.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return 'Signed in';
  }

  String get _initials {
    final parts = _displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _logout() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, a1, a2) => _LogoutDialog(),
      transitionBuilder: (ctx, anim, secondary, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: c, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(c), child: child));
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      context.go(AuthPostLogin.postLogoutRoute());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not log out. Try again.')));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _ensureSignedInThen(VoidCallback action) async {
    if (!FirebaseAuthSafe.isSignedIn) {
      context.go(AuthPostLogin.loginUrlWithReturn(RouteNames.accountHome));
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return CustomerAccountShell(
      activeTab: CustomerAccountTab.account,
      backFallback: RouteNames.publicHome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _profileHero(v).animate().fadeIn(duration: 420.ms).slideY(begin: 0.08, end: 0),
          const SizedBox(height: 22),
          Text('Quick actions', style: V2FontStyles.inter(fontSize: 13, fontWeight: FontWeight.w700, color: V2Colors.fgSubtle)),
          const SizedBox(height: 12),
          _quickGrid(v),
          const SizedBox(height: 28),
          Text('Account', style: V2FontStyles.inter(fontSize: 13, fontWeight: FontWeight.w700, color: V2Colors.fgSubtle)),
          const SizedBox(height: 12),
          _menuCard([
            _HubMenuItem(Icons.receipt_long_rounded, V2Colors.plasma, 'My orders', 'Track, view details, order again',
                () => _ensureSignedInThen(() => context.push(RouteNames.accountOrders))),
            _HubMenuItem(Icons.request_quote_rounded, V2Colors.ember, 'Saved quotations', 'PDF download or order from quote',
                () => _ensureSignedInThen(() => context.push(RouteNames.calculatorQuotations))),
            _HubMenuItem(Icons.settings_rounded, V2Colors.navy, 'Settings', 'Preferences, notifications, support',
                () => context.push(RouteNames.settings)),
          ]).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06, end: 0),
          const SizedBox(height: 16),
          _logoutCard().animate().fadeIn(delay: 180.ms).slideY(begin: 0.06, end: 0),
        ],
      ),
    );
  }

  Widget _profileHero(V2Responsive v) {
    final signedIn = FirebaseAuthSafe.isSignedIn;
    return Container(
      padding: EdgeInsets.all(v.r(xs: 20, md: 24)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B192C), Color(0xFF1A2740), Color(0xFF635BFF)],
        ),
        boxShadow: [BoxShadow(color: V2Colors.plasma.withValues(alpha: 0.28), blurRadius: 32, offset: Offset(0, 16))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [V2Colors.ember, Color(0xFFFF8A4C)]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(_initials, style: V2FontStyles.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signedIn ? 'My account' : 'Welcome', style: V2Text.micro().copyWith(color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 4),
                Text(_displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: V2FontStyles.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text(_subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: V2Text.small().copyWith(color: Colors.white.withValues(alpha: 0.78))),
              ],
            ),
          ),
          if (!signedIn)
            TextButton(
              onPressed: () => context.go(AuthPostLogin.loginUrlWithReturn(RouteNames.accountHome)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: V2Colors.navy,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
              ),
              child: const Text('Sign in'),
            ),
        ],
      ),
    );
  }

  Widget _quickGrid(V2Responsive v) {
    final items = [
      _QuickItem(Icons.storefront_rounded, 'Shop', V2Colors.ember, () => context.go(RouteNames.publicStore)),
      _QuickItem(Icons.shopping_cart_rounded, 'Cart', V2Colors.plasma, () => context.go(RouteNames.publicCart)),
      _QuickItem(Icons.calculate_rounded, 'Calculator', V2Colors.aurora, () => context.go(RouteNames.publicCalculatorList)),
      _QuickItem(Icons.home_rounded, 'Home', V2Colors.navy, () => context.go(RouteNames.publicHome)),
    ];
    return LayoutBuilder(
      builder: (context, c) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < items.length; i++)
            SizedBox(
              width: (c.maxWidth - 12) / 2,
              child: _QuickTile(item: items[i]).animate(delay: (60 * i).ms).fadeIn().scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
            ),
        ],
      ),
    );
  }

  Widget _menuCard(List<_HubMenuItem> items) => AccountGlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _HubMenuTile(item: items[i]),
              if (i < items.length - 1) Divider(height: 1, indent: 68, color: Colors.black.withValues(alpha: 0.05)),
            ],
          ],
        ),
      );

  Widget _logoutCard() {
    final signedIn = FirebaseAuthSafe.isSignedIn;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (!signedIn || _loggingOut) ? null : _logout,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: _loggingOut
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                    : const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(signedIn ? 'Log out' : 'Not signed in',
                        style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w800, color: signedIn ? const Color(0xFFDC2626) : V2Colors.fgSubtle)),
                    Text(signedIn ? 'Sign out of this device securely' : 'Sign in to enable logout',
                        style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: signedIn ? const Color(0xFFDC2626).withValues(alpha: 0.5) : V2Colors.fgFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Log out?', style: V2FontStyles.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('You will be signed out on this device.', style: V2Text.small().copyWith(color: V2Colors.fgSubtle, height: 1.4)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980))),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(980))),
                            child: const Text('Log out'),
                          ),
                        ),
                      ],
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

class _QuickItem {
  const _QuickItem(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({required this.item});
  final _QuickItem item;
  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: item.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.02 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: item.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: item.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item.label, style: V2FontStyles.inter(fontSize: 14, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubMenuItem {
  const _HubMenuItem(this.icon, this.accent, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _HubMenuTile extends StatefulWidget {
  const _HubMenuTile({required this.item});
  final _HubMenuItem item;
  @override
  State<_HubMenuTile> createState() => _HubMenuTileState();
}

class _HubMenuTileState extends State<_HubMenuTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          color: _hover ? item.accent.withValues(alpha: 0.04) : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: item.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(item.icon, color: item.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(item.subtitle, style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: V2Colors.fgFaint),
            ],
          ),
        ),
      ),
    );
  }
}

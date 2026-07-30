// Connect Page — Apple-style DG Yard Connect landing for web.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../shared/services/auth_post_login.dart';
import '../../../../shared/services/auth_service.dart';
import '../../core/brand/public_brand_content.dart';
import '../../core/brand/public_brand_scope.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_glass.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/widgets/v2_brand_icons.dart';
import '../../widgets/public_floating_menu.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../v2/widgets/v2_hero_download_block.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _scroll = ScrollController();

  static const _features = [
    _ConnectFeature(
      'Post jobs in minutes',
      'Describe CCTV, networking or IT work with location, scope and budget.',
      Icons.post_add_rounded,
      V2Colors.plasma,
    ),
    _ConnectFeature(
      'Verified technicians',
      'KYC-checked professionals bid on your job with clear pricing.',
      Icons.verified_user_rounded,
      V2Colors.aurora,
    ),
    _ConnectFeature(
      'Live tracking & chat',
      'Track arrival, chat on job, share photos and approve milestones.',
      Icons.location_on_rounded,
      V2Colors.ember,
    ),
    _ConnectFeature(
      'Secure payments',
      'Escrow-style flow with ratings, warranty and payout protection.',
      Icons.payments_rounded,
      V2Colors.premiumOrange,
    ),
  ];

  static const _steps = [
    ('01', 'Post', 'Share job details and preferred schedule.'),
    ('02', 'Match', 'Verified technicians send bids instantly.'),
    ('03', 'Execute', 'Track work, chat and approve completion.'),
    ('04', 'Pay', 'Rate the pro and release secure payment.'),
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final brand = PublicBrandScope.contentOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _ConnectHero(appName: brand.companyName),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    v.gutter,
                    0,
                    v.gutter,
                    v.sectionPadY,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: V2.maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeading(
                            eyebrow: 'Marketplace',
                            title: 'Built for dealers and technicians.',
                            subtitle:
                                'DG Yard Connect brings job posting, bidding, execution and payouts into one trusted ecosystem.',
                          ),
                          const SizedBox(height: 24),
                          _FeatureGrid(features: _features),
                          const SizedBox(height: 72),
                          const _SectionHeading(
                            eyebrow: 'How it works',
                            title: 'From job post to payout.',
                            subtitle:
                                'A simple four-step flow designed for speed, transparency and accountability.',
                          ),
                          const SizedBox(height: 24),
                          const _ProcessRail(steps: _steps),
                          const SizedBox(height: 72),
                          const _RoleCards(),
                          const SizedBox(height: 72),
                          _AppDownloadBand(brand: brand),
                        ],
                      ),
                    ),
                  ),
                ),
                const V2Footer(),
                SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectHero extends StatelessWidget {
  const _ConnectHero({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.lg;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        v.gutter,
        v.r<double>(xs: 128, md: 148, lg: 166),
        v.gutter,
        v.r<double>(xs: 58, md: 76, lg: 96),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F5F7)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _HeroStory(appName: appName)),
                    const SizedBox(width: 42),
                    SizedBox(width: 460, child: const _ConnectAccessPanel()),
                  ],
                )
              : Column(
                  children: [
                    _HeroStory(appName: appName),
                    const SizedBox(height: 32),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: const _ConnectAccessPanel(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroStory extends StatelessWidget {
  const _HeroStory({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Column(
      crossAxisAlignment:
          v.isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _GlassPill(
          label: 'DG Yard Connect',
          icon: Icons.hub_rounded,
          color: V2Colors.aurora,
        ),
        SizedBox(height: v.r<double>(xs: 18, md: 22)),
        Text(
          'Hire verified technicians.\nTrack every job.',
          textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 36, sm: 42, md: 54, lg: 62),
            height: 0.98,
            letterSpacing: -2.4,
            fontWeight: FontWeight.w800,
            color: V2Colors.inkSaaS,
          ),
        ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.06, end: 0),
        SizedBox(height: v.r<double>(xs: 16, md: 20)),
        Text(
          'India\'s verified marketplace for IT and security professionals. '
          'Dealers post jobs, technicians bid with confidence, and $appName keeps everything tracked, rated and paid in one place.',
          textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 16, md: 18),
            height: 1.55,
            letterSpacing: -0.2,
            color: V2Colors.inkMutedSaaS,
          ),
        ).animate(delay: 80.ms).fadeIn(duration: 520.ms),
        SizedBox(height: v.r<double>(xs: 22, md: 28)),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: v.isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: const [
            _StatChip(value: '300+', label: 'Technicians'),
            _StatChip(value: 'Live', label: 'Tracking'),
            _StatChip(value: 'KYC', label: 'Verified'),
          ],
        ).animate(delay: 140.ms).fadeIn(duration: 480.ms),
        if (v.isDesktop) ...[
          const SizedBox(height: 28),
          _HeroPreviewCard(),
        ],
      ],
    );
  }
}

class _HeroPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: v2BlurLayer(
        sigma: 18,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: V2Colors.paperLow,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      V2Colors.plasma,
                      V2Colors.aurora.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: const Icon(Icons.engineering_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CCTV installation — Andheri',
                      style: V2FontStyles.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: V2Colors.inkSaaS,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3 bids received · 2 verified technicians nearby',
                      style: V2FontStyles.inter(
                        fontSize: 12.5,
                        color: V2Colors.inkMutedSaaS,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: V2Colors.auroraSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Live',
                  style: V2FontStyles.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: V2Colors.aurora,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 520.ms).slideY(begin: 0.05, end: 0);
  }
}

class _ConnectAccessPanel extends StatefulWidget {
  const _ConnectAccessPanel();

  @override
  State<_ConnectAccessPanel> createState() => _ConnectAccessPanelState();
}

class _ConnectAccessPanelState extends State<_ConnectAccessPanel> {
  bool _socialLoading = false;

  Future<void> _handleAuthSuccess(UserCredential cred) async {
    await AuthPostLogin.complete(
      context,
      cred,
      onLoadingEnd: () {
        if (mounted) setState(() => _socialLoading = false);
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _socialLoading = true);
    try {
      final cred = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (cred == null) {
        setState(() => _socialLoading = false);
        _showError('Google sign in was cancelled or failed.');
        return;
      }
      await _handleAuthSuccess(cred);
    } catch (e) {
      if (!mounted) return;
      setState(() => _socialLoading = false);
      _showError(e);
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() => _socialLoading = true);
    try {
      final cred = await AuthService().signInWithFacebook();
      if (!mounted) return;
      if (cred == null) {
        setState(() => _socialLoading = false);
        _showError('Facebook sign in was cancelled or failed.');
        return;
      }
      await _handleAuthSuccess(cred);
    } catch (e) {
      if (!mounted) return;
      setState(() => _socialLoading = false);
      _showError(e);
    }
  }

  void _showError(Object errorOrMessage) {
    final msg = errorOrMessage is String
        ? errorOrMessage
        : userFacingError(errorOrMessage);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        boxShadow: V2Colors.paperHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Get started',
            style: V2FontStyles.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: V2Colors.inkSaaS,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in or create your Connect account.',
            style: V2FontStyles.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: V2Colors.inkMutedSaaS,
            ),
          ),
          const SizedBox(height: 22),
          _AccessButton(
            label: 'Continue with Google',
            leading: V2BrandIcons.google(size: 16),
            color: const Color(0xFF4285F4),
            onTap: _socialLoading ? null : _signInWithGoogle,
          ),
          const SizedBox(height: 10),
          _AccessButton(
            label: 'Continue with Facebook',
            leading: V2BrandIcons.facebook(size: 16),
            color: const Color(0xFF1877F2),
            onTap: _socialLoading ? null : _signInWithFacebook,
          ),
          const SizedBox(height: 20),
          const _OrDivider(label: 'or sign in with'),
          const SizedBox(height: 20),
          _AccessButton(
            label: 'Email & password',
            leading: const Icon(Icons.mail_outline_rounded, size: 18, color: Colors.white),
            color: V2Colors.inkSaaS,
            filled: true,
            onTap: () => context.go(
              AuthPostLogin.loginUrlWithReturn(RouteNames.publicConnect),
            ),
          ),
          const SizedBox(height: 10),
          _AccessButton(
            label: 'Phone OTP',
            leading: Icon(Icons.sms_outlined, size: 18, color: V2Colors.aurora),
            color: V2Colors.aurora,
            filled: true,
            onTap: () => context.go(
              AuthPostLogin.phoneUrlWithReturn(RouteNames.publicConnect),
            ),
          ),
          const SizedBox(height: 22),
          const _OrDivider(label: 'new to connect'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OutlineTile(
                  label: 'Register as Dealer',
                  icon: Icons.storefront_rounded,
                  onTap: () => context.go(RouteNames.registerDealer),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlineTile(
                  label: 'Register as Technician',
                  icon: Icons.handyman_rounded,
                  onTap: () => context.go(RouteNames.registerTechnician),
                ),
              ),
            ],
          ),
          if (_socialLoading) ...[
            const SizedBox(height: 18),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.05, end: 0);
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features});

  final List<_ConnectFeature> features;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final cols = v.width >= V2Breakpoints.lg
        ? 4
        : v.width >= V2Breakpoints.md
        ? 2
        : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: v.width >= V2Breakpoints.lg ? 0.92 : 1.15,
      ),
      itemBuilder: (context, index) {
        final item = features[index];
        return _FeatureCard(feature: item, index: index);
      },
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature, required this.index});

  final _ConnectFeature feature;
  final int index;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: V2.dFast,
        curve: V2.eOut,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.95 : 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hover ? widget.feature.color.withValues(alpha: 0.35) : V2Colors.borderSubtle,
          ),
          boxShadow: _hover ? V2Colors.paperMid : V2Colors.paperLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.feature.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.feature.icon, color: widget.feature.color),
            ),
            const SizedBox(height: 16),
            Text(
              widget.feature.title,
              style: V2FontStyles.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: V2Colors.inkSaaS,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.feature.subtitle,
              style: V2FontStyles.inter(
                fontSize: 13.5,
                height: 1.45,
                color: V2Colors.inkMutedSaaS,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (80 + widget.index * 70).ms)
        .fadeIn(duration: 480.ms)
        .slideY(begin: 0.06, end: 0);
  }
}

class _ProcessRail extends StatelessWidget {
  const _ProcessRail({required this.steps});

  final List<(String, String, String)> steps;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final horizontal = v.width >= V2Breakpoints.md;

    if (horizontal) {
      return Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _ProcessStep(step: steps[i], index: i)),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _ProcessStep(step: steps[i], index: i),
          if (i < steps.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({required this.step, required this.index});

  final (String, String, String) step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: V2Colors.borderSubtle),
        boxShadow: V2Colors.paperLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.$1,
            style: V2FontStyles.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: V2Colors.aurora,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.$2,
            style: V2FontStyles.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: V2Colors.inkSaaS,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.$3,
            style: V2FontStyles.inter(
              fontSize: 13.5,
              height: 1.45,
              color: V2Colors.inkMutedSaaS,
            ),
          ),
        ],
      ),
    ).animate(delay: (100 + index * 80).ms).fadeIn(duration: 480.ms);
  }
}

class _RoleCards extends StatelessWidget {
  const _RoleCards();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final stacked = v.width < V2Breakpoints.md;

    final dealer = _RoleCard(
      title: 'For dealers',
      subtitle: 'Post jobs, compare bids, track technicians and manage payouts.',
      icon: Icons.storefront_rounded,
      color: V2Colors.plasma,
      cta: 'Register as Dealer',
      onTap: () => context.go(RouteNames.registerDealer),
    );
    final tech = _RoleCard(
      title: 'For technicians',
      subtitle: 'Get nearby jobs, bid confidently and build your verified profile.',
      icon: Icons.handyman_rounded,
      color: V2Colors.aurora,
      cta: 'Register as Technician',
      onTap: () => context.go(RouteNames.registerTechnician),
    );

    if (stacked) {
      return Column(children: [dealer, const SizedBox(height: 14), tech]);
    }

    return Row(
      children: [
        Expanded(child: dealer),
        const SizedBox(width: 16),
        Expanded(child: tech),
      ],
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String cta;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.dFast,
          curve: V2.eOut,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                widget.color.withValues(alpha: _hover ? 0.12 : 0.06),
              ],
            ),
            border: Border.all(
              color: widget.color.withValues(alpha: _hover ? 0.35 : 0.18),
            ),
            boxShadow: _hover ? V2Colors.paperMid : V2Colors.paperLow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: widget.color, size: 28),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: V2FontStyles.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: V2Colors.inkSaaS,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: V2FontStyles.inter(
                  fontSize: 14.5,
                  height: 1.5,
                  color: V2Colors.inkMutedSaaS,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    widget.cta,
                    style: V2FontStyles.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: widget.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDownloadBand extends StatelessWidget {
  const _AppDownloadBand({required this.brand});

  final PublicBrandContent brand;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: v2BlurLayer(
        sigma: 16,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: V2Colors.paperLow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prefer the mobile app?',
                style: V2FontStyles.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: V2Colors.inkSaaS,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                brand.appDownloadDescription,
                style: V2FontStyles.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: V2Colors.inkMutedSaaS,
                ),
              ),
              const SizedBox(height: 18),
              V2HeroDownloadBlock(
                links: brand.heroCta1StoreButtons,
                alignStart: true,
                flat: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: V2FontStyles.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: V2Colors.aurora,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: V2FontStyles.inter(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: V2Colors.inkSaaS,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: V2FontStyles.inter(
            fontSize: 16,
            height: 1.5,
            color: V2Colors.inkMutedSaaS,
          ),
        ),
      ],
    );
  }
}

class _ConnectFeature {
  const _ConnectFeature(this.title, this.subtitle, this.icon, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: V2Colors.paperLow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: V2FontStyles.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: V2Colors.inkSaaS,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: V2Colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: V2FontStyles.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: V2Colors.inkSaaS,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: V2FontStyles.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: V2Colors.inkMutedSaaS,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessButton extends StatefulWidget {
  const _AccessButton({
    required this.label,
    required this.leading,
    required this.color,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final Widget leading;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  State<_AccessButton> createState() => _AccessButtonState();
}

class _AccessButtonState extends State<_AccessButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final bg = widget.filled
        ? (widget.color == V2Colors.inkSaaS
              ? V2Colors.inkSaaS
              : const Color(0xFFF5F5F7))
        : Colors.white;
    final fg = widget.filled && widget.color == V2Colors.inkSaaS
        ? Colors.white
        : V2Colors.inkSaaS;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.dFast,
          curve: V2.eOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: enabled && _hover ? bg.withValues(alpha: 0.92) : bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.filled
                  ? (widget.color == V2Colors.inkSaaS
                        ? V2Colors.inkSaaS
                        : V2Colors.borderSubtle)
                  : V2Colors.borderStrong,
            ),
            boxShadow: _hover ? V2Colors.paperLow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.leading,
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: widget.filled ? fg : V2Colors.inkSaaS,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineTile extends StatefulWidget {
  const _OutlineTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_OutlineTile> createState() => _OutlineTileState();
}

class _OutlineTileState extends State<_OutlineTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? V2Colors.plasmaSubtle : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? V2Colors.plasma.withValues(alpha: 0.35) : V2Colors.borderSubtle,
            ),
          ),
          child: Column(
            children: [
              Icon(widget.icon, size: 20, color: V2Colors.inkSaaS),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: V2FontStyles.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: V2Colors.inkSaaS,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: V2Colors.borderSubtle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: V2FontStyles.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: V2Colors.inkMutedSaaS,
            ),
          ),
        ),
        const Expanded(child: Divider(color: V2Colors.borderSubtle)),
      ],
    );
  }
}
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../shared/services/walkthrough_service.dart';
import '../../shared/widgets/brand_logo.dart';

class AppWalkthroughScreen extends StatefulWidget {
  const AppWalkthroughScreen({super.key});

  @override
  State<AppWalkthroughScreen> createState() => _AppWalkthroughScreenState();
}

class _AppWalkthroughScreenState extends State<AppWalkthroughScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _pages = <_WalkItem>[
    _WalkItem(
      title: 'Welcome to D.G.Yard Connect',
      subtitle: 'Smart platform for dealers and technicians.',
      body:
          'Post jobs, receive bids, assign experts, and track work in one reliable workflow.',
      icon: Icons.waving_hand_rounded,
      a: Color(0xFFE0EAFF),
      b: Color(0xFFF6F9FF),
    ),
    _WalkItem(
      title: 'Transparent Job Flow',
      subtitle: 'From posting to completion.',
      body:
          'Structured steps, live status updates, and proof uploads make every service job auditable.',
      icon: Icons.route_rounded,
      a: Color(0xFFE4FCEB),
      b: Color(0xFFF5FFF8),
    ),
    _WalkItem(
      title: 'Secure and Trusted',
      subtitle: 'Built for real operations.',
      body:
          'OTP login, role checks, KYC-ready onboarding, and safe process controls throughout the app.',
      icon: Icons.verified_user_rounded,
      a: Color(0xFFFFEFE3),
      b: Color(0xFFFFF9F4),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await WalkthroughService.markGeneralSeen();
    if (!mounted) return;
    context.go(kIsWeb ? RouteNames.publicHome : RouteNames.phoneEntry);
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _WalkPage(item: _pages[i]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const BrandLogo(size: 26, preferAppIcon: true),
                      const Spacer(),
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _index == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _index == i
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(isLast ? 'Get Started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkPage extends StatelessWidget {
  const _WalkPage({required this.item});

  final _WalkItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [item.a, item.b],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 50, 22, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, size: 60, color: const Color(0xFF2563EB)),
                )
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
              ),
              const SizedBox(height: 28),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700,
                    ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
              ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 14),
              Text(
                item.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF334155),
                      height: 1.45,
                    ),
              ).animate().fadeIn(delay: 240.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkItem {
  const _WalkItem({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    required this.a,
    required this.b,
  });

  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
  final Color a;
  final Color b;
}

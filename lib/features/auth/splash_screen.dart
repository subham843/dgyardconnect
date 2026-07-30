import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/fcm_service.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/widgets/brand_kit_provider.dart';
import '../../shared/widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _baseBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _baseBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    if (await FcmService.isDeepLinkLockActive()) {
      await Future.delayed(const Duration(seconds: 7));
      if (!mounted) return;
    }

    if (Firebase.apps.isEmpty) {
      if (!mounted) return;
      context.go(RouteNames.phoneEntry);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      if (kIsWeb) {
        context.go(RouteNames.publicHome);
      } else {
        context.go(RouteNames.phoneEntry);
      }
      return;
    }

    final outcome = await AuthPostLogin.resolveProfile(user.uid);
    if (!mounted) return;
    switch (outcome) {
      case AuthProfileUnavailable():
        context.go(kIsWeb ? RouteNames.publicHome : RouteNames.phoneEntry);
        break;
      case AuthProfileNewUser():
        context.go(kIsWeb ? RouteNames.publicHome : RouteNames.serviceAreaPicker);
        break;
      case AuthProfileExisting(:final role):
        try {
          await FcmService.saveTokenToUser(user.uid);
          await FcmService.saveCurrentRole(role);
        } catch (_) {}
        if (!mounted) return;
        context.go(AuthPostLogin.homeRouteForRole(role));
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 400));
          final payload = await FcmService.getNotificationLaunchPayload();
          if (payload != null && payload.isNotEmpty) {
            await FcmService.navigateFromLaunchPayload(payload);
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = BrandKitProvider.of(context);
    final remoteIntro = (kit.splashBackgroundUrl ?? '').trim();
    const appName = 'D.G.Yard Connect';

    return Scaffold(
      backgroundColor: _baseBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _SplashBackground()),
          Positioned(
            top: -90,
            left: -70,
            child: _GlowOrb(
              size: 240,
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            right: -80,
            top: 180,
            child: _GlowOrb(
              size: 220,
              color: AppColors.accent.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: -80,
            left: 50,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFFBFDBFE).withValues(alpha: 0.20),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Column(
                    children: [
                      Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const BrandLogo(size: 72, preferAppIcon: true),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'DGYARD',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 2.2,
                            ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 650.ms, curve: Curves.easeOutCubic)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        duration: 650.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 26),
                  _IntroIllustration(remoteIntro: remoteIntro)
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: 0, end: -8, duration: 1700.ms, curve: Curves.easeInOut)
                      .fadeIn(delay: 180.ms, duration: 420.ms),
                  const Spacer(),
                  Column(
                    children: [
                      Text(
                        appName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.4,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: 0.7,
                        child: Text(
                          AppConstants.introTagline,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF334155),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 520.ms, duration: 420.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.10, end: 0, duration: 420.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFDDEEFF),
            const Color(0xFFF2F8FF),
            Colors.white,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _IntroIllustration extends StatelessWidget {
  const _IntroIllustration({required this.remoteIntro});

  final String remoteIntro;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: remoteIntro.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: remoteIntro,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const _IntroGradientFallback(),
              )
            : const _IntroGradientFallback(),
      ),
    );
  }
}

class _IntroGradientFallback extends StatelessWidget {
  const _IntroGradientFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDDEEFF),
            Color(0xFFF2F8FF),
            Colors.white,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

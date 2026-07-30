import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/social_sign_in_icons_export.dart';
import '../web_public/v2/v2_font_styles.dart';
import 'package:go_router/go_router.dart';
import '../../core/bootstrap/firebase_bootstrap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/utils/user_facing_error.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/brand_logo.dart';
import '../web_public/v2/v2_colors.dart';
import '../web_public/v2/v2_tokens.dart';
import '../web_public/widgets/public_floating_menu.dart';

const int _adminTapCount = 7;

// Premium design tokens
const _radiusGlass = 20.0;

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  static const String _countryCode = '+91';

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseBootstrap.ensureInitialized();
      });
    }
  }

  void _onOtpChanged() {
    if (_otpController.text.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  bool _isLoading = false;
  bool _socialLoading = false;
  bool _otpSent = false;
  String? _verificationId;
  String _sentPhone = '';
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  int _adminTapCountCurrent = 0;
  Timer? _adminTapResetTimer;

  void _onAdminTap() {
    if (!kDebugMode) return;
    _adminTapResetTimer?.cancel();
    _adminTapCountCurrent++;
    if (_adminTapCountCurrent >= _adminTapCount) {
      _adminTapCountCurrent = 0;
      context.go(RouteNames.login);
      return;
    }
    _adminTapResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _adminTapCountCurrent = 0);
    });
  }

  @override
  void dispose() {
    _otpController.removeListener(_onOtpChanged);
    _adminTapResetTimer?.cancel();
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_resendSecondsRemaining <= 1) {
          _resendSecondsRemaining = 0;
          _resendTimer?.cancel();
        } else {
          _resendSecondsRemaining--;
        }
      });
    });
  }

  void _changeNumber() {
    setState(() {
      _otpSent = false;
      _verificationId = null;
      _otpController.clear();
      _resendTimer?.cancel();
      _resendSecondsRemaining = 0;
    });
  }

  Future<void> _handleAuthSuccess(UserCredential cred) async {
    final redirect = AuthPostLogin.redirectFromUri(GoRouterState.of(context).uri);
    await AuthPostLogin.complete(
      context,
      cred,
      redirectAfterLogin: redirect,
      onLoadingEnd: () {
        if (mounted) setState(() => _socialLoading = false);
      },
    );
  }

  Future<bool> _ensureFirebaseReady() async {
    try {
      await FirebaseBootstrap.ensureInitialized();
      if (Firebase.apps.isEmpty) {
        _showError(
          'Sign-in service is not available. Refresh the page and try again.',
        );
        return false;
      }
      return true;
    } catch (_) {
      _showError(
        'Could not connect to sign-in service. Check your internet and try again.',
      );
      return false;
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
    if (digits.length < 10) {
      _showError('Please enter a valid 10-digit mobile number.');
      return;
    }
    final phone = '$_countryCode$digits';
    if (!await _ensureFirebaseReady()) return;
    // Show OTP input immediately so user is not waiting on a blank/loading screen.
    setState(() {
      _isLoading = true;
      _otpSent = true;
      _sentPhone = phone;
    });

    // If codeSent is delayed (e.g. reCAPTCHA/SMS/network delay), stop spinner and
    // show a non-blocking info hint. Avoid blocking dialogs for this transient state.
    Timer? fallbackTimer;
    fallbackTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      if (_isLoading && _verificationId == null) {
        setState(() => _isLoading = false);
        _showInfo(
          'OTP is taking longer than usual. Check your SMS or try Send OTP again.',
        );
      }
      fallbackTimer?.cancel();
    });

    try {
      await AuthService().verifyPhoneNumber(
        phoneNumber: phone,
        codeSent: (verificationId) {
          fallbackTimer?.cancel();
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          _startResendTimer();
        },
        verificationFailed: (error) {
          fallbackTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _otpSent = false;
            _verificationId = null;
          });
          _showError(error);
        },
        verificationCompleted: (cred) async {
          fallbackTimer?.cancel();
          if (!mounted) return;
          setState(() => _isLoading = false);
          try {
            final userCred = await AuthService().signInWithCredential(cred);
            if (!mounted) return;
            if (userCred != null) await _handlePhoneAuthSuccess(userCred);
          } catch (e) {
            if (mounted) _showError(e);
          }
        },
      );
    } catch (e) {
      fallbackTimer.cancel();
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSecondsRemaining > 0) return;
    if (!await _ensureFirebaseReady()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService().verifyPhoneNumber(
        phoneNumber: _sentPhone,
        codeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          _startResendTimer();
        },
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _otpSent = false;
            _verificationId = null;
          });
          _showError(error);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim().replaceAll(RegExp(r'\s'), '');
    if (code.length != 6) {
      _showError('Please enter the 6-digit OTP.');
      return;
    }
    if (_verificationId == null) {
      _showError('Please wait, OTP is being sent…');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService().signInWithPhoneCredential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      if (!mounted) return;
      if (cred == null) {
        setState(() => _isLoading = false);
        _showError('Verification failed. Please try again.');
        return;
      }
      await _handlePhoneAuthSuccess(cred);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _handlePhoneAuthSuccess(UserCredential cred) async {
    final redirect = AuthPostLogin.redirectFromUri(GoRouterState.of(context).uri);
    await AuthPostLogin.complete(
      context,
      cred,
      redirectAfterLogin: redirect,
      onLoadingEnd: () {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _socialLoading = true);
    if (!await _ensureFirebaseReady()) {
      if (mounted) setState(() => _socialLoading = false);
      return;
    }
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
    if (!await _ensureFirebaseReady()) {
      if (mounted) setState(() => _socialLoading = false);
      return;
    }
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
    final String friendlyText;
    if (errorOrMessage is String) {
      final s = errorOrMessage;
      final otpTuned = _friendlyOtpError(s);
      friendlyText = otpTuned != s ? otpTuned : userFacingError(s);
    } else {
      friendlyText = userFacingError(errorOrMessage);
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusGlass),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Notice',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          friendlyText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Maps Firebase/Play Integrity errors to a user-friendly message.
  static String _friendlyOtpError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('missing a valid app identifier') ||
        lower.contains('play integrity') ||
        lower.contains('recaptcha') ||
        lower.contains('safetynet')) {
      return 'OTP cannot be sent right now due to app verification (Play Integrity / reCAPTCHA).\n\nPlease update the app from the latest Play build and try again. If the issue continues, contact support.';
    }
    if (lower.contains('blocked') || lower.contains('unusual activity')) {
      return 'Too many attempts from this device. Please try again after 1–2 hours or use a different network.';
    }
    if (lower.contains('too many requests') || lower.contains('quota')) {
      return 'Too many attempts. Please try again after some time.';
    }
    if (lower.contains('invalid') && lower.contains('number')) {
      return 'Please enter a valid 10-digit mobile number.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebPhoneEntry(context);
    }

    const bgBase = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // Soft gradient wash (primary 8% top-left, accent 5% bottom-right)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    bgBase,
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: kDebugMode ? _onAdminTap : null,
                            behavior: HitTestBehavior.opaque,
                            child: _buildTitleBlock(context),
                          ),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            key: ValueKey(_otpSent),
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _otpSent
                                ? KeyedSubtree(
                                    key: const ValueKey('otp'),
                                    child: _buildOtpCard(),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('phone'),
                                    child: _buildPhoneCard(),
                                  ),
                          ),
                          if (!_otpSent) ...[
                            const SizedBox(height: 28),
                            _buildDivider(320),
                            const SizedBox(height: 28),
                            _PremiumCard(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 20,
                                    ),
                                    child: Column(
                                      children: [
                                        _SocialButton(
                                          label: 'Continue with Google',
                                          leading: buildGoogleSocialIcon(
                                            size: 22,
                                            color: const Color(0xFF4285F4),
                                          ),
                                          onPressed: _socialLoading
                                              ? null
                                              : _signInWithGoogle,
                                          delay: 340,
                                        ),
                                        const SizedBox(height: 14),
                                        _SocialButton(
                                          label: 'Continue with Facebook',
                                          leading: buildFacebookSocialIcon(
                                            size: 22,
                                            color: const Color(0xFF1877F2),
                                          ),
                                          onPressed: _socialLoading
                                              ? null
                                              : _signInWithFacebook,
                                          delay: 380,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(
                                  delay: 280.ms,
                                  duration: 600.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_otpSent) _buildStickyCta(),
              ],
            ),
          ),
          // Waiting overlay when Send OTP is in progress (reCAPTCHA / SMS sending)
          if (_isLoading && _verificationId == null) _buildWaitingOverlay(),
        ],
      ),
    );
  }

  Widget _buildWebPhoneEntry(BuildContext context) {
    final v = V2Responsive(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    const Color(0xFFF5F5F7),
                    V2Colors.auroraSubtle.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      v.gutter,
                      v.r<double>(xs: 32, md: 48, lg: 56),
                      v.gutter,
                      PublicFloatingMenu.contentBottomInset(context),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Continue with phone',
                                textAlign: TextAlign.center,
                                style: V2FontStyles.inter(
                                  fontSize: v.r<double>(xs: 30, md: 34),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: V2Colors.inkSaaS,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We\'ll send a one-time code to verify your number.',
                                textAlign: TextAlign.center,
                                style: V2FontStyles.inter(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: V2Colors.inkMutedSaaS,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                  boxShadow: V2Colors.paperHigh,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  child: _otpSent
                                      ? _buildOtpCard()
                                      : Column(
                                          key: const ValueKey('phone-web'),
                                          children: [
                                            _buildPhoneCard(),
                                            const SizedBox(height: 20),
                                            SizedBox(
                                              height: 52,
                                              width: double.infinity,
                                              child: FilledButton.icon(
                                                onPressed: _isLoading ? null : _sendOtp,
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: V2Colors.inkSaaS,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                                icon: _isLoading
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(Icons.sms_outlined, size: 18),
                                                label: Text(
                                                  _isLoading ? 'Sending OTP…' : 'Send OTP',
                                                  style: V2FontStyles.inter(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              if (!_otpSent) ...[
                                const SizedBox(height: 24),
                                _buildDivider(320),
                                const SizedBox(height: 20),
                                _PremiumCard(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    child: Column(
                                      children: [
                                        _SocialButton(
                                          label: 'Continue with Google',
                                          leading: buildGoogleSocialIcon(
                                            size: 22,
                                            color: const Color(0xFF4285F4),
                                          ),
                                          onPressed: _socialLoading ? null : _signInWithGoogle,
                                          delay: 340,
                                        ),
                                        const SizedBox(height: 12),
                                        _SocialButton(
                                          label: 'Continue with Facebook',
                                          leading: buildFacebookSocialIcon(
                                            size: 22,
                                            color: const Color(0xFF1877F2),
                                          ),
                                          onPressed: _socialLoading ? null : _signInWithFacebook,
                                          delay: 380,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: () => context.go(RouteNames.login),
                                    child: const Text('Use email instead'),
                                  ),
                                  TextButton(
                                    onPressed: () => context.go(RouteNames.publicConnect),
                                    child: const Text('Back to Connect'),
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
              ],
            ),
          ),
          if (_isLoading && _verificationId == null) _buildWaitingOverlay(),
        ],
      ),
    );
  }

  /// Full-screen waiting overlay: "Verifying... Complete reCAPTCHA if shown."
  Widget _buildWaitingOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verifying your number',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A security check (reCAPTCHA) may appear.\nPlease complete it to receive the OTP.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Part 1B: Logo + tagline + "Continue with phone" + subtitle
  Widget _buildTitleBlock(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: BrandLogo(size: 72, preferAppIcon: true)),
            const SizedBox(height: 14),
            Text(
              AppConstants.introTagline,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Continue with phone',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We'll send a one-time code to verify your number.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 220.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }

  /// Apple-style glass CTA — frosted primary
  Widget _buildStickyCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: SizedBox(
        height: 52,
        child: Opacity(
          opacity: _isLoading ? 0.75 : 1,
          child: GlassContainer(
            onTap: _isLoading ? null : _sendOtp,
            borderRadius: 16,
            blurSigma: 22,
            // Lighter base glass; gradient overlay gives "Apple" feel.
            color: Colors.white.withValues(alpha: 0.22),
            borderColor: Colors.white.withValues(alpha: 0.5),
            borderWidth: 1.2,
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.9),
                    AppColors.primaryLight.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sms_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Send OTP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
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

  /// Phone input card — glass morphism
  Widget _buildPhoneCard() {
    return GlassContainer(
          borderRadius: _radiusGlass,
          blurSigma: 22,
          padding: const EdgeInsets.all(20),
          child: _MobileNumberField(
            controller: _phoneController,
            validator: (v) {
              if (v == null || v.trim().length < 10) {
                return 'Enter valid 10-digit number';
              }
              return null;
            },
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
  }

  String get _maskedPhone {
    if (_sentPhone.length < 8) return _sentPhone;
    return '${_sentPhone.substring(0, 4)} ****** ${_sentPhone.substring(_sentPhone.length - 4)}';
  }

  Widget _buildOtpCard() {
    return _PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassContainer(
                  borderRadius: 14,
                  blurSigma: 14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderColor: AppColors.primary.withValues(alpha: 0.25),
                  child: Row(
                    children: [
                      if (_verificationId == null && _isLoading)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.mark_email_read_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _verificationId == null && _isLoading
                                  ? 'Sending OTP…'
                                  : 'OTP sent',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _verificationId == null && _isLoading
                                  ? 'Sent to $_maskedPhone (wait a moment)'
                                  : 'Sent to $_maskedPhone',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Enter OTP',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                _OtpSlotsInput(controller: _otpController),
                const SizedBox(height: 24),
                _GradientButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  isLoading: _isLoading,
                  label: 'Verify',
                ),
                const SizedBox(height: 24),
                _buildOtpFooter(),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildOtpFooter() {
    return GlassContainer(
      borderRadius: 18,
      blurSigma: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          TextButton.icon(
            onPressed: () {
              _showError(
                'Check your SMS. OTP may take a few seconds to arrive.',
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
            icon: Icon(
              Icons.sms_outlined,
              size: 16,
              color: Colors.grey.shade500,
            ),
            label: Text(
              "Can't receive OTP?",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_resendSecondsRemaining > 0)
                GlassContainer(
                  borderRadius: 20,
                  blurSigma: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: 1 - (_resendSecondsRemaining / 30),
                          color: AppColors.primary,
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Resend in ${_resendSecondsRemaining}s',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextButton(
                  onPressed: _isLoading ? null : _resendOtp,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Resend OTP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _changeNumber,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Change number',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sign in header with soft continuous animations on title and blue strip.
class _AnimatedSignInHeader extends StatefulWidget {
  const _AnimatedSignInHeader({required this.appName});

  final String appName;

  @override
  State<_AnimatedSignInHeader> createState() => _AnimatedSignInHeaderState();
}

class _AnimatedSignInHeaderState extends State<_AnimatedSignInHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.015,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulse.value,
                  child: Text(
                    'Sign in',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -1.2,
                      height: 1.1,
                    ),
                  ),
                );
              },
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 6),
        AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: 0.15 + (_shimmer.value * 0.15),
                        ),
                        blurRadius: 6 + (_shimmer.value * 2),
                        spreadRadius: _shimmer.value,
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment(-1.2 + (_shimmer.value * 0.4), 0),
                      end: Alignment(1.2 - (_shimmer.value * 0.4), 0),
                      colors: [
                        AppColors.primary.withValues(alpha: 0.5),
                        AppColors.primary,
                        AppColors.primaryLight.withValues(
                          alpha: 0.5 + (_shimmer.value * 0.3),
                        ),
                        AppColors.primary,
                      ],
                      stops: const [0.0, 0.4, 0.6, 1.0],
                    ),
                  ),
                );
              },
            )
            .animate()
            .fadeIn(delay: 120.ms)
            .scaleX(begin: 0, end: 1, curve: Curves.easeOutCubic),
        const SizedBox(height: 12),
        Text(
              'Welcome to ${widget.appName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                letterSpacing: 0.15,
                height: 1.45,
              ),
            )
            .animate()
            .fadeIn(delay: 160.ms)
            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }
}

extension on _PhoneEntryScreenState {
  Widget _buildDivider(int delay) {
    return GlassContainer(
      borderRadius: 20,
      blurSigma: 12,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: Text(
          'or continue with',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
            letterSpacing: 0.3,
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay));
  }
}

/// Underscore-style digit slots: _ _ _ _ _ _ _ _ _ _
/// No text box — only slots. Smooth animation when digit is entered.
class _MobileNumberField extends StatefulWidget {
  const _MobileNumberField({required this.controller, required this.validator});

  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  State<_MobileNumberField> createState() => _MobileNumberFieldState();
}

class _MobileNumberFieldState extends State<_MobileNumberField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile number',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: _DigitSlotsInput(
            controller: widget.controller,
            focusNode: _focusNode,
            validator: widget.validator,
          ),
        ),
      ],
    );
  }
}

/// 6-digit OTP slots: _ _ _ _ _ _
class _OtpSlotsInput extends StatefulWidget {
  const _OtpSlotsInput({required this.controller});

  final TextEditingController controller;

  @override
  State<_OtpSlotsInput> createState() => _OtpSlotsInputState();
}

class _OtpSlotsInputState extends State<_OtpSlotsInput> {
  final _focusNode = FocusNode();
  static const int _slotCount = 6;
  static const double _gap = 10.0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0,
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: _slotCount,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final text = widget.controller.text;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_slotCount, (i) {
                      final hasDigit = i < text.length;
                      final digit = hasDigit ? text[i] : '_';
                      return Padding(
                        padding: EdgeInsets.only(
                          right: i < _slotCount - 1 ? _gap : 0,
                        ),
                        child: _DigitSlot(
                          key: ValueKey('otp-$i-$digit'),
                          digit: digit,
                          isFilled: hasDigit,
                          index: i,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitSlotsInput extends StatefulWidget {
  const _DigitSlotsInput({
    required this.controller,
    required this.focusNode,
    required this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(String?)? validator;

  @override
  State<_DigitSlotsInput> createState() => _DigitSlotsInputState();
}

class _DigitSlotsInputState extends State<_DigitSlotsInput> {
  static const int _slotCount = 10;
  static const double _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0,
              child: TextFormField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: TextInputType.phone,
                maxLength: _slotCount,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: widget.validator,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final text = widget.controller.text;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_slotCount, (i) {
                    final hasDigit = i < text.length;
                    final digit = hasDigit ? text[i] : '_';
                    return Padding(
                      padding: EdgeInsets.only(
                        right: i < _slotCount - 1 ? _gap : 0,
                      ),
                      child: _DigitSlot(
                        key: ValueKey('$i-$digit'),
                        digit: digit,
                        isFilled: hasDigit,
                        index: i,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitSlot extends StatefulWidget {
  const _DigitSlot({
    super.key,
    required this.digit,
    required this.isFilled,
    required this.index,
  });

  final String digit;
  final bool isFilled;
  final int index;

  @override
  State<_DigitSlot> createState() => _DigitSlotState();
}

class _DigitSlotState extends State<_DigitSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isFilled) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_DigitSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFilled && !oldWidget.isFilled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final border = widget.isFilled
            ? AppColors.primary.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.6);
        final fill = widget.isFilled
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.22);

        return Container(
          width: 36,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.isFilled
              ? ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: Text(
                      widget.digit,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                )
              : Text(
                  '_',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0,
                  ),
                ),
        );
      },
    );
  }
}

/// Apple-style glass card
class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: _radiusGlass,
      blurSigma: 22,
      child: child,
    );
  }
}

/// Apple-style glass primary button
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: GlassContainer(
        onTap: isLoading ? null : onPressed,
        borderRadius: 16,
        blurSigma: 20,
        color: AppColors.primary.withValues(alpha: 0.35),
        borderColor: AppColors.primary.withValues(alpha: 0.5),
        borderWidth: 1.5,
        padding: EdgeInsets.zero,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
    required this.delay,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final labelStyle = kIsWeb
        ? V2FontStyles.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: const Color(0xFF334155),
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: const Color(0xFF334155),
          );
    return Opacity(
          opacity: enabled ? 1 : 0.6,
          child: IgnorePointer(
            ignoring: !enabled,
            child: GlassContainer(
              onTap: onPressed,
              borderRadius: 18,
              blurSigma: 18,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              borderWidth: 1.2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 16),
                  Text(label, style: labelStyle),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
  }
}

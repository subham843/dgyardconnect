import 'package:firebase_auth/firebase_auth.dart';
import '../../core/bootstrap/firebase_bootstrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/utils/user_facing_error.dart';
import '../../core/utils/validators.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/services/saved_login_service_export.dart';
import '../../shared/widgets/brand_kit_provider.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/glass_container.dart';
import '../web_public/v2/v2_colors.dart';
import '../web_public/v2/v2_font_styles.dart';
import '../web_public/v2/v2_tokens.dart';
import '../web_public/v2/widgets/v2_brand_icons.dart';
import '../web_public/widgets/public_floating_menu.dart';

const _radiusSm = 16.0;
const _radiusGlass = 24.0;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _socialLoading = false;
  bool _rememberMe = true;
  bool _savedCredentialsLoaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // After first paint — login is already a deferred chunk; avoid blocking build().
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseBootstrap.ensureInitialized();
      });
    }
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await SavedLoginService.get();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _emailController.text = saved.email;
        _passwordController.text = saved.password;
        _rememberMe = true;
      }
      _savedCredentialsLoaded = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSuccess(UserCredential cred) async {
    final redirect = AuthPostLogin.redirectFromUri(GoRouterState.of(context).uri);
    await AuthPostLogin.complete(
      context,
      cred,
      useSuccessAnimation: true,
      redirectAfterLogin: redirect,
      onLoadingEnd: () {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _socialLoading = false;
        });
      },
    );
  }

  void _goPhoneEntry() {
    final redirect = AuthPostLogin.redirectFromUri(GoRouterState.of(context).uri);
    context.go(
      redirect != null
          ? AuthPostLogin.phoneUrlWithReturn(redirect)
          : RouteNames.phoneEntry,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService().signInWithEmailPassword(email, password);
      if (!mounted) return;
      if (cred == null) {
        setState(() => _isLoading = false);
        _showError('Sign in failed. Check email and password.');
        return;
      }
      if (_rememberMe) {
        await SavedLoginService.save(email, password);
      } else {
        await SavedLoginService.clear();
      }
      await _handleAuthSuccess(cred);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
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
                style: V2FontStyles.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          msg,
          style: V2FontStyles.inter(
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
              style: V2FontStyles.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _bgLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final appName =
        BrandKitProvider.of(context).appName ?? AppConstants.appName;

    if (kIsWeb) {
      return _buildWebLogin(context, appName);
    }

    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    _bgLight,
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Center(
                      child: BrandLogo(size: 72, color: AppColors.primary)
                          .animate()
                          .fadeIn(duration: 260.ms)
                          .scale(
                            begin: const Offset(0.98, 0.98),
                            end: const Offset(1, 1),
                            curve: Curves.easeOutCubic,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: V2FontStyles.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.8,
                            height: 1.15,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 260.ms)
                        .slideY(
                          begin: 0.06,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 8),
                    Text(
                          'Sign in to continue to $appName',
                          textAlign: TextAlign.center,
                          style: V2FontStyles.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.1,
                            height: 1.4,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 140.ms, duration: 260.ms)
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 32),
                    GlassContainer(
                          borderRadius: _radiusGlass,
                          blurSigma: 22,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LoginSocialButton(
                                label: 'Continue with Google',
                                icon: V2BrandIcons.google(size: 22),
                                color: const Color(0xFF4285F4),
                                onPressed: _socialLoading
                                    ? null
                                    : _signInWithGoogle,
                                delay: 200,
                              ),
                              const SizedBox(height: 14),
                              _LoginSocialButton(
                                label: 'Continue with Facebook',
                                icon: V2BrandIcons.facebook(size: 22),
                                color: const Color(0xFF1877F2),
                                onPressed: _socialLoading
                                    ? null
                                    : _signInWithFacebook,
                                delay: 260,
                              ),
                              const SizedBox(height: 28),
                              GlassContainer(
                                borderRadius: 20,
                                blurSigma: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: Center(
                                  child: Text(
                                    'or sign in with email',
                                    style: V2FontStyles.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: 300.ms),
                              const SizedBox(height: 28),
                              TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    style: V2FontStyles.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.1,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    decoration:
                                        _loginInputDecoration(
                                          AppConstants.emailHint,
                                        ).copyWith(
                                          hintText: 'you@example.com',
                                          prefixIcon: Icon(
                                            Icons.mail_outline_rounded,
                                            size: 22,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                    validator: Validators.email,
                                  )
                                  .animate()
                                  .fadeIn(delay: 340.ms)
                                  .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  ),
                              const SizedBox(height: 18),
                              TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    style: V2FontStyles.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.1,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    decoration:
                                        _loginInputDecoration(
                                          AppConstants.passwordHint,
                                        ).copyWith(
                                          prefixIcon: Icon(
                                            Icons.lock_outline_rounded,
                                            size: 22,
                                            color: Colors.grey.shade500,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              size: 22,
                                              color: Colors.grey.shade500,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                          ),
                                        ),
                                    validator: Validators.password,
                                  )
                                  .animate()
                                  .fadeIn(delay: 380.ms)
                                  .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  ),
                              if (_savedCredentialsLoaded) ...[
                                const SizedBox(height: 16),
                                GlassContainer(
                                  borderRadius: 14,
                                  blurSigma: 14,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (v) => setState(
                                            () => _rememberMe = v ?? true,
                                          ),
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _rememberMe = !_rememberMe,
                                        ),
                                        child: Text(
                                          AppConstants.rememberEmailPassword,
                                          style: V2FontStyles.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(delay: 420.ms),
                                const SizedBox(height: 24),
                              ] else
                                const SizedBox(height: 24),
                              _LoginGradientButton(
                                    onPressed: _isLoading ? null : _submit,
                                    isLoading: _isLoading,
                                    label: 'Sign in',
                                  )
                                  .animate()
                                  .fadeIn(delay: 440.ms)
                                  .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 160.ms, duration: 550.ms)
                        .slideY(
                          begin: 0.04,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 24),
                    GlassContainer(
                      borderRadius: 20,
                      blurSigma: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          TextButton(
                            onPressed: _goPhoneEntry,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Text(
                              AppConstants.usePhoneNumber,
                              style: V2FontStyles.inter(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppConstants.noAccount,
                            textAlign: TextAlign.center,
                            style: V2FontStyles.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => context.go(RouteNames.phoneEntry),
                                child: Text(
                                  AppConstants.registerAsDealer,
                                  style: V2FontStyles.inter(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                ' · ',
                                style: V2FontStyles.inter(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go(RouteNames.phoneEntry),
                                child: Text(
                                  AppConstants.registerAsTechnician,
                                  style: V2FontStyles.inter(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebLogin(BuildContext context, String appName) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.lg;

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
                    V2Colors.emberSubtle.withValues(alpha: 0.35),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -120,
                    right: -90,
                    child: _WebBlurOrb(
                      color: V2Colors.plasma.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    bottom: -150,
                    left: -110,
                    child: _WebBlurOrb(
                      color: V2Colors.aurora.withValues(alpha: 0.16),
                      size: 360,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              v.gutter,
              v.r<double>(xs: 32, md: 48, lg: 56),
              v.gutter,
              PublicFloatingMenu.contentBottomInset(context),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _WebLoginStory(appName: appName)),
                          const SizedBox(width: 46),
                          SizedBox(width: 480, child: _webLoginCard(appName)),
                        ],
                      )
                    : Column(
                        children: [
                          _WebLoginStory(appName: appName),
                          const SizedBox(height: 34),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _webLoginCard(appName),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webLoginCard(String appName) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          boxShadow: V2Colors.paperHigh,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BrandLogo(size: 44, color: V2Colors.inkSaaS),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: V2FontStyles.inter(
                          color: V2Colors.inkSaaS,
                          fontSize: 25,
                          letterSpacing: -0.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Sign in to continue to $appName',
                        style: V2FontStyles.inter(
                          color: V2Colors.inkMutedSaaS,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _WebSocialButton(
              label: 'Continue with Google',
              icon: V2BrandIcons.google(size: 19),
              color: const Color(0xFF4285F4),
              onPressed: _socialLoading ? null : _signInWithGoogle,
            ),
            const SizedBox(height: 12),
            _WebSocialButton(
              label: 'Continue with Facebook',
              icon: V2BrandIcons.facebook(size: 19),
              color: const Color(0xFF1877F2),
              onPressed: _socialLoading ? null : _signInWithFacebook,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider(color: V2Colors.borderSubtle)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or sign in with email',
                    style: V2FontStyles.inter(
                      color: V2Colors.inkMutedSaaS,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: V2Colors.borderSubtle)),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _webInputDecoration(
                label: AppConstants.emailHint,
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration:
                  _webInputDecoration(
                    label: AppConstants.passwordHint,
                    hint: 'Enter password',
                    icon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: V2Colors.inkMutedSaaS,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
              validator: Validators.password,
            ),
            if (_savedCredentialsLoaded) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: V2Colors.ember,
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Text(
                        AppConstants.rememberEmailPassword,
                        style: V2FontStyles.inter(
                          color: V2Colors.inkMutedSaaS,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              const SizedBox(height: 18),
            const SizedBox(height: 10),
            _WebPrimaryButton(
              label: 'Sign in',
              isLoading: _isLoading,
              onTap: _isLoading ? null : _submit,
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _goPhoneEntry,
                  child: const Text('Use phone number'),
                ),
                TextButton(
                  onPressed: () => context.go(RouteNames.registerDealer),
                  child: const Text('Register as dealer'),
                ),
                TextButton(
                  onPressed: () => context.go(RouteNames.registerTechnician),
                  child: const Text('Register as technician'),
                ),
                TextButton(
                  onPressed: () => context.go(RouteNames.bosTrialSignup),
                  child: const Text('AI Business OS trial'),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.05, end: 0),
    );
  }

  InputDecoration _webInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: V2Colors.inkMutedSaaS),
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: V2Colors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: V2Colors.ember, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }

  InputDecoration _loginInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: V2FontStyles.inter(
        color: const Color(0xFF64748B),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }
}

class _WebLoginStory extends StatelessWidget {
  const _WebLoginStory({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Column(
      crossAxisAlignment: v.isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: V2Colors.paperLow,
          ),
          child: Text(
            'DG Yard Connect Web App',
            style: V2FontStyles.inter(
              color: V2Colors.inkMutedSaaS,
              fontSize: 12,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'One secure sign in for shop, calculator and connect.',
          textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
          style: V2FontStyles.inter(
            color: V2Colors.inkSaaS,
            fontSize: v.r<double>(xs: 38, sm: 44, md: 58, lg: 70),
            height: 0.96,
            letterSpacing: -3,
            fontWeight: FontWeight.w800,
          ),
        ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Text(
            'Access $appName with the same account. Continue to manage orders, BOQ calculators, support and DG Yard Connect workflows.',
            textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
            style: V2FontStyles.inter(
              color: V2Colors.inkMutedSaaS,
              fontSize: v.r<double>(xs: 16, md: 18),
              height: 1.62,
              fontWeight: FontWeight.w500,
            ),
          ),
        ).animate(delay: 90.ms).fadeIn(duration: 520.ms),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: v.isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: const [
            _WebFeaturePill(Icons.storefront_rounded, 'Shop'),
            _WebFeaturePill(Icons.calculate_rounded, 'BOQ Calculator'),
            _WebFeaturePill(Icons.engineering_rounded, 'Connect'),
            _WebFeaturePill(Icons.support_agent_rounded, 'Support'),
          ],
        ).animate(delay: 150.ms).fadeIn(duration: 520.ms),
      ],
    );
  }
}

class _WebFeaturePill extends StatelessWidget {
  const _WebFeaturePill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: V2Colors.borderSubtle),
        boxShadow: V2Colors.paperLow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: V2Colors.emberDeep),
          const SizedBox(width: 7),
          Text(
            label,
            style: V2FontStyles.inter(
              color: V2Colors.inkSaaS,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSocialButton extends StatefulWidget {
  const _WebSocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  State<_WebSocialButton> createState() => _WebSocialButtonState();
}

class _WebSocialButtonState extends State<_WebSocialButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: V2.d,
          curve: V2.eOut,
          transform: Matrix4.translationValues(
            0,
            _hover && enabled ? -2 : 0,
            0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: V2Colors.borderSubtle),
            boxShadow: _hover && enabled ? V2Colors.paperLow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  color: V2Colors.inkSaaS,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebPrimaryButton extends StatefulWidget {
  const _WebPrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  State<_WebPrimaryButton> createState() => _WebPrimaryButtonState();
}

class _WebPrimaryButtonState extends State<_WebPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          height: 54,
          duration: V2.d,
          curve: V2.eOut,
          transform: Matrix4.translationValues(
            0,
            _hover && widget.onTap != null ? -2 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: V2Colors.inkSaaS,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _hover ? V2Colors.paperMid : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: V2FontStyles.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WebBlurOrb extends StatelessWidget {
  const _WebBlurOrb({required this.color, this.size = 300});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _LoginSocialButton extends StatelessWidget {
  const _LoginSocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.delay,
  });

  final String label;
  final Widget icon;
  final Color color;
  final VoidCallback? onPressed;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
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
                  icon,
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: V2FontStyles.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }
}

/// Apple-style glass CTA: frosted glass with primary tint.
class _LoginGradientButton extends StatelessWidget {
  const _LoginGradientButton({
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
                  style: V2FontStyles.inter(
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

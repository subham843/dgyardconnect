import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/supabase/supabase_auth_service.dart';
import 'auth_post_login.dart';

/// Web auth — no [google_sign_in], [flutter_facebook_auth], or [FcmService] imports
/// (keeps deferred auth chunks small; avoids gsi/client until user taps sign-in).
class AuthService {
  static ConfirmationResult? _webPhoneConfirmation;
  static RecaptchaVerifier? _recaptchaVerifier;

  User? get currentUser =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  Stream<User?> get authStateChanges => Firebase.apps.isEmpty
      ? const Stream.empty()
      : FirebaseAuth.instance.authStateChanges();

  Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    AuthPostLogin.clearSessionRole();
    await FirebaseAuth.instance.signOut();
    await SupabaseAuthService.instance.clearSession();
  }

  Future<void> deleteAccount() async {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFunctions.instance.httpsCallable('deleteMyAccount').call();
      return;
    } catch (_) {}

    await user.delete();
  }

  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } catch (e, st) {
      debugPrint('AuthService.signInWithGoogle: $e\n$st');
      return null;
    }
  }

  Future<UserCredential?> signInWithFacebook() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      return FirebaseAuth.instance.signInWithPopup(FacebookAuthProvider());
    } catch (e, st) {
      debugPrint('AuthService.signInWithFacebook: $e\n$st');
      return null;
    }
  }

  void _clearRecaptcha() {
    try {
      _recaptchaVerifier?.clear();
    } catch (_) {}
    _recaptchaVerifier = null;
  }

  /// Builds a verifier bound to `#recaptcha-container` (outside Flutter host).
  RecaptchaVerifier _createRecaptchaVerifier() {
    _clearRecaptcha();
    final auth = FirebaseAuth.instance;
    final verifier = RecaptchaVerifier(
      auth: FirebaseAuthPlatform.instanceFor(
        app: auth.app,
        pluginConstants: auth.pluginConstants,
      ),
      container: 'recaptcha-container',
      size: RecaptchaVerifierSize.normal,
      theme: RecaptchaVerifierTheme.light,
      onError: (e) {
        debugPrint('RecaptchaVerifier.onError: ${e.code} ${e.message}');
      },
      onExpired: () {
        debugPrint('RecaptchaVerifier.onExpired');
        _clearRecaptcha();
      },
    );
    _recaptchaVerifier = verifier;
    return verifier;
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    void Function(String error)? verificationFailed,
    void Function(PhoneAuthCredential credential)? verificationCompleted,
  }) async {
    if (Firebase.apps.isEmpty) {
      verificationFailed?.call(
        'Sign-in service is not ready. Please wait a moment and try again.',
      );
      return;
    }
    try {
      final verifier = _createRecaptchaVerifier();
      _webPhoneConfirmation = await FirebaseAuth.instance.signInWithPhoneNumber(
        phoneNumber,
        verifier,
      );
      codeSent(_webPhoneConfirmation!.verificationId);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.verifyPhoneNumber: ${e.code} ${e.message}');
      _clearRecaptcha();
      verificationFailed?.call(_mapAuthError(e));
    } catch (e, st) {
      debugPrint('AuthService.verifyPhoneNumber: $e\n$st');
      _clearRecaptcha();
      verificationFailed?.call(
        'Unable to send OTP right now. Please try again in a few moments.',
      );
    }
  }

  Future<UserCredential?> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    if (Firebase.apps.isEmpty) return null;
    final confirmation = _webPhoneConfirmation;
    if (confirmation == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'OTP session expired. Please request OTP again.',
      );
    }
    try {
      final cred = await confirmation.confirm(smsCode);
      _webPhoneConfirmation = null;
      _clearRecaptcha();
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'captcha-check-failed':
      case 'invalid-app-credential':
        return 'Security check failed. Complete the reCAPTCHA checkbox, '
            'refresh the page, and try again. '
            'If this keeps happening, ask admin to add this site domain under '
            'Firebase → Authentication → Settings → Authorized domains.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      case 'quota-exceeded':
        return 'OTP quota exceeded. Please try again later.';
      case 'network-request-failed':
        return 'Network issue detected. Please check your internet and retry.';
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      case 'session-expired':
        return 'OTP session expired. Please request a new OTP.';
      default:
        return e.message ?? 'Verification failed. Please try again.';
    }
  }
}

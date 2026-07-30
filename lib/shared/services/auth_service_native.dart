import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/oauth_config.dart';
import '../../core/supabase/supabase_auth_service.dart';
import 'auth_post_login.dart';
import 'fcm_service.dart';

class AuthService {
  static Future<void>? _googleSignInInitialized;
  static ConfirmationResult? _webPhoneConfirmation;
  User? get currentUser =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  Stream<User?> get authStateChanges => Firebase.apps.isEmpty
      ? const Stream.empty()
      : FirebaseAuth.instance.authStateChanges();

  Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    AuthPostLogin.clearSessionRole();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FcmService.clearCurrentRole();
    if (uid != null) await FcmService.removeTokenFromUser(uid);
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    await SupabaseAuthService.instance.clearSession();
  }

  Future<void> deleteAccount() async {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    await FcmService.clearCurrentRole();
    await FcmService.removeTokenFromUser(uid);

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

  static Future<void> _ensureGoogleSignInInitialized() async {
    _googleSignInInitialized ??= GoogleSignIn.instance.initialize(
      serverClientId: OAuthConfig.googleWebClientId.isEmpty
          ? null
          : OAuthConfig.googleWebClientId,
    );
    await _googleSignInInitialized!;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      await _ensureGoogleSignInInitialized();
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();
      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) {
        debugPrint(
          'AuthService.signInWithGoogle: idToken is null. Add SHA-1/SHA-256 in '
          'Firebase for Android, re-download google-services.json, and/or set '
          'OAuthConfig.googleWebClientId to your Web client ID.',
        );
        return null;
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      debugPrint('AuthService.signInWithGoogle: $e');
      return null;
    } catch (e, st) {
      debugPrint('AuthService.signInWithGoogle: $e\n$st');
      return null;
    }
  }

  Future<UserCredential?> signInWithFacebook() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
        loginTracking: LoginTracking.enabled,
      );
      if (loginResult.status != LoginStatus.success) return null;
      final accessToken = loginResult.accessToken;
      if (accessToken == null) return null;
      final credential = FacebookAuthProvider.credential(
        accessToken.tokenString,
      );
      return FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e, st) {
      debugPrint('AuthService.signInWithFacebook: $e\n$st');
      return null;
    }
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
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (cred) {
          verificationCompleted?.call(cred);
        },
        verificationFailed: (e) {
          verificationFailed?.call(_mapAuthError(e));
        },
        codeSent: (verId, _) {
          codeSent(verId);
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 120),
      );
    } on FirebaseAuthException catch (e) {
      verificationFailed?.call(_mapAuthError(e));
    } catch (_) {
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
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
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
        return 'Security check failed. Refresh the page and try again.';
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

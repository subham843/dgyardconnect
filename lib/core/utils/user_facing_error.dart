import 'package:firebase_auth/firebase_auth.dart';

/// Turns exceptions (Firebase Auth, Firestore internal web errors, etc.)
/// into short, safe messages for dialogs — never raw stack traces.
String userFacingError(Object error) {
  if (error is FirebaseAuthException) {
    return _firebaseAuthMessage(error);
  }
  final raw = error.toString();
  if (_isFirestoreOrSdkNoise(raw) || _looksLikeStackTrace(raw)) {
    return _genericConnectivityMessage;
  }
  final oneLine = _firstMeaningfulLine(raw);
  if (oneLine.length > 240) {
    return '${oneLine.substring(0, 237)}…';
  }
  return oneLine.isEmpty ? _genericConnectivityMessage : oneLine;
}

const String _genericConnectivityMessage =
    'Something went wrong while connecting to our servers. '
    'Check your internet connection, refresh the page, and try again. '
    'If it keeps happening, wait a few minutes and retry.';

String _firebaseAuthMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support if you need help.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password. Please try again.';
    case 'too-many-requests':
      return 'Too many sign-in attempts. Please wait a few minutes and try again.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled. Please contact support.';
    case 'requires-recent-login':
      return 'For security, please sign in again and retry.';
    default:
      final msg = e.message?.trim();
      if (msg != null && msg.isNotEmpty && msg.length < 120 && !_looksLikeStackTrace(msg)) {
        return msg;
      }
      return 'Sign-in could not be completed. Please try again.';
  }
}

bool _isFirestoreOrSdkNoise(String s) {
  final l = s.toLowerCase();
  return l.contains('internal assertion') ||
      l.contains('unexpected state') ||
      l.contains('firestore') && (l.contains('firebase') || l.contains('assertion')) ||
      l.contains('firebase-firestore') ||
      l.contains('gstatic.com/firebase') ||
      l.contains('firebasejs') ||
      l.contains('context:') && l.contains('pc":') ||
      l.contains('cloud.firestore');
}

bool _looksLikeStackTrace(String s) {
  final l = s.toLowerCase();
  return l.contains('http://') ||
      l.contains('https://') ||
      l.contains('.dart:') ||
      l.contains('package:') ||
      l.contains('at ') && l.contains('(') ||
      l.contains('stack') && l.contains('trace');
}

String _firstMeaningfulLine(String s) {
  final lines = s.split(RegExp(r'\r?\n'));
  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (t.startsWith('Exception:')) {
      return t.substring('Exception:'.length).trim();
    }
    if (t.startsWith('Error:')) {
      return t.substring('Error:'.length).trim();
    }
    return t;
  }
  return s.trim();
}

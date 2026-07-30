import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Safe Firebase Auth accessors for web public UI.
///
/// Web cold-start does **not** init Firebase on the critical path
/// ([main_bootstrap_web.dart]). Calling [FirebaseAuth.instance] before
/// [FirebaseBootstrap.ensureInitialized] throws a TypeError on web.
abstract final class FirebaseAuthSafe {
  static bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static User? get currentUser {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  static bool get isSignedIn => currentUser != null;

  static Stream<User?> authStateChanges() {
    try {
      if (Firebase.apps.isEmpty) return const Stream<User?>.empty();
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return const Stream<User?>.empty();
    }
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_options.dart' as fo;

/// Lazy Firebase Core init — no Firestore/Auth SDK side-effects until first use.
abstract final class FirebaseBootstrap {
  static Future<void>? _future;

  static bool get isReady => Firebase.apps.isNotEmpty;

  static Future<void> ensureInitialized() {
    _future ??= _init();
    return _future!;
  }

  static Future<void> _init() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(
        options: fo.DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase not configured: $e');
      rethrow;
    }
  }
}

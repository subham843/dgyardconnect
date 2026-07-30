import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Firestore web settings — call only from routes that use Firestore (not auth-only).
Future<void> configureWebFirestore() async {
  if (!kIsWeb) return;
  await FirebaseBootstrap.ensureInitialized();
  if (Firebase.apps.isEmpty) return;
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
}

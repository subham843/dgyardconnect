import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore web SDK can throw INTERNAL ASSERTION (b815/ca9) after hot restart
/// or corrupted IndexedDB — see firebase-js-sdk issues #9491, #10008.
bool isFirestoreInternalAssertion(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('internal assertion') ||
      s.contains('unexpected state') ||
      (s.contains('firestore') && s.contains('assertion')) ||
      s.contains('firebase-firestore.js');
}

/// One-shot reads for routing/auth guards. On web uses server source to avoid
/// stale or broken local cache after hot restart.
Future<DocumentSnapshot<Map<String, dynamic>>?> safeGetUserDocument(
  String uid, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (uid.isEmpty) return null;
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);
  final options = kIsWeb ? const GetOptions(source: Source.server) : const GetOptions();

  try {
    return await ref.get(options).timeout(timeout);
  } on TimeoutException {
    debugPrint('safeGetUserDocument: timed out after ${timeout.inSeconds}s');
    return null;
  } catch (e, st) {
    if (!isFirestoreInternalAssertion(e)) {
      debugPrint('safeGetUserDocument failed: $e');
      debugPrint('$st');
      rethrow;
    }
    debugPrint('safeGetUserDocument: Firestore internal error, skipping guard read ($e)');
    return null;
  }
}

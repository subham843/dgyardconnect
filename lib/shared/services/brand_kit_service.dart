import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/brand_kit_model.dart';
import 'firestore_service.dart';

/// Fetches and caches brand kit from Firestore. App uses this for dynamic branding.
class BrandKitService {
  BrandKitService._();
  static final BrandKitService _instance = BrandKitService._();
  static BrandKitService get instance => _instance;

  static final _broadcast = StreamController<BrandKitModel>.broadcast();
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _firestoreSub;
  static Timer? _webPollTimer;
  static bool _streamBootstrapped = false;
  static BrandKitModel? _cached;

  BrandKitModel? get current => _cached;

  /// Initialize and listen to brand kit changes (native only).
  void init() {
    if (kIsWeb) return;
    if (!FirestoreService.isAvailable) return;
    _firestoreSub?.cancel();
    _firestoreSub = FirestoreService.brandKit().snapshots().listen((snap) {
      final kit = BrandKitModel.fromMap(snap.data());
      _cached = kit;
      _emit(kit);
    }, onError: (_) {});
  }

  /// One-time fetch (for screens that need it without listener).
  static Future<BrandKitModel> fetch() async {
    if (!FirestoreService.isAvailable) return const BrandKitModel();
    try {
      final snap = await FirestoreService.brandKit().get();
      final kit = BrandKitModel.fromMap(snap.data());
      _cached = kit;
      return kit;
    } catch (_) {
      return const BrandKitModel();
    }
  }

  /// Stream of brand kit updates — emits immediately after save on web.
  static Stream<BrandKitModel> stream() async* {
    _ensureStreamBootstrapped();
    final cached = _cached;
    if (cached != null) {
      yield cached;
    }
    yield* _broadcast.stream;
  }

  /// Save brand kit to Firestore and push update to all listeners immediately.
  static Future<void> save(BrandKitModel kit) async {
    if (!FirestoreService.isAvailable) return;
    await FirestoreService.brandKit().set(kit.toMap(), SetOptions(merge: true));
    _cached = kit;
    _emit(kit);
    // Re-fetch so merge/server fields stay in sync with what public site reads.
    unawaited(_refreshAndEmit());
  }

  /// Force refresh from Firestore (e.g. after admin save).
  static Future<void> refresh() => _refreshAndEmit();

  /// Push an in-memory kit to all listeners (e.g. right after asset upload).
  static void cacheAndEmit(BrandKitModel kit) {
    _cached = kit;
    _emit(kit);
  }

  static Future<void> _refreshAndEmit() async {
    final kit = await fetch();
    _emit(kit);
  }

  static void _emit(BrandKitModel kit) {
    if (_broadcast.isClosed) return;
    _broadcast.add(kit);
  }

  static void _ensureStreamBootstrapped() {
    if (_streamBootstrapped) return;
    _streamBootstrapped = true;

    unawaited(_refreshAndEmit());

    if (kIsWeb) {
      // Public web: no Firestore listener (avoids auth iframe + timeout on cold start).
      if (_cached == null) {
        unawaited(fetch());
      }
      return;
    }

    if (!FirestoreService.isAvailable) return;
    _firestoreSub?.cancel();
    _firestoreSub = FirestoreService.brandKit().snapshots().listen((snap) {
      final kit = BrandKitModel.fromMap(snap.data());
      _cached = kit;
      _emit(kit);
    }, onError: (_) {});
  }

  void dispose() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _webPollTimer?.cancel();
    _webPollTimer = null;
    _cached = null;
  }
}

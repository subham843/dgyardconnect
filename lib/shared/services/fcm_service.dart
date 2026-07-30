import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:android_intent_plus/android_intent.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../router/app_router.dart';
import '../../core/config/firebase_options.dart' as fo;
import '../../core/constants/route_names.dart';
import '../../features/shared/chat_screen.dart' as shared_chat;
import 'auth_post_login.dart';
import 'firestore_service.dart';

const String _keyCurrentRole = 'fcm_current_user_role';
const String _keyPushEnabled = 'prefs_push_enabled';
const String _keyDeepLinkLockUntilMs = 'fcm_deeplink_lock_until_ms';

const String _jobRequestsChannelId = 'job_requests_urgent';
const int _jobNotificationId = 1001;

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

String _stringify(Object? v) => v == null ? '' : v.toString();

String _readImageUrl(Map<String, dynamic> data) {
  final a = _stringify(data['image_url']).trim();
  final b = _stringify(data['imageUrl']).trim();
  final c = _stringify(data['image']).trim();
  return a.isNotEmpty ? a : (b.isNotEmpty ? b : c);
}

Future<Uint8List?> _downloadImageBytes(String url) async {
  if (kIsWeb) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, 'dgyardconnect');
    final res = await req.close().timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final bytes = await consolidateHttpClientResponseBytes(res).timeout(const Duration(seconds: 10));
    if (bytes.isEmpty) return null;
    // basic size guard (~2.5 MB)
    if (bytes.lengthInBytes > 2500000) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// Encode payload into a compact JSON string for local notification tap handling.
String _encodePayload(Map<String, dynamic> data) {
  try {
    return jsonEncode(data);
  } catch (_) {
    // fallback to legacy simple payload
    final jobId = _stringify(data['jobId'] ?? data['job_id']);
    final type = _stringify(data['type']);
    final target = _stringify(data['target']);
    return _makePayload(jobId, type.isEmpty ? 'job_request' : type, target.isEmpty ? 'technician' : target);
  }
}

/// Title and body for job notifications by type. Same full-screen ring for dealer and technician.
(String, String) _notificationContent(String type, String target) {
  switch (type) {
    case 'chat_message':
      return ('New message', 'You have a new chat message. Tap to view.');
    case 'job_request':
      return ('New job request', 'You have a new job. Tap to accept or reject.');
    case 'technician_accepted':
      return ('Technician accepted', 'A technician accepted your job. Tap to view and respond.');
    case 'technician_bid':
      return ('Technician bid', 'You have a new bid. Tap to accept, counter, or reject.');
    case 'technician_rejected_offer':
      return (
        'Technician rejected your offer',
        'Search for other technician for your job. Next technician has been notified.',
      );
    case 'dealer_counter':
      return ('Dealer counter offer', 'Dealer sent a counter offer. Tap to respond.');
    case 'dealer_accept_bid':
      return ('Bid accepted', 'Your bid was accepted. Tap to view job.');
    case 'payment_ready':
      return ('Proceed to payment', 'Rate agreed. Tap to complete payment.');
    case 'payment_received':
      return ('Payment received', 'Your job is started now. Tap to view.');
    case 'material_list':
      return ('Material list updated', 'Technician provided material list. Tap to review.');
    case 'proof_uploaded':
      return ('Proof uploaded', 'Technician uploaded a proof photo. Tap to view.');
    case 'job_pending_confirm':
      return ('Job complete – confirm', 'Technician completed the job. Tap to confirm.');
    case 'job_completed':
      return ('Job completed', 'Job has been completed. Tap to view and rate.');
    case 'warranty_claim':
      return ('Warranty claim', 'A dealer raised a warranty claim – visit required. Respond within 24 hours.');
    case 'mp_seller_order_request':
      return ('Marketplace order', 'You have a new line item. Tap to accept or reject.');
    default:
      return ('Job update', 'You have a job update. Tap to view.');
  }
}

/// Legacy payload format: jobId|type|target for routing when tapped.
String _makePayload(String jobId, String type, String target) =>
    '$jobId|$type|$target';

Map<String, dynamic>? _decodePayload(String payload) {
  final p = payload.trim();
  if (p.isEmpty) return null;
  if (p.startsWith('{')) {
    try {
      final decoded = jsonDecode(p);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
  }
  // legacy: jobId|type|target
  final parts = p.split('|');
  final jobId = parts.isNotEmpty ? parts[0] : '';
  final type = parts.length > 1 ? parts[1] : '';
  final target = parts.length > 2 ? parts[2] : '';
  if (jobId.isEmpty && type.isEmpty && target.isEmpty) return null;
  return <String, dynamic>{
    if (jobId.isNotEmpty) 'jobId': jobId,
    if (type.isNotEmpty) 'type': type,
    if (target.isNotEmpty) 'target': target,
  };
}

String _readType(Map<String, dynamic> data) {
  final t = _stringify(data['type']).trim();
  final s = _stringify(data['screen']).trim();
  if (t.isNotEmpty) return t;
  if (s.isNotEmpty) return s;
  return 'general';
}

String _readJobId(Map<String, dynamic> data) {
  final a = _stringify(data['job_id']).trim();
  final b = _stringify(data['jobId']).trim();
  final c = _stringify(data['jobID']).trim();
  return a.isNotEmpty ? a : (b.isNotEmpty ? b : c);
}

String _readTarget(Map<String, dynamic> data) {
  final t = _stringify(data['target']).trim().toLowerCase();
  if (t == 'dealer' || t == 'technician' || t == 'admin') return t;
  return '';
}

/// Persists notification to Firestore for in-app notification center. Fire-and-forget.
void _saveNotificationToFirestore(String title, String body, String type, String jobId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || !FirestoreService.isAvailable) return;
  try {
    FirestoreService.notifications(uid).add({
      'title': title,
      'body': body,
      'type': type,
      'jobId': jobId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

/// Saves notification from payload (JSON preferred, legacy supported).
void _saveNotificationFromPayload(String payload) {
  final data = _decodePayload(payload);
  if (data == null) return;
  final type = _readType(data);
  final jobId = _readJobId(data);
  final title = _stringify(data['title']).trim().isNotEmpty ? _stringify(data['title']).trim() : 'Notification';
  final body = _stringify(data['body']).trim();

  if (jobId.isNotEmpty) {
    _saveNotificationToFirestore(title, body, type, jobId);
    return;
  }
  // Save general notifications too (use empty jobId)
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || !FirestoreService.isAvailable) return;
  try {
    FirestoreService.notifications(uid).add({
      'title': title,
      'body': body,
      'type': type,
      'jobId': '',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

/// Returns true only if the notification target matches the currently logged-in user's role.
Future<bool> _shouldShowJobNotification(String target) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pushEnabled = prefs.getBool(_keyPushEnabled);
    if (pushEnabled == false) return false;
    final role = prefs.getString(_keyCurrentRole);
    if (role == null || role.isEmpty) return true; // No role stored: show (legacy)
    return role == target;
  } catch (_) {
    return true;
  }
}

/// Top-level handler for FCM when app is in background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: fo.DefaultFirebaseOptions.currentPlatform);
  final data = message.data;
  final type = _stringify(data['type']).trim();
  final target = _stringify(data['target']).trim().isEmpty ? 'technician' : _stringify(data['target']).trim();
  final jobId = _stringify(data['jobId']).trim().isEmpty ? _stringify(data['job_id']).trim() : _stringify(data['jobId']).trim();
  if (!kIsWeb && Platform.isAndroid) {
    if (jobId.isNotEmpty) {
      final shouldShow = await _shouldShowJobNotification(target);
      if (!shouldShow) return;
    }
    final title = message.notification?.title ?? _stringify(data['title']).trim();
    final body = message.notification?.body ?? _stringify(data['body']).trim();
    final (fallbackTitle, fallbackBody) = _notificationContent(type.isEmpty ? 'job_request' : type, target);
    final showTitle = title.isEmpty ? fallbackTitle : title;
    final showBody = body.isEmpty ? fallbackBody : body;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: initSettings);
    const channel = AndroidNotificationChannel(
      _jobRequestsChannelId,
      'Job alerts',
      description: 'Ring and vibration for all job notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    final imageUrl = _readImageUrl(data);
    final imageBytes = imageUrl.isEmpty ? null : await _downloadImageBytes(imageUrl);
    final style = imageBytes == null
        ? null
        : BigPictureStyleInformation(
            ByteArrayAndroidBitmap(imageBytes),
            contentTitle: showTitle,
            summaryText: showBody,
            hideExpandedLargeIcon: true,
          );

    await plugin.show(
      id: _jobNotificationId,
      title: showTitle,
      body: showBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _jobRequestsChannelId,
          'Job alerts',
          channelDescription: 'Ring and vibration for all job notifications',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/ic_notification',
          playSound: true,
          enableVibration: true,
          enableLights: true,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.message,
          audioAttributesUsage: AudioAttributesUsage.notification,
          ongoing: false,
          vibrationPattern: Int64List.fromList(<int>[0, 300, 150, 300]),
          styleInformation: style,
        ),
      ),
      payload: _encodePayload({
        ...data,
        if (showTitle.isNotEmpty) 'title': showTitle,
        if (showBody.isNotEmpty) 'body': showBody,
      }),
    );
  }
}

class FcmService {
  static bool _initialized = false;
  static const Duration _deepLinkLockWindow = Duration(seconds: 6);

  /// Prevents Splash auto-navigation from overriding a notification deep-link.
  static Future<void> markDeepLinkHandled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.now().add(_deepLinkLockWindow).millisecondsSinceEpoch;
      await prefs.setInt(_keyDeepLinkLockUntilMs, until);
    } catch (_) {}
  }

  static Future<bool> isDeepLinkLockActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_keyDeepLinkLockUntilMs) ?? 0;
      return DateTime.now().millisecondsSinceEpoch <= until;
    } catch (_) {
      return false;
    }
  }

  /// Call from main() after Firebase.initializeApp(). Sets up foreground handler,
  /// background handler, and creates job_requests channel.
  static Future<void> init() async {
    if (Firebase.apps.isEmpty || _initialized) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // On web, do not block startup behind notification permission prompt.
    // Permission can be requested later from explicit user action.
    if (!kIsWeb) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    if (!kIsWeb && Platform.isAndroid) {
      await Permission.notification.request();
    }
    if (!kIsWeb && Platform.isAndroid) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
    const channel = AndroidNotificationChannel(
        _jobRequestsChannelId,
        'Job alerts',
        description: 'Ring and vibration for all job notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
    await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    cancelJobNotification();
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _saveNotificationFromPayload(payload);
      markDeepLinkHandled();
      _navigateFromPayload(payload);
    }
  }

  /// Called from main when app launches from notification (terminated state).
  static Future<void> navigateFromLaunchPayload(String payload) async {
    _saveNotificationFromPayload(payload);
    await markDeepLinkHandled();
    await _navigateFromPayload(payload);
  }

  /// Called from main when app launches from FCM `getInitialMessage()` (terminated state).
  static Future<void> navigateFromInitialMessage(RemoteMessage message) async {
    await markDeepLinkHandled();
    await _navigateFromData(message.data, notification: message.notification);
  }

  /// Used by the in-app notification center to open the relevant screen.
  /// Provide the stored notification fields (type/jobId/title/body) and optional target.
  static Future<void> navigateFromNotificationCenter({
    required String type,
    required String jobId,
    required String title,
    required String body,
    String? target,
  }) async {
    await markDeepLinkHandled();
    final data = <String, dynamic>{
      'type': type,
      'screen': type,
      'title': title,
      'body': body,
      if (jobId.isNotEmpty) 'jobId': jobId,
      if (jobId.isNotEmpty) 'job_id': jobId,
      if (target != null && target.isNotEmpty) 'target': target,
    };
    await _navigateFromData(data, notification: null);
  }

  /// Called from main when app launches from FCM getInitialMessage.
  static Future<void> navigateFromJobData(String jobId, String type, String target) async {
    final (title, body) = _notificationContent(type, target);
    _saveNotificationToFirestore(title, body, type, jobId);
    await _navigateFromJobDataIfRoleMatches(jobId, type, target);
  }

  /// Cancels the ongoing job notification (stops ring/vibration). Call when user accepts, rejects, or opens the notification.
  static Future<void> cancelJobNotification() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _localNotifications.cancel(id: _jobNotificationId);
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  /// Save current user role so job notifications are shown only when target matches.
  static Future<void> saveCurrentRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentRole, role);
    } catch (_) {}
  }

  /// Clear stored role on sign out.
  static Future<void> clearCurrentRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCurrentRole);
    } catch (_) {}
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    // New unified deep-link payload handling.
    final type = message.data['type'] as String?;
    if (type == 'otp') {
      // OTP messages are informational and should never auto-navigate away
      // from the user's current flow (e.g. finish job OTP dialog).
      final body = message.notification?.body ?? '';
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body.isEmpty ? 'OTP received.' : body),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      // Do not save as job notification; do not navigate.
      return;
    }
    if (type == 'approval') {
      final title = message.notification?.title ?? 'Registration update';
      final body = message.notification?.body ?? '';
      _showApprovalSnackBar(title, body);
      return;
    }
    if (type == 'mp_seller_order_request') {
      const mpType = 'mp_seller_order_request';
      final requestId = _stringify(message.data['requestId']).trim();
      final title = message.notification?.title ?? _notificationContent(mpType, '').$1;
      final body = message.notification?.body ?? _notificationContent(mpType, '').$2;
      if (requestId.isNotEmpty) {
        _saveNotificationToFirestore(title, body, mpType, requestId);
      }
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted && requestId.isNotEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(body),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => GoRouter.of(ctx).go(RouteNames.marketplaceSellerRequestDetail(requestId)),
            ),
          ),
        );
      }
      return;
    }
    if (type == 'warranty_claim') {
      final claimId = message.data['claimId'] as String?;
      final target = message.data['target'] as String? ?? 'technician';
      if (claimId != null && claimId.isNotEmpty) {
        final shouldShow = await _shouldShowJobNotification(target);
        if (shouldShow && target == 'technician') {
          final (title, body) = _notificationContent('warranty_claim', target);
          _saveNotificationToFirestore(title, body, 'warranty_claim', claimId);
          if (!kIsWeb && Platform.isAndroid) {
            await _vibrateForJobAlert();
            await _showForegroundJobNotification(claimId, 'warranty_claim', target);
          }
          _navigateToTechnicianWarrantyClaim(claimId);
        }
      }
      return;
    }
    final jobId = message.data['jobId'] as String?;
    final target = message.data['target'] as String? ?? 'technician';
    if (jobId != null && jobId.isNotEmpty) {
      final shouldShow = await _shouldShowJobNotification(target);
      if (!shouldShow) return;
      final notifType = type ?? 'job_request';
      final title = type == 'chat_message'
          ? (message.data['title'] as String? ?? 'New message')
          : _notificationContent(notifType, target).$1;
      final body = type == 'chat_message'
          ? (message.data['body'] as String? ?? '')
          : _notificationContent(notifType, target).$2;
      _saveNotificationToFirestore(title, body, notifType, jobId);
      if (type == 'chat_message') {
        _showChatMessagePopup(jobId, title, body);
        return;
      }
      if (!kIsWeb && Platform.isAndroid) {
        await _vibrateForJobAlert();
        final imageUrl = _readImageUrl(message.data);
        await _showForegroundJobNotification(jobId, notifType, target, imageUrl: imageUrl);
      }
      _navigateFromJobData(jobId, notifType, target);
    }
  }

  static void _showChatMessagePopup(String jobId, String title, String body) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _navigateToChat(jobId),
        ),
      ),
    );
  }

  static Future<void> _navigateToChat(String jobId) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final router = GoRouter.of(context);
    String? role;
    try {
      final prefs = await SharedPreferences.getInstance();
      role = prefs.getString(_keyCurrentRole);
    } catch (_) {}
    if (role == 'dealer') {
      router.go('/dealer/jobs/$jobId/bidding');
    } else {
      router.go('/technician/jobs/$jobId');
    }
    await Future.delayed(const Duration(milliseconds: 400));
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) shared_chat.showChatPopup(ctx, jobId);
  }

  /// Shows full-screen local notification when app is in foreground (same as background handler).
  static Future<void> _showForegroundJobNotification(
    String jobId,
    String type,
    String target, {
    String? imageUrl,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final (title, body) = _notificationContent(type, target);
      final img = (imageUrl ?? '').trim();
      final imageBytes = img.isEmpty ? null : await _downloadImageBytes(img);
      final style = imageBytes == null
          ? null
          : BigPictureStyleInformation(
              ByteArrayAndroidBitmap(imageBytes),
              contentTitle: title,
              summaryText: body,
              hideExpandedLargeIcon: true,
            );
      await _localNotifications.show(
        id: _jobNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _jobRequestsChannelId,
            'Job alerts',
            channelDescription: 'Ring and vibration for all job notifications',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@drawable/ic_notification',
            playSound: true,
            enableVibration: true,
            enableLights: true,
            fullScreenIntent: false,
            category: AndroidNotificationCategory.message,
            audioAttributesUsage: AudioAttributesUsage.notification,
            ongoing: false,
            vibrationPattern: Int64List.fromList(<int>[0, 300, 150, 300]),
            styleInformation: style,
          ),
        ),
        payload: _encodePayload({
          'jobId': jobId,
          'job_id': jobId,
          'type': type,
          'target': target,
          if (img.isNotEmpty) 'image_url': img,
          'title': title,
          'body': body,
        }),
      );
    } catch (_) {}
  }

  static Future<void> _vibrateForJobAlert() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: [0, 1500, 400, 1500, 400, 1500], repeat: -1);
      }
    } catch (_) {}
  }

  static Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    await _navigateFromData(message.data, notification: message.notification);
  }

  static Future<void> _navigateFromPayload(String payload) async {
    final data = _decodePayload(payload);
    if (data == null) return;
    await _navigateFromData(data.map((k, v) => MapEntry(k, v)), notification: null);
  }

  static Future<void> _navigateFromData(Map<String, dynamic> data, {RemoteNotification? notification}) async {
    final type = _readType(data);
    final target = _readTarget(data);

    // Title/body for in-app logging (optional).
    final title = (notification?.title ?? _stringify(data['title'])).trim();
    final body = (notification?.body ?? _stringify(data['body'])).trim();

    // Job-based deep links
    final jobId = _readJobId(data);
    final claimId = _stringify(data['claimId']).trim();

    // OTP notifications are informational only; don't route user away.
    if (type == 'otp') {
      return;
    }

    if (type == 'approval') {
      _navigateToLogin();
      return;
    }

    if (type == 'mp_seller_order_request') {
      final requestId = _stringify(data['requestId']).trim();
      if (requestId.isEmpty) {
        _navigateToDefaultHome();
        return;
      }
      final (t0, b0) = _notificationContent(type, target);
      _saveNotificationToFirestore(title.isEmpty ? t0 : title, body.isEmpty ? b0 : body, type, requestId);
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;
      GoRouter.of(context).go(RouteNames.marketplaceSellerRequestDetail(requestId));
      return;
    }

    if (type == 'warranty_claim' && claimId.isNotEmpty) {
      final t = target.isEmpty ? 'technician' : target;
      final (t0, b0) = _notificationContent('warranty_claim', t);
      _saveNotificationToFirestore(title.isEmpty ? t0 : title, body.isEmpty ? b0 : body, 'warranty_claim', claimId);
      final shouldShow = await _shouldShowJobNotification(t);
      if (shouldShow && t == 'technician') {
        _navigateToTechnicianWarrantyClaim(claimId);
      } else {
        _navigateToDefaultHome();
      }
      return;
    }

    // New requested types: job/chat/offer/general
    if (type == 'job' || type == 'chat' || type == 'offer') {
      if (jobId.isEmpty) {
        if (type == 'offer') {
          _navigateToOffers();
          return;
        }
        _navigateToDefaultHome();
        return;
      }
      // For job/chat/offer, use role target if provided, else infer from current role.
      final inferredTarget = target.isEmpty ? await _inferTargetFromPrefs() : target;
      final mappedType = type == 'chat' ? 'chat_message' : (type == 'offer' ? 'technician_bid' : 'job_request');
      final (t0, b0) = _notificationContent(mappedType, inferredTarget);
      _saveNotificationToFirestore(title.isEmpty ? t0 : title, body.isEmpty ? b0 : body, mappedType, jobId);
      final shouldShow = await _shouldShowJobNotification(inferredTarget);
      if (!shouldShow) return;
      _navigateFromJobData(jobId, mappedType, inferredTarget);
      return;
    }

    // Existing job-based notifications
    if (jobId.isNotEmpty) {
      final notifType = _stringify(data['type']).trim().isEmpty ? 'job_request' : _stringify(data['type']).trim();
      final inferredTarget = target.isEmpty ? await _inferTargetFromPrefs() : target;
      final (t0, b0) = _notificationContent(notifType, inferredTarget);
      _saveNotificationToFirestore(title.isEmpty ? t0 : title, body.isEmpty ? b0 : body, notifType, jobId);
      await _navigateFromJobDataIfRoleMatches(jobId, notifType, inferredTarget);
      return;
    }

    // General / unknown: open home
    if (title.isNotEmpty || body.isNotEmpty) {
      // save as general
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && FirestoreService.isAvailable) {
        try {
          FirestoreService.notifications(uid).add({
            'title': title.isEmpty ? 'Notification' : title,
            'body': body,
            'type': type,
            'jobId': '',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    }
    _navigateToDefaultHome();
  }

  static Future<String> _inferTargetFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_keyCurrentRole)?.toLowerCase();
      if (role == 'dealer' || role == 'technician' || role == 'admin') return role!;
    } catch (_) {}
    return 'technician';
  }

  static void _navigateToDefaultHome() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    // Use current route guard + auth redirect; go_router will land correctly.
    GoRouter.of(context).go(RouteNames.splash);
  }

  static void _navigateToOffers() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go(RouteNames.offers);
  }

  static Future<void> _navigateFromJobDataIfRoleMatches(String jobId, String type, String target) async {
    final shouldShow = await _shouldShowJobNotification(target);
    if (!shouldShow) return;
    _navigateFromJobData(jobId, type, target);
  }

  static void _navigateFromJobData(String jobId, String type, String target) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    if (type == 'warranty_claim' && target == 'technician') {
      _navigateToTechnicianWarrantyClaim(jobId);
      return;
    }
    if (target == 'dealer') {
      _navigateToDealerJob(jobId, type);
    } else {
      _navigateToTechnicianJob(jobId, type);
    }
  }

  static void _navigateToDealerJob(String jobId, String type) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    if (type == 'chat_message') {
      GoRouter.of(context).go('/dealer/jobs/$jobId/bidding');
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) shared_chat.showChatPopup(ctx, jobId);
      });
      return;
    }
    if (type == 'technician_accepted' || type == 'technician_bid') {
      GoRouter.of(context).go('/dealer/jobs/$jobId/bidding');
    } else {
      GoRouter.of(context).go('/dealer/jobs/$jobId');
    }
  }

  static void _navigateToTechnicianJob(String jobId, String type) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    if (type == 'chat_message') {
      GoRouter.of(context).go('/technician/jobs/$jobId');
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) shared_chat.showChatPopup(ctx, jobId);
      });
      return;
    }
    if (type == 'job_request') {
      GoRouter.of(context).go('${RouteNames.technicianIncomingJob}?jobId=$jobId');
    } else if (type == 'dealer_counter' || type == 'dealer_accept_bid') {
      GoRouter.of(context).go('/technician/jobs/$jobId/bidding');
    } else {
      GoRouter.of(context).go('/technician/jobs/$jobId');
    }
  }

  static void _navigateToTechnicianWarrantyClaim(String claimId) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go('/technician/warranty-claims/$claimId');
  }

  static void _showApprovalSnackBar(String title, String body) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — $body'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static void _navigateToLogin() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go(AuthPostLogin.postLogoutRoute());
  }


  static Future<String?> getToken() async {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseMessaging.instance.getToken();
  }

  /// Returns jobId if app was launched from our local job notification (terminated state).
  static Future<String?> getNotificationLaunchPayload() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final details = await _localNotifications.getNotificationAppLaunchDetails();
    return details?.notificationResponse?.payload;
  }

  /// Opens the full-screen notification permission screen (Android 14+).
  /// Falls back to app settings if the specific screen is not available.
  static Future<void> openFullScreenIntentSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      const packageName = 'com.dgyardconnect.dgyardconnect';
      final intent = AndroidIntent(
        action: 'android.settings.action.MANAGE_APP_USE_FULL_SCREEN_INTENT',
        data: 'package:$packageName',
      );
      final canResolve = await intent.canResolveActivity();
      if (canResolve == true) {
        await intent.launch();
      } else {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  static Future<void> requestPermission() async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseMessaging.instance.requestPermission();
  }

  /// Save FCM token to users/{uid}. Keeps both fcmToken (latest) and fcmTokens (all devices).
  /// Multiple tokens ensure notifications reach phone even if user also logged in on web.
  static Future<void> saveTokenToUser(String uid) async {
    if (Firebase.apps.isEmpty || !FirestoreService.isAvailable) return;
    final token = await getToken();
    if (token == null) return;
    await FirestoreService.users().doc(uid).update({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Remove current device's FCM token from user doc on logout. Prevents notifications
  /// going to a device after user has switched accounts (e.g. dealer logged out, technician now on same device).
  static Future<void> removeTokenFromUser(String uid) async {
    if (Firebase.apps.isEmpty || !FirestoreService.isAvailable) return;
    final token = await getToken();
    if (token == null) return;
    final ref = FirestoreService.users().doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    final currentFcmToken = data?['fcmToken'] as String?;
    final updates = <String, dynamic>{
      'fcmTokens': FieldValue.arrayRemove([token]),
    };
    if (currentFcmToken == token) {
      updates['fcmToken'] = FieldValue.delete();
    }
    await ref.update(updates);
  }
}

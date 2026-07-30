import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Server calls for seller order-request queue.
class MarketplaceSellerRequestService {
  MarketplaceSellerRequestService._();

  static bool get _ok => Firebase.apps.isNotEmpty;

  static Future<void> respond({required String requestId, required bool accept}) async {
    if (!_ok) throw StateError('Firebase not initialized');
    await FirebaseFunctions.instance.httpsCallable('marketplaceSellerRespondToOrderRequest').call({
      'requestId': requestId,
      'action': accept ? 'accept' : 'reject',
    });
  }

  static String messageForFunctionsException(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }
}

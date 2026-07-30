import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Server-authoritative marketplace checkout (Razorpay + COD).
class MarketplaceCheckoutService {
  MarketplaceCheckoutService._();

  static bool get _ok => Firebase.apps.isNotEmpty;

  static Future<({bool eligible, String? reason})> checkCodEligibility({
    required int totalPaise,
    String? pincode,
  }) async {
    if (!_ok) return (eligible: false, reason: 'firebase_unavailable');
    final result = await FirebaseFunctions.instance.httpsCallable('marketplaceCheckCodEligibility').call({
      'totalPaise': totalPaise,
      if (pincode != null && pincode.trim().isNotEmpty) 'pincode': pincode.trim(),
    });
    final data = result.data as Map<dynamic, dynamic>?;
    final eligible = data?['eligible'] == true;
    final reason = data?['reason'] as String?;
    return (eligible: eligible, reason: reason);
  }

  static Future<({String marketplaceOrderId, int totalPaise})> placeCodOrder({String? pincode}) async {
    if (!_ok) throw StateError('Firebase not initialized');
    final result = await FirebaseFunctions.instance.httpsCallable('marketplacePlaceCodOrder').call({
      if (pincode != null && pincode.trim().isNotEmpty) 'pincode': pincode.trim(),
    });
    final data = result.data as Map<dynamic, dynamic>?;
    final id = data?['marketplaceOrderId'] as String?;
    final total = (data?['totalPaise'] as num?)?.toInt() ?? 0;
    if (id == null || id.isEmpty) {
      throw StateError('Invalid response from marketplacePlaceCodOrder');
    }
    return (marketplaceOrderId: id, totalPaise: total);
  }

  static Future<({
    String marketplaceOrderId,
    String razorpayOrderId,
    String keyId,
    int amountPaise,
  })> createRazorpayCheckout() async {
    if (!_ok) throw StateError('Firebase not initialized');
    final result = await FirebaseFunctions.instance.httpsCallable('marketplaceCreateRazorpayCheckout').call({});
    final data = result.data as Map<dynamic, dynamic>?;
    final mpId = data?['marketplaceOrderId'] as String?;
    final rpId = data?['razorpayOrderId'] as String?;
    final keyId = data?['keyId'] as String?;
    final amount = (data?['amountPaise'] as num?)?.toInt() ?? 0;
    if (mpId == null || rpId == null || keyId == null || amount <= 0) {
      throw StateError('Invalid response from marketplaceCreateRazorpayCheckout');
    }
    return (
      marketplaceOrderId: mpId,
      razorpayOrderId: rpId,
      keyId: keyId,
      amountPaise: amount,
    );
  }

  static Future<void> verifyRazorpayPayment({
    required String marketplaceOrderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    if (!_ok) throw StateError('Firebase not initialized');
    await FirebaseFunctions.instance.httpsCallable('marketplaceVerifyRazorpayPayment').call({
      'marketplaceOrderId': marketplaceOrderId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
  }

  static String messageForFunctionsException(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }
}

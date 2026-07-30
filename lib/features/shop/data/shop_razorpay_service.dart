import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_config.dart';
import 'supabase_repository_base.dart';

class ShopRazorpayCheckoutResult {
  const ShopRazorpayCheckoutResult({
    required this.shopOrderId,
    required this.razorpayOrderId,
    required this.keyId,
    required this.amountPaise,
  });

  final String shopOrderId;
  final String razorpayOrderId;
  final String keyId;
  final int amountPaise;
}

/// Calls Edge Function [shop-razorpay] for create / verify.
class ShopRazorpayService {
  static Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    await SupabaseAuthService.instance.syncSessionFromFirebase();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    final session = client?.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in required for payment');
    }

    final res = await http.post(
      Uri.parse(SupabaseConfig.functionUrl('shop-razorpay')),
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': SupabaseConfig.anonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic> json = {};
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
    } catch (_) {}

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(json['error']?.toString() ?? 'Payment request failed (${res.statusCode})');
    }
    return json;
  }

  static Future<ShopRazorpayCheckoutResult> createCheckout(String shopOrderId) async {
    final data = await _invoke({
      'action': 'create',
      'shopOrderId': shopOrderId,
    });
    final rpId = data['razorpayOrderId'] as String?;
    final keyId = data['keyId'] as String?;
    final amountPaise = (data['amountPaise'] as num?)?.toInt();
    if (rpId == null || keyId == null || amountPaise == null) {
      throw StateError('Invalid checkout response');
    }
    return ShopRazorpayCheckoutResult(
      shopOrderId: shopOrderId,
      razorpayOrderId: rpId,
      keyId: keyId,
      amountPaise: amountPaise,
    );
  }

  static Future<void> verifyPayment({
    required String shopOrderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    await _invoke({
      'action': 'verify',
      'shopOrderId': shopOrderId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
  }
}

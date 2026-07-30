import 'package:firebase_auth/firebase_auth.dart';

import 'shop_razorpay_launcher.dart';
import 'shop_razorpay_service.dart';

/// Creates a pending shop order (caller), then opens Razorpay and verifies.
class ShopCheckoutPaymentFlow {
  /// [createOrder] must return a shop_orders id in pending_payment status.
  static Future<String?> payAfterCreatingOrder({
    required Future<String?> Function() createOrder,
    String? prefillContact,
    String? prefillEmail,
    required void Function(String message) onError,
    required void Function(String shopOrderId) onPaid,
  }) async {
    final orderId = await createOrder();
    if (orderId == null || orderId.isEmpty) {
      onError('Could not create order');
      return null;
    }

    try {
      final checkout = await ShopRazorpayService.createCheckout(orderId);
      final user = FirebaseAuth.instance.currentUser;
      await ShopRazorpayLauncher.open(
        keyId: checkout.keyId,
        razorpayOrderId: checkout.razorpayOrderId,
        amountPaise: checkout.amountPaise,
        name: 'D.G.Yard Shop',
        description: 'Order ${orderId.substring(0, 8).toUpperCase()}',
        prefillContact: prefillContact ?? user?.phoneNumber,
        prefillEmail: prefillEmail ?? user?.email,
        onSuccess: ({
          required String orderId,
          required String paymentId,
          required String signature,
        }) async {
          try {
            await ShopRazorpayService.verifyPayment(
              shopOrderId: checkout.shopOrderId,
              razorpayOrderId: orderId,
              razorpayPaymentId: paymentId,
              razorpaySignature: signature,
            );
            onPaid(checkout.shopOrderId);
          } catch (e) {
            onError(
              'Payment received but confirmation failed. Contact support with order ${checkout.shopOrderId}. $e',
            );
          }
        },
        onFailure: onError,
      );
      return orderId;
    } catch (e) {
      onError(e.toString());
      return orderId;
    }
  }
}

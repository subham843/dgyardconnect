import 'shop_razorpay_launcher_stub.dart'
    if (dart.library.html) 'shop_razorpay_launcher_web.dart'
    if (dart.library.io) 'shop_razorpay_launcher_mobile.dart';

typedef ShopRazorpaySuccess = void Function({
  required String orderId,
  required String paymentId,
  required String signature,
});

typedef ShopRazorpayFailure = void Function(String message);

/// Opens Razorpay Checkout (native SDK on mobile, Checkout.js on web).
abstract final class ShopRazorpayLauncher {
  static Future<void> open({
    required String keyId,
    required String razorpayOrderId,
    required int amountPaise,
    required String name,
    required String description,
    String? prefillContact,
    String? prefillEmail,
    required ShopRazorpaySuccess onSuccess,
    required ShopRazorpayFailure onFailure,
  }) {
    return openShopRazorpay(
      keyId: keyId,
      razorpayOrderId: razorpayOrderId,
      amountPaise: amountPaise,
      name: name,
      description: description,
      prefillContact: prefillContact,
      prefillEmail: prefillEmail,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }
}

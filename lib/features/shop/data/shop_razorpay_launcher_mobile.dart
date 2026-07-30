import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'shop_razorpay_launcher.dart';

Future<void> openShopRazorpay({
  required String keyId,
  required String razorpayOrderId,
  required int amountPaise,
  required String name,
  required String description,
  String? prefillContact,
  String? prefillEmail,
  required ShopRazorpaySuccess onSuccess,
  required ShopRazorpayFailure onFailure,
}) async {
  final razorpay = Razorpay();

  void clear() {
    razorpay.clear();
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
    clear();
    onSuccess(
      orderId: response.orderId ?? razorpayOrderId,
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    );
  });
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
    clear();
    onFailure(response.message ?? 'Payment cancelled');
  });
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

  razorpay.open({
    'key': keyId,
    'amount': amountPaise,
    'currency': 'INR',
    'name': name,
    'description': description,
    'order_id': razorpayOrderId,
    'prefill': {
      if (prefillContact != null && prefillContact.isNotEmpty) 'contact': prefillContact,
      if (prefillEmail != null && prefillEmail.isNotEmpty) 'email': prefillEmail,
    },
  });
}

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
  onFailure('Payments are not available on this platform');
}

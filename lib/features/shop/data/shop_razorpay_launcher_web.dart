import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'shop_razorpay_launcher.dart';

extension type _RazorpayInstance._(JSObject _) implements JSObject {
  external void open();
  external void on(String event, JSFunction handler);
}

String? _jsString(JSObject obj, String key) {
  final v = obj.getProperty(key.toJS);
  if (v == null || v.isUndefinedOrNull) return null;
  return (v as JSString).toDart;
}

Future<void> _ensureScript() async {
  if (web.window.hasProperty('Razorpay'.toJS).toDart) return;

  final existing = web.document.querySelector('script[data-dgyard-razorpay="1"]');
  if (existing == null) {
    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = 'https://checkout.razorpay.com/v1/checkout.js'
      ..async = true;
    script.setAttribute('data-dgyard-razorpay', '1');
    script.onload = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;
    script.onerror = (web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Failed to load Razorpay'));
      }
    }.toJS;
    web.document.head?.append(script);
    await completer.future;
  }

  for (var i = 0; i < 50; i++) {
    if (web.window.hasProperty('Razorpay'.toJS).toDart) return;
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  throw StateError('Razorpay Checkout.js not available');
}

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
  try {
    await _ensureScript();
  } catch (e) {
    onFailure(e.toString());
    return;
  }

  final options = JSObject();
  options.setProperty('key'.toJS, keyId.toJS);
  options.setProperty('amount'.toJS, amountPaise.toJS);
  options.setProperty('currency'.toJS, 'INR'.toJS);
  options.setProperty('name'.toJS, name.toJS);
  options.setProperty('description'.toJS, description.toJS);
  options.setProperty('order_id'.toJS, razorpayOrderId.toJS);

  final prefill = JSObject();
  if (prefillContact != null && prefillContact.isNotEmpty) {
    prefill.setProperty('contact'.toJS, prefillContact.toJS);
  }
  if (prefillEmail != null && prefillEmail.isNotEmpty) {
    prefill.setProperty('email'.toJS, prefillEmail.toJS);
  }
  options.setProperty('prefill'.toJS, prefill);

  options.setProperty(
    'handler'.toJS,
    ((JSAny? response) {
      if (response == null || response.isA<JSObject>() == false) {
        onFailure('Invalid payment response');
        return;
      }
      final obj = response as JSObject;
      onSuccess(
        orderId: _jsString(obj, 'razorpay_order_id') ?? razorpayOrderId,
        paymentId: _jsString(obj, 'razorpay_payment_id') ?? '',
        signature: _jsString(obj, 'razorpay_signature') ?? '',
      );
    }).toJS,
  );

  final ctor = web.window.getProperty('Razorpay'.toJS);
  if (ctor == null || ctor.isUndefinedOrNull) {
    onFailure('Razorpay not loaded');
    return;
  }

  final instance = (ctor as JSFunction).callAsConstructor(options) as _RazorpayInstance;
  instance.on(
    'payment.failed',
    ((JSAny? response) {
      String msg = 'Payment failed';
      if (response != null && response.isA<JSObject>()) {
        final err = (response as JSObject).getProperty('error'.toJS);
        if (err != null && err.isA<JSObject>()) {
          final desc = _jsString(err as JSObject, 'description');
          if (desc != null && desc.isNotEmpty) msg = desc;
        }
      }
      onFailure(msg);
    }).toJS,
  );
  instance.open();
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../data/marketplace_checkout_service.dart';
import '../state/marketplace_cart_controller.dart';
import 'marketplace_format.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceCheckoutScreen extends StatefulWidget {
  const MarketplaceCheckoutScreen({super.key});

  @override
  State<MarketplaceCheckoutScreen> createState() => _MarketplaceCheckoutScreenState();
}

class _MarketplaceCheckoutScreenState extends State<MarketplaceCheckoutScreen> {
  String _method = 'razorpay';
  bool _busy = false;
  final _pincode = TextEditingController();
  Razorpay? _razorpay;
  String? _pendingMarketplaceOrderId;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    }
    if (kIsWeb) {
      _method = 'cod';
    }
  }

  @override
  void dispose() {
    _pincode.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _onRazorpaySuccess(PaymentSuccessResponse response) async {
    final mpId = _pendingMarketplaceOrderId;
    if (mpId == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await MarketplaceCheckoutService.verifyRazorpayPayment(
        marketplaceOrderId: mpId,
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );
      if (!mounted) return;
      context.go(
        '${RouteNames.marketplacePaymentResult}?orderId=$mpId&method=razorpay&verified=1',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment received but confirmation failed. If debited, support will reconcile. ${MarketplaceCheckoutService.messageForFunctionsException(e)}',
            ),
          ),
        );
      }
    } finally {
      _pendingMarketplaceOrderId = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.message ?? 'Payment cancelled')),
    );
    setState(() => _busy = false);
  }

  Future<void> _placeCod() async {
    final cart = context.read<MarketplaceCartController>();
    final pin = _pincode.text.trim();
    final check = await MarketplaceCheckoutService.checkCodEligibility(
      totalPaise: cart.totalPaise,
      pincode: pin.isEmpty ? null : pin,
    );
    if (!check.eligible) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_codReasonMessage(check.reason))),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final r = await MarketplaceCheckoutService.placeCodOrder(pincode: pin.isEmpty ? null : pin);
      if (!mounted) return;
      context.go(
        '${RouteNames.marketplacePaymentResult}?orderId=${r.marketplaceOrderId}&method=cod',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MarketplaceCheckoutService.messageForFunctionsException(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _codReasonMessage(String? code) {
    return switch (code) {
      'cod_disabled' => 'Cash on delivery is not available right now.',
      'amount_over_cap' => 'Order total exceeds the COD limit. Pay online or reduce the cart.',
      'pincode_blocked' => 'COD is not offered for this pincode.',
      'trust_too_low' => 'COD is not available for your account tier yet.',
      'invalid_amount' => 'Invalid cart total.',
      _ => 'COD is not available for this order.',
    };
  }

  Future<void> _placeRazorpay() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use the mobile app for card / UPI checkout.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await MarketplaceCheckoutService.createRazorpayCheckout();
      _pendingMarketplaceOrderId = r.marketplaceOrderId;
      if (!mounted) return;
      _razorpay!.open({
        'key': r.keyId,
        'amount': r.amountPaise,
        'order_id': r.razorpayOrderId,
        'name': 'D.G.Yard Connect',
        'description': 'Marketplace order',
        'prefill': {'contact': '', 'email': ''},
      });
      setState(() => _busy = false);
    } catch (e) {
      _pendingMarketplaceOrderId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MarketplaceCheckoutService.messageForFunctionsException(e))),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<MarketplaceCartController>();
    final theme = Theme.of(context);
    final firebaseOk = Firebase.apps.isNotEmpty;

    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Payment',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Totals are confirmed on the server from live catalog prices. You pay D.G.Yard only.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        if (!firebaseOk) ...[
          const SizedBox(height: 12),
          Text(
            'Firebase is not available — checkout disabled.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        if (kIsWeb) ...[
          const SizedBox(height: 12),
          Text(
            'On web, use Cash on delivery or open this screen in the Android/iOS app for online pay.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'razorpay',
              label: const Text('Online'),
              icon: const Icon(Icons.payment),
              enabled: !kIsWeb,
            ),
            const ButtonSegment(value: 'cod', label: Text('COD'), icon: Icon(Icons.local_shipping_outlined)),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        if (_method == 'cod') ...[
          const SizedBox(height: 20),
          TextField(
            controller: _pincode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Delivery pincode (optional)',
              hintText: 'Used for COD eligibility rules',
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'Order summary',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...cart.items.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text('${e.titleSnapshot} × ${e.quantity}')),
                Text(marketplaceFormatInr(e.pricePaiseSnapshot * e.quantity)),
              ],
            ),
          ),
        ),
        const Divider(height: 32),
        Row(
          children: [
            Text('Cart total (indicative)', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              marketplaceFormatInr(cart.totalPaise),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Final amount is set when you place the order (server-priced).',
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Checkout')),
      body: Column(
        children: [
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton(
          onPressed: cart.items.isEmpty || _busy || !firebaseOk
              ? null
              : () {
                  if (_method == 'cod') {
                    _placeCod();
                  } else {
                    _placeRazorpay();
                  }
                },
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Place order'),
        ),
      ),
    );
  }
}

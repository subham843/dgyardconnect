import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/route_names.dart';
import '../../shop/data/public_cart_checkout_service.dart';
import '../../shop/data/shop_order_repository.dart';
import '../../shop/data/shop_razorpay_launcher.dart';
import '../../shop/data/shop_razorpay_service.dart';
import '../../shop/domain/shop_order.dart';
import '../../web_public/pages/shop/widgets/store_atoms.dart';
import '../../web_public/v2/v2_animate_export.dart';
import '../../web_public/v2/v2_colors.dart';
import '../../web_public/v2/v2_font_styles.dart';
import '../../web_public/v2/v2_text.dart';
import 'customer_account_shell.dart';

class CustomerOrderDetailScreen extends StatefulWidget {
  const CustomerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<CustomerOrderDetailScreen> createState() => _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  final _repo = ShopOrderRepository();
  final _checkout = PublicCartCheckoutService();
  ShopOrder? _order;
  List<ShopOrderLineItem> _lines = [];
  bool _loading = true;
  bool _reordering = false;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final order = await _repo.getOrder(widget.orderId);
    final lines = order == null ? <ShopOrderLineItem>[] : await _repo.listOrderLines(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _lines = lines;
        _loading = false;
      });
    }
  }

  Future<void> _payNow() async {
    final order = _order;
    if (order == null) return;
    setState(() => _paying = true);
    try {
      final checkout = await ShopRazorpayService.createCheckout(order.id);
      await ShopRazorpayLauncher.open(
        keyId: checkout.keyId,
        razorpayOrderId: checkout.razorpayOrderId,
        amountPaise: checkout.amountPaise,
        name: 'D.G.Yard Shop',
        description: 'Order ${order.id.substring(0, 8).toUpperCase()}',
        onSuccess: ({
          required String orderId,
          required String paymentId,
          required String signature,
        }) async {
          try {
            await ShopRazorpayService.verifyPayment(
              shopOrderId: order.id,
              razorpayOrderId: orderId,
              razorpayPaymentId: paymentId,
              razorpaySignature: signature,
            );
            if (!mounted) return;
            setState(() => _paying = false);
            await _load();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful')));
          } catch (e) {
            if (!mounted) return;
            setState(() => _paying = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment received but confirmation failed: $e')));
          }
        },
        onFailure: (msg) {
          if (!mounted) return;
          setState(() => _paying = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted && _paying) setState(() => _paying = false);
  }

  Future<void> _orderAgain() async {
    if (_lines.isEmpty) return;
    setState(() => _reordering = true);
    await _checkout.reorderLines(_lines);
    if (!mounted) return;
    setState(() => _reordering = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items added to cart')));
    context.go(RouteNames.publicCart);
  }

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return CustomerAccountShell(
        activeTab: CustomerAccountTab.account,
        backFallback: RouteNames.accountOrders,
        title: 'Order details',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final order = _order;
    if (order == null) {
      return CustomerAccountShell(
        activeTab: CustomerAccountTab.account,
        backFallback: RouteNames.accountOrders,
        title: 'Order details',
        child: AccountEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Order not found',
          message: 'This order may have been removed or you may not have access.',
          actionLabel: 'Back to orders',
          onAction: () => context.go(RouteNames.accountOrders),
        ),
      );
    }

    final dateFmt = DateFormat('d MMM yyyy, h:mm a');
    final showPay = order.status == 'pending_payment' || order.status == 'draft';

    return CustomerAccountShell(
      activeTab: CustomerAccountTab.account,
      backFallback: RouteNames.accountOrders,
      title: 'Order #${_shortId(order.id)}',
      subtitle: order.statusLabel,
      stickyBottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showPay)
                _ActionPill(
                  label: _paying ? 'Opening Razorpay…' : 'Pay with Razorpay',
                  icon: Icons.lock_outline_rounded,
                  loading: _paying,
                  filled: true,
                  onTap: _payNow,
                ),
              if (showPay) const SizedBox(height: 10),
              _ActionPill(
                label: 'Order again',
                icon: Icons.replay_rounded,
                loading: _reordering,
                filled: false,
                onTap: _lines.isEmpty || _reordering ? null : _orderAgain,
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusTracker(status: order.status).animate().fadeIn(duration: 360.ms).slideY(begin: 0.06, end: 0),
          const SizedBox(height: 14),
          AccountGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.statusLabel, style: V2FontStyles.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                if (order.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Placed on ${dateFmt.format(order.createdAt!.toLocal())}', style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                ],
                const SizedBox(height: 16),
                Divider(color: Colors.black.withValues(alpha: 0.06)),
                const SizedBox(height: 12),
                _row('Subtotal', formatINR(order.subtotal)),
                const SizedBox(height: 6),
                _row('Total', formatINR(order.totalAmount), bold: true),
              ],
            ),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 18),
          Text('Items', style: V2FontStyles.inter(fontSize: 13, fontWeight: FontWeight.w700, color: V2Colors.fgSubtle)),
          const SizedBox(height: 10),
          for (var i = 0; i < _lines.length; i++) ...[
            AccountGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_lines[i].productName, style: V2FontStyles.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('SKU ${_lines[i].sku} · Qty ${_lines[i].qty}', style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
                      ],
                    ),
                  ),
                  Text(formatINR(_lines[i].lineTotal), style: V2FontStyles.inter(fontWeight: FontWeight.w800)),
                ],
              ),
            ).animate(delay: (50 * i).ms).fadeIn().slideY(begin: 0.04, end: 0),
            if (i < _lines.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = V2FontStyles.inter(fontWeight: bold ? FontWeight.w800 : FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(980),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(980),
            color: filled ? V2Colors.ink : Colors.white.withValues(alpha: 0.92),
            border: filled ? null : Border.all(color: V2Colors.borderStrong),
            boxShadow: filled
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 8))]
                : null,
          ),
          child: Center(
            child: loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: filled ? Colors.white : V2Colors.ink))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: filled ? Colors.white : V2Colors.ink),
                      const SizedBox(width: 8),
                      Text(label, style: V2FontStyles.inter(fontSize: 14, fontWeight: FontWeight.w700, color: filled ? Colors.white : V2Colors.ink)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({required this.status});
  final String status;
  static const _steps = ['pending_payment', 'paid', 'processing', 'shipped', 'delivered'];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return AccountGlassCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text('This order was cancelled', style: V2FontStyles.inter(fontWeight: FontWeight.w700))),
          ],
        ),
      );
    }

    final currentIndex = _steps.indexOf(status).clamp(0, _steps.length - 1);
    return AccountGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track order', style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: i <= currentIndex
                              ? const LinearGradient(colors: [V2Colors.ember, V2Colors.plasma])
                              : null,
                          color: i <= currentIndex ? null : V2Colors.bgSubtle,
                        ),
                        child: Icon(
                          i < currentIndex ? Icons.check_rounded : Icons.circle,
                          size: 14,
                          color: i <= currentIndex ? Colors.white : V2Colors.fgFaint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _label(_steps[i]),
                        textAlign: TextAlign.center,
                        style: V2Text.micro().copyWith(
                          fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w500,
                          color: i <= currentIndex ? V2Colors.ink : V2Colors.fgSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(980),
                        gradient: i < currentIndex
                            ? const LinearGradient(colors: [V2Colors.ember, V2Colors.plasma])
                            : null,
                        color: i < currentIndex ? null : V2Colors.border,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _label(String step) => switch (step) {
        'pending_payment' => 'Pending',
        'paid' => 'Paid',
        'processing' => 'Processing',
        'shipped' => 'Shipped',
        'delivered' => 'Delivered',
        _ => step,
      };
}

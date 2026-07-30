import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../data/shop_checkout_payment_flow.dart';
import '../data/shop_order_repository.dart';
import '../domain/shop_order.dart';
import '../state/shop_cart_controller.dart';

class ShopCartScreen extends StatelessWidget {
  const ShopCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<ShopCartController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.loading
          ? const Center(child: CircularProgressIndicator())
          : cart.items.isEmpty
          ? const Center(child: Text('Cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final it = cart.items[i];
                      return ListTile(
                        title: Text(it.product?.name ?? 'Product'),
                        subtitle: Text('₹${it.lineTotal.toStringAsFixed(0)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => cart.setQty(it.id, it.qty - 1),
                            ),
                            Text('${it.qty}'),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => cart.setQty(it.id, it.qty + 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Subtotal: ₹${cart.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: cart.items.isEmpty
                              ? null
                              : () => context.push(RouteNames.shopCheckout),
                          child: const Text('Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class ShopCheckoutScreen extends StatefulWidget {
  const ShopCheckoutScreen({super.key});

  @override
  State<ShopCheckoutScreen> createState() => _ShopCheckoutScreenState();
}

class _ShopCheckoutScreenState extends State<ShopCheckoutScreen> {
  final _orderRepo = ShopOrderRepository();
  bool _placing = false;

  Future<void> _place() async {
    setState(() => _placing = true);
    await ShopCheckoutPaymentFlow.payAfterCreatingOrder(
      createOrder: () => _orderRepo.createOrderFromCart(),
      onError: (msg) {
        if (!mounted) return;
        setState(() => _placing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      onPaid: (orderId) {
        if (!mounted) return;
        context.read<ShopCartController>().refresh();
        setState(() => _placing = false);
        context.go(RouteNames.accountOrderDetail(orderId));
      },
    );
    if (mounted && _placing) setState(() => _placing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<ShopCartController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${cart.itemCount} items · ₹${cart.subtotal.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text('Secure payment via Razorpay (UPI, cards, netbanking).'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _placing ? null : _place,
              icon: _placing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(_placing ? 'Opening Razorpay…' : 'Pay with Razorpay'),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopOrdersScreen extends StatefulWidget {
  const ShopOrdersScreen({super.key});

  @override
  State<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends State<ShopOrdersScreen> {
  final _repo = ShopOrderRepository();
  List<ShopOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.listMyOrders();
    if (mounted) {
      setState(() {
        _orders = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (_, i) {
                final o = _orders[i];
                return ListTile(
                  title: Text('₹${o.totalAmount.toStringAsFixed(0)}'),
                  subtitle: Text(o.statusLabel),
                  onTap: () => context.push(RouteNames.accountOrderDetail(o.id)),
                );
              },
            ),
    );
  }
}

// Public guest cart — review items, adjust quantities, then login to checkout.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bootstrap/firebase_auth_safe.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/auth_post_login.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/v2_text.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';
import '../../v2/widgets/v2_page_container.dart';
import '../../state/public_cart.dart';
import 'widgets/store_atoms.dart';

class StoreCartPage extends StatefulWidget {
  const StoreCartPage({super.key});

  @override
  State<StoreCartPage> createState() => _StoreCartPageState();
}

class _StoreCartPageState extends State<StoreCartPage> {
  final _scroll = ScrollController();
  final _cart = PublicCart.instance;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkout() {
    if (FirebaseAuthSafe.isSignedIn) {
      context.go(RouteNames.publicCheckout);
      return;
    }
    context.go(AuthPostLogin.loginUrlWithReturn(RouteNames.publicCheckout));
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Scaffold(
      backgroundColor: V2Colors.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                SizedBox(height: v.r(xs: 16, lg: 24)),
                V2PageContainer(
                  maxWidth: V2.maxMedium,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Your cart', style: V2Text.h2(context)),
                          const SizedBox(width: V2.s4),
                          ListenableBuilder(
                            listenable: _cart,
                            builder: (context, _) => _cart.isEmpty
                                ? const SizedBox.shrink()
                                : StorePill(
                                    label: '${_cart.itemCount} items',
                                    color: V2Colors.plasma,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: V2.s8),
                      ListenableBuilder(
                        listenable: _cart,
                        builder: (context, _) {
                          if (_cart.isEmpty) return _empty();
                          return v.isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 7, child: _lines()),
                                    const SizedBox(width: V2.s8),
                                    Expanded(flex: 4, child: _summary()),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _lines(),
                                    const SizedBox(height: V2.s8),
                                    _summary(),
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: V2.s16),
                const V2Footer(),
                SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: V2.s24),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 80, color: V2Colors.fgFaint),
          const SizedBox(height: V2.s6),
          Text('Your cart is empty', style: V2Text.h3(context)),
          const SizedBox(height: V2.s2),
          Text('Browse the store and add products to get started.',
              style: V2Text.body()),
          const SizedBox(height: V2.s6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: V2Colors.ember,
              padding: const EdgeInsets.symmetric(
                  horizontal: V2.s6, vertical: 16),
            ),
            onPressed: () => context.go(RouteNames.publicStore),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Browse the store'),
          ),
        ],
      ),
    );
  }

  Widget _lines() {
    return Column(
      children: [
        for (final line in _cart.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: V2.s4),
            child: _CartLineTile(
              line: line,
              onIncrement: () => _cart.increment(line.id),
              onDecrement: () => _cart.decrement(line.id),
              onRemove: () => _cart.remove(line.id),
              onTap: () => context.go('/product/${line.slug}'),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(RouteNames.publicStore),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Continue shopping'),
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(V2.s6),
      decoration: BoxDecoration(
        color: V2Colors.bgSubtle,
        borderRadius: BorderRadius.circular(V2.rXl),
        border: Border.all(color: V2Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order summary', style: V2Text.bodyEmph()),
          const SizedBox(height: V2.s6),
          _summaryRow('Subtotal', formatINR(_cart.subtotal)),
          if (_cart.totalSavings > 0) ...[
            const SizedBox(height: V2.s2),
            _summaryRow('You save', '- ${formatINR(_cart.totalSavings)}',
                valueColor: V2Colors.aurora),
          ],
          const SizedBox(height: V2.s2),
          _summaryRow('Taxes & delivery', 'Calculated at checkout',
              valueStyleSmall: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: V2.s4),
            child: Divider(height: 1, color: V2Colors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estimated total', style: V2Text.bodyEmph()),
              Text(formatINR(_cart.subtotal),
                  style: V2Text.bodyEmph().copyWith(
                      color: V2Colors.ink,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: V2.s6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: V2Colors.ember,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: _checkout,
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text('Login & checkout'),
            ),
          ),
          const SizedBox(height: V2.s2),
          Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  size: 14, color: V2Colors.fgSubtle),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sign in to confirm pricing, delivery and place your order securely.',
                  style: V2Text.small(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? valueColor, bool valueStyleSmall = false}) {
    final valueStyle = (valueStyleSmall
            ? V2Text.small()
            : V2Text.bodyEmph())
        .copyWith(color: valueColor ?? V2Colors.ink);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: V2Text.body(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: V2.s2),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onTap,
  });

  final PublicCartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2.s4),
      decoration: BoxDecoration(
        color: V2Colors.surface,
        borderRadius: BorderRadius.circular(V2.rXl),
        border: Border.all(color: V2Colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(V2.rLg),
              child: SizedBox(
                width: 84,
                height: 84,
                child: StoreImage(url: line.imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(width: V2.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((line.brandName ?? '').isNotEmpty)
                  Text(line.brandName!.toUpperCase(),
                      style: V2Text.micro()
                          .copyWith(color: V2Colors.ember)),
                GestureDetector(
                  onTap: onTap,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.bodyEmph()
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: V2.s2),
                Row(
                  children: [
                    _QtyStepper(
                      qty: line.qty,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                    const Spacer(),
                    Text(formatINR(line.lineTotal),
                        style: V2Text.bodyEmph().copyWith(
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                size: 18, color: V2Colors.fgSubtle),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: V2Colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove_rounded, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2.s4),
            child: Text('$qty',
                style: V2Text.bodyEmph()
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          _stepBtn(Icons.add_rounded, onIncrement),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(V2.rFull),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: V2Colors.plasma),
      ),
    );
  }
}
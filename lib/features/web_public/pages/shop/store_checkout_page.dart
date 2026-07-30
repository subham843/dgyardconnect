import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../shop/data/public_cart_checkout_service.dart';
import '../../../shop/data/shop_checkout_payment_flow.dart';
import '../../state/public_cart.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_font_styles.dart';
import '../../v2/v2_text.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';
import '../../v2/widgets/v2_page_container.dart';
import 'models/shop_checkout_address.dart';
import 'widgets/store_checkout_address_picker.dart';
import 'widgets/store_checkout_alert.dart';
import 'widgets/product_detail_glass.dart';
import 'widgets/store_atoms.dart';

class StoreCheckoutPage extends StatefulWidget {
  const StoreCheckoutPage({super.key});

  @override
  State<StoreCheckoutPage> createState() => _StoreCheckoutPageState();
}

class _StoreCheckoutPageState extends State<StoreCheckoutPage> {
  final _scroll = ScrollController();
  final _cart = PublicCart.instance;
  final _checkout = PublicCartCheckoutService();
  ShopCheckoutAddress? _address;
  bool _placing = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openAddressPicker({
    bool useCurrentLocation = false,
    bool focusSearch = false,
  }) async {
    final result = await showStoreCheckoutAddressPicker(
      context,
      initial: _address,
      autoUseCurrentLocation: useCurrentLocation,
      autoFocusSearch: focusSearch,
    );
    if (result != null && mounted) {
      setState(() => _address = result);
    }
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;
    if (_address == null) {
      await showStoreCheckoutValidationAlert(
        context,
        title: 'Delivery address required',
        message: 'Please add a delivery address before placing your order.',
      );
      await _openAddressPicker();
      return;
    }

    setState(() => _placing = true);
    await ShopCheckoutPaymentFlow.payAfterCreatingOrder(
      createOrder: () => _checkout.checkoutFromPublicCart(
        shippingAddress: _address!.toShippingJson(),
      ),
      prefillContact: _address!.phone,
      onError: (msg) {
        if (!mounted) return;
        setState(() => _placing = false);
        showStoreCheckoutErrorAlert(
          context,
          title: 'Payment failed',
          message: msg,
        );
      },
      onPaid: (orderId) {
        if (!mounted) return;
        setState(() => _placing = false);
        context.go(RouteNames.accountOrderDetail(orderId));
      },
    );
    if (mounted && _placing) setState(() => _placing = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: V2Colors.plasma,
          selectionColor: V2Colors.plasma.withValues(alpha: 0.18),
          selectionHandleColor: V2Colors.plasma,
        ),
      ),
      child: Scaffold(
        backgroundColor: V2Colors.surface,
        body: Stack(
        children: [
          const ProductDetailAmbientBg(),
          ListenableBuilder(
            listenable: _cart,
            builder: (context, _) {
              final hasItems = !_cart.isEmpty;
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: Column(
                        children: [
                          SizedBox(height: v.r(xs: 16, lg: 24)),
                          V2PageContainer(
                            maxWidth: V2.maxContentWidth,
                            child: hasItems
                                ? _checkoutBody(context, v)
                                : _emptyState(context),
                          ),
                          const SizedBox(height: V2.s16),
                          const V2Footer(),
        SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
                          if (hasItems && !v.isDesktop)
                            SizedBox(height: v.r(xs: 100, md: 0)),
                        ],
                      ),
                    ),
                  ),
                  if (hasItems && !v.isDesktop) _mobilePayBar(context),
                ],
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _checkoutBody(BuildContext context, V2Responsive v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _breadcrumb(context).animate().fadeIn(duration: 320.ms),
        const SizedBox(height: V2.s6),
        _heroHeader(context, v).animate().fadeIn(duration: 420.ms).slideY(begin: 0.03, end: 0),
        const SizedBox(height: V2.s8),
        _stepStrip(context).animate().fadeIn(duration: 400.ms, delay: 80.ms),
        const SizedBox(height: V2.s10),
        v.isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _deliveryForm(context)),
                  const SizedBox(width: V2.s10),
                  Expanded(flex: 5, child: _orderSummary(context, sticky: true)),
                ],
              )
            : Column(
                children: [
                  _deliveryForm(context),
                  const SizedBox(height: V2.s8),
                  _orderSummary(context, sticky: false),
                ],
              ),
      ],
    );
  }

  Widget _breadcrumb(BuildContext context) {
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Crumb(label: 'Store', onTap: () => context.go(RouteNames.publicStore)),
        const Icon(Icons.chevron_right_rounded, size: 16, color: V2Colors.fgFaint),
        _Crumb(label: 'Bag', onTap: () => context.go(RouteNames.publicCart)),
        const Icon(Icons.chevron_right_rounded, size: 16, color: V2Colors.fgFaint),
        Text(
          'Checkout',
          style: V2Text.small().copyWith(
            color: V2Colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _heroHeader(BuildContext context, V2Responsive v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Secure checkout',
                style: V2Text.h2(context).copyWith(letterSpacing: -0.8),
              ),
              const SizedBox(height: V2.s2),
              Text(
                'Review delivery details and pay securely with Razorpay.',
                style: V2Text.bodyLg(context),
              ),
            ],
          ),
        ),
        if (v.isDesktop) ...[
          const SizedBox(width: V2.s6),
          StorePill(
            label: '${_cart.itemCount} items',
            color: V2Colors.plasma,
          ),
        ],
      ],
    );
  }

  Widget _stepStrip(BuildContext context) {
    return ProductGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: V2.s6, vertical: V2.s4),
      child: Row(
        children: [
          _StepDot(active: true, done: true, label: 'Bag', icon: Icons.shopping_bag_outlined),
          Expanded(child: _stepLine(active: true)),
          _StepDot(active: true, done: false, label: 'Delivery', icon: Icons.local_shipping_outlined),
          Expanded(child: _stepLine(active: false)),
          _StepDot(active: false, done: false, label: 'Payment', icon: Icons.lock_outline_rounded),
        ],
      ),
    );
  }

  Widget _stepLine({required bool active}) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: active
            ? LinearGradient(
                colors: [
                  V2Colors.plasma.withValues(alpha: 0.6),
                  V2Colors.plasma.withValues(alpha: 0.15),
                ],
              )
            : null,
        color: active ? null : V2Colors.border,
      ),
    );
  }

  Widget _deliveryForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Delivery address',
          subtitle: 'Search on map or use GPS — city & state auto-fill from pincode.',
          icon: Icons.location_on_outlined,
          child: _addressSection(context),
        ).animate().fadeIn(duration: 450.ms, delay: 120.ms),
        const SizedBox(height: V2.s6),
        _SectionCard(
          title: 'Payment',
          subtitle: 'UPI, cards, net banking — powered by Razorpay.',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            children: [
              _PaymentMethodTile(
                selected: true,
                title: 'Pay online with Razorpay',
                subtitle: 'Instant confirmation · Bank-grade encryption',
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: V2.s4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  ProductMetaChip(label: 'UPI', icon: Icons.qr_code_2_rounded),
                  ProductMetaChip(label: 'Visa / Mastercard', icon: Icons.credit_card),
                  ProductMetaChip(label: 'Net Banking', icon: Icons.account_balance),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 450.ms, delay: 180.ms),
        if (V2Responsive(context).isDesktop) ...[
          const SizedBox(height: V2.s8),
          _PayButton(
            placing: _placing,
            totalLabel: formatINR(_cart.subtotal),
            onTap: _placeOrder,
          ).animate().fadeIn(duration: 400.ms, delay: 240.ms),
        ],
      ],
    );
  }

  Widget _addressSection(BuildContext context) {
    final addr = _address;
    if (addr == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where should we deliver your order?',
            style: V2Text.small().copyWith(color: V2Colors.fgSubtle),
          ),
          const SizedBox(height: V2.s4),
          _AddressChoiceTile(
            icon: Icons.map_outlined,
            title: 'Away from my location',
            subtitle: 'Search area, street or landmark on map',
            onTap: () => _openAddressPicker(focusSearch: true),
          ),
          const SizedBox(height: V2.s3),
          _AddressChoiceTile(
            icon: Icons.my_location_rounded,
            title: 'Use my current location',
            subtitle: 'Detect GPS and fill address automatically',
            onTap: () => _openAddressPicker(useCurrentLocation: true),
          ),
        ],
      );
    }

    final typeLabel = switch (addr.addressType) {
      'work' => 'Work',
      'other' => 'Other',
      _ => 'Home',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(V2.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V2Colors.border),
            color: Colors.white.withValues(alpha: 0.55),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: V2Colors.plasma.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      typeLabel,
                      style: V2Text.micro().copyWith(
                        color: V2Colors.plasma,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openAddressPicker(),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(
                      foregroundColor: V2Colors.plasma,
                      splashFactory: NoSplash.splashFactory,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V2.s2),
              Text(addr.name, style: V2Text.bodyEmph()),
              Text(addr.phone, style: V2Text.small()),
              if (addr.alternatePhone != null && addr.alternatePhone!.isNotEmpty)
                Text('Alt: ${addr.alternatePhone}', style: V2Text.small()),
              const SizedBox(height: V2.s2),
              Text(addr.displayLine, style: V2Text.small()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _orderSummary(BuildContext context, {required bool sticky}) {
    final panel = ProductGlassPanel(
      highlight: true,
      padding: const EdgeInsets.all(V2.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Order summary', style: V2Text.h3(context)),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(RouteNames.publicCart),
                child: Text(
                  'Edit bag',
                  style: V2Text.small().copyWith(
                    color: V2Colors.plasma,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V2.s4),
          for (final line in _cart.lines) ...[
            _SummaryLine(line: line),
            const SizedBox(height: V2.s3),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: V2.s4),
            child: Divider(height: 1, color: V2Colors.border),
          ),
          _summaryRow('Subtotal', formatINR(_cart.subtotal)),
          if (_cart.totalSavings > 0) ...[
            const SizedBox(height: V2.s2),
            _summaryRow(
              'You save',
              '- ${formatINR(_cart.totalSavings)}',
              valueColor: V2Colors.aurora,
            ),
          ],
          const SizedBox(height: V2.s2),
          _summaryRow('Taxes & delivery', 'Included at payment', muted: true),
          const SizedBox(height: V2.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated total', style: V2Text.small()),
                    const SizedBox(height: 4),
                    Text(
                      formatINR(_cart.subtotal),
                      style: V2Text.h3(context).copyWith(
                        fontWeight: FontWeight.w800,
                        color: V2Colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (!sticky && !V2Responsive(context).isDesktop)
                const SizedBox.shrink()
              else if (sticky)
                SizedBox(
                  width: 180,
                  child: _PayButton(
                    placing: _placing,
                    compact: true,
                    totalLabel: formatINR(_cart.subtotal),
                    onTap: _placeOrder,
                  ),
                ),
            ],
          ),
          const SizedBox(height: V2.s6),
          _TrustRow(),
        ],
      ),
    );

    if (!sticky) {
      return panel.animate().fadeIn(duration: 450.ms, delay: 200.ms);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: panel.animate().fadeIn(duration: 450.ms, delay: 200.ms),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool muted = false,
  }) {
    final valueStyle = (muted ? V2Text.small() : V2Text.bodyEmph())
        .copyWith(color: valueColor ?? V2Colors.ink);
    return Row(
      children: [
        Expanded(child: Text(label, style: V2Text.body())),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _mobilePayBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        V2.s6,
        V2.s4,
        V2.s6,
        V2.s4 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: V2Colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: V2Text.small()),
                  Text(
                    formatINR(_cart.subtotal),
                    style: V2FontStyles.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: V2Colors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: V2.s4),
            Expanded(
              flex: 2,
              child: _PayButton(
                placing: _placing,
                compact: true,
                totalLabel: formatINR(_cart.subtotal),
                onTap: _placeOrder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: ProductGlassPanel(
        highlight: true,
        padding: const EdgeInsets.symmetric(horizontal: V2.s10, vertical: V2.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    V2Colors.plasma.withValues(alpha: 0.12),
                    V2Colors.ember.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 40,
                color: V2Colors.plasma,
              ),
            ),
            const SizedBox(height: V2.s6),
            Text('Your bag is empty', style: V2Text.h3(context)),
            const SizedBox(height: V2.s2),
            Text(
              'Add products from the store, then return here to checkout.',
              textAlign: TextAlign.center,
              style: V2Text.body(),
            ),
            const SizedBox(height: V2.s8),
            _PayButton(
              placing: false,
              label: 'Browse the store',
              icon: Icons.storefront_outlined,
              onTap: () => context.go(RouteNames.publicStore),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.98, 0.98)),
    );
  }
}

// ─── Atoms ───────────────────────────────────────────────────────────────────

class _Crumb extends StatefulWidget {
  const _Crumb({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_Crumb> createState() => _CrumbState();
}

class _CrumbState extends State<_Crumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: V2Text.small().copyWith(
            color: _hover ? V2Colors.plasma : V2Colors.fgSubtle,
            fontWeight: FontWeight.w500,
            decoration: _hover ? TextDecoration.underline : null,
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.active,
    required this.done,
    required this.label,
    required this.icon,
  });

  final bool active;
  final bool done;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = active ? V2Colors.plasma : V2Colors.fgFaint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? V2Colors.plasma.withValues(alpha: 0.12) : V2Colors.bgSubtle,
            border: Border.all(
              color: active ? V2Colors.plasma.withValues(alpha: 0.4) : V2Colors.border,
              width: 1.2,
            ),
          ),
          child: Icon(
            done ? Icons.check_rounded : icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: V2Text.micro().copyWith(
            color: active ? V2Colors.ink : V2Colors.fgFaint,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProductGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      V2Colors.plasma.withValues(alpha: 0.14),
                      V2Colors.ember.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: Icon(icon, size: 22, color: V2Colors.plasma),
              ),
              const SizedBox(width: V2.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: V2Text.bodyEmph().copyWith(fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: V2Text.small()),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: V2.s6),
            child: Divider(height: 1, color: V2Colors.border),
          ),
          child,
        ],
      ),
    );
  }
}

class _AddressChoiceTile extends StatelessWidget {
  const _AddressChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(V2.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V2Colors.border),
            color: Colors.white.withValues(alpha: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: V2Colors.plasma.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: V2Colors.plasma, size: 22),
              ),
              const SizedBox(width: V2.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: V2Text.bodyEmph()),
                    Text(subtitle, style: V2Text.small()),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: V2Colors.fgFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2.s4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? V2Colors.plasma.withValues(alpha: 0.45) : V2Colors.border,
          width: selected ? 1.6 : 1,
        ),
        color: selected ? V2Colors.plasma.withValues(alpha: 0.06) : Colors.white,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: V2Colors.ink,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: V2.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: V2Text.bodyEmph()),
                Text(subtitle, style: V2Text.small()),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? V2Colors.plasma : V2Colors.fgFaint,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.line});
  final PublicCartLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: StoreImage(url: line.imageUrl, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: V2.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((line.brandName ?? '').isNotEmpty)
                Text(
                  line.brandName!.toUpperCase(),
                  style: V2Text.micro().copyWith(color: V2Colors.ember),
                ),
              Text(
                line.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: V2Text.bodyEmph().copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text('Qty ${line.qty}', style: V2Text.small()),
            ],
          ),
        ),
        Text(
          formatINR(line.lineTotal),
          style: V2Text.bodyEmph().copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2.s4),
      decoration: BoxDecoration(
        color: V2Colors.bgSubtle.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: V2Colors.aurora),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '256-bit encrypted checkout · Razorpay secure payments',
              style: V2Text.micro().copyWith(color: V2Colors.fgSubtle),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayButton extends StatefulWidget {
  const _PayButton({
    required this.placing,
    required this.onTap,
    this.compact = false,
    this.totalLabel,
    this.label,
    this.icon,
  });

  final bool placing;
  final VoidCallback onTap;
  final bool compact;
  final String? totalLabel;
  final String? label;
  final IconData? icon;

  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.label == null;
    final text = widget.label ??
        (widget.placing ? 'Opening Razorpay…' : 'Pay ${widget.totalLabel ?? ''}');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.placing ? null : widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(
              vertical: widget.compact ? 14 : 18,
              horizontal: widget.compact ? 16 : 24,
            ),
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _hover
                          ? [const Color(0xFF1A1A22), V2Colors.ink]
                          : [V2Colors.ink, const Color(0xFF252530)],
                    )
                  : null,
              color: isPrimary ? null : V2Colors.plasma,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: V2Colors.ink.withValues(alpha: _hover ? 0.22 : 0.14),
                  blurRadius: _hover ? 24 : 16,
                  offset: Offset(0, _hover ? 10 : 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.placing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    widget.icon ?? Icons.lock_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2FontStyles.inter(
                      fontSize: widget.compact ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
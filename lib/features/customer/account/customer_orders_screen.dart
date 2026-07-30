import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/route_names.dart';
import '../../shop/data/shop_order_repository.dart';
import '../../shop/domain/shop_order.dart';
import '../../web_public/pages/shop/widgets/store_atoms.dart';
import '../../web_public/v2/v2_animate_export.dart';
import '../../web_public/v2/v2_colors.dart';
import '../../web_public/v2/v2_font_styles.dart';
import '../../web_public/v2/v2_text.dart';
import 'customer_account_shell.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final _repo = ShopOrderRepository();
  List<ShopOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.listMyOrders();
    if (mounted) {
      setState(() {
        _orders = list;
        _loading = false;
      });
    }
  }

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  Color _statusColor(String status) {
    return switch (status) {
      'delivered' => V2Colors.aurora,
      'shipped' => V2Colors.plasma,
      'paid' || 'processing' => V2Colors.ember,
      'cancelled' => const Color(0xFFDC2626),
      _ => V2Colors.fgSubtle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');
    return CustomerAccountShell(
      activeTab: CustomerAccountTab.account,
      backFallback: RouteNames.accountHome,
      title: 'My orders',
      subtitle: 'Track purchases, pay pending orders, or order again',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : _orders.isEmpty
              ? AccountEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  message: 'When you place an order from the shop, it will appear here with live status.',
                  actionLabel: 'Start shopping',
                  onAction: () => context.go(RouteNames.publicStore),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final o = _orders[i];
                      return _OrderCard(
                        order: o,
                        dateFmt: dateFmt,
                        statusColor: _statusColor(o.status),
                        shortId: _shortId(o.id),
                        onTap: () => context.push(RouteNames.accountOrderDetail(o.id)),
                      ).animate(delay: (40 * i).ms).fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0);
                    },
                  ),
                ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    required this.order,
    required this.dateFmt,
    required this.statusColor,
    required this.shortId,
    required this.onTap,
  });

  final ShopOrder order;
  final DateFormat dateFmt;
  final Color statusColor;
  final String shortId;
  final VoidCallback onTap;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.01 : 1,
          duration: const Duration(milliseconds: 180),
          child: AccountGlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: widget.statusColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #${widget.shortId}', style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          o.statusLabel,
                          if (o.createdAt != null) widget.dateFmt.format(o.createdAt!.toLocal()),
                        ].join(' · '),
                        style: V2Text.small().copyWith(color: V2Colors.fgSubtle),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatINR(o.totalAmount), style: V2FontStyles.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Icon(Icons.chevron_right_rounded, color: V2Colors.fgFaint, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_admin_repository.dart';

/// Store overview — modern e-commerce admin dashboard (Shopify / seller-center style).
class AdminShopHubScreen extends StatefulWidget {
  const AdminShopHubScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminShopHubScreen> createState() => _AdminShopHubScreenState();
}

class _AdminShopHubScreenState extends State<AdminShopHubScreen> {
  final _adminRepo = ShopAdminRepository();
  ShopAdminDashboardData? _data;
  bool _loading = true;

  static const _bg = Color(0xFFF8FAFC);
  static const _card = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _shopGreen = Color(0xFF059669);

  void _go(String route) {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
    } else {
      context.push(route);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _adminRepo.loadDashboard();
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            color: _shopGreen,
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    _DashboardHeader(onRefresh: _load, onAddProduct: () => _go(RouteNames.adminShopProducts)),
                    const SizedBox(height: 20),
                    _PrimaryMetricsRow(data: _data!, wide: wide),
                    const SizedBox(height: 16),
                    _SecondaryMetricsRow(data: _data!, wide: wide),
                    const SizedBox(height: 20),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _OrdersPanel(data: _data!, onViewAll: () => _go(RouteNames.adminShopOrders))),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _OrderStatusChart(data: _data!),
                                const SizedBox(height: 16),
                                _CartsPanel(data: _data!, onViewOrders: () => _go(RouteNames.adminShopOrders)),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _OrdersPanel(data: _data!, onViewAll: () => _go(RouteNames.adminShopOrders)),
                      const SizedBox(height: 16),
                      _OrderStatusChart(data: _data!),
                      const SizedBox(height: 16),
                      _CartsPanel(data: _data!, onViewOrders: () => _go(RouteNames.adminShopOrders)),
                    ],
                    const SizedBox(height: 20),
                    _QuickActionsGrid(onNavigate: _go),
                    const SizedBox(height: 20),
                    if (_data!.lowStockProducts.isNotEmpty)
                      _LowStockPanel(
                        items: _data!.lowStockProducts,
                        onManage: () => _go(RouteNames.adminShopInventory),
                      ),
                    if (_data!.recentProducts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _TopProductsRow(
                        products: _data!.recentProducts,
                        onViewAll: () => _go(RouteNames.adminShopProducts),
                      ),
                    ],
                  ],
                );
              },
            ),
          );

    return AdminEmbeddedScaffold(
      title: 'Overview',
      embedded: widget.embedded,
      showEmbeddedTitle: false,
      embeddedBackgroundColor: _bg,
      body: body,
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onRefresh, required this.onAddProduct});

  final VoidCallback onRefresh;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Store overview', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _AdminShopHubScreenState._text, height: 1.15)),
              const SizedBox(height: 6),
              Text(date, style: GoogleFonts.inter(fontSize: 13, color: _AdminShopHubScreenState._muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onAddProduct,
          style: FilledButton.styleFrom(
            backgroundColor: _AdminShopHubScreenState._shopGreen,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Add product', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AdminShopHubScreenState._card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _AdminShopHubScreenState._border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const Spacer(),
                  if (onTap != null) Icon(Icons.arrow_outward_rounded, size: 16, color: accent.withValues(alpha: 0.8)),
                ],
              ),
              const SizedBox(height: 16),
              Text(value, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _AdminShopHubScreenState._text)),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _AdminShopHubScreenState._text)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: _AdminShopHubScreenState._muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryMetricsRow extends StatelessWidget {
  const _PrimaryMetricsRow({required this.data, required this.wide});

  final ShopAdminDashboardData data;
  final bool wide;

  String _inr(double n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Total revenue',
        value: _inr(data.totalRevenue),
        subtitle: 'All shop orders',
        icon: Icons.payments_rounded,
        accent: const Color(0xFF059669),
        onTap: null,
      ),
      _MetricCard(
        label: 'Orders',
        value: '${data.orders}',
        subtitle: '${data.pendingOrders} need attention',
        icon: Icons.receipt_long_rounded,
        accent: const Color(0xFF2563EB),
      ),
      _MetricCard(
        label: 'Live products',
        value: '${data.activeProducts}',
        subtitle: '${data.products} total SKUs',
        icon: Icons.inventory_2_rounded,
        accent: const Color(0xFF7C3AED),
      ),
      _MetricCard(
        label: 'Active carts',
        value: '${data.activeCarts}',
        subtitle: '${data.cartLineItems} items in carts',
        icon: Icons.shopping_cart_rounded,
        accent: const Color(0xFF0EA5E9),
      ),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }
}

class _SecondaryMetricsRow extends StatelessWidget {
  const _SecondaryMetricsRow({required this.data, required this.wide});

  final ShopAdminDashboardData data;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _AdminShopHubScreenState._card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _AdminShopHubScreenState._border),
          ),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(label, style: GoogleFonts.inter(fontSize: 11, color: _AdminShopHubScreenState._muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final chips = [
      chip('Categories', '${data.categories}', const Color(0xFF6366F1)),
      chip('Sub-categories', '${data.subCategories}', const Color(0xFF3B82F6)),
      chip('Brands', '${data.brands}', const Color(0xFFF59E0B)),
      chip('Low stock', '${data.lowStockCount}', data.lowStockCount > 0 ? AppColors.error : AppColors.success),
    ];

    if (wide) {
      return Row(children: [for (var i = 0; i < chips.length; i++) ...[if (i > 0) const SizedBox(width: 10), chips[i]]]);
    }
    return Column(
      children: [
        Row(children: [chips[0], const SizedBox(width: 10), chips[1]]),
        const SizedBox(height: 10),
        Row(children: [chips[2], const SizedBox(width: 10), chips[3]]),
      ],
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AdminShopHubScreenState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AdminShopHubScreenState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _AdminShopHubScreenState._text)),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: _AdminShopHubScreenState._border),
          child,
        ],
      ),
    );
  }
}

class _OrdersPanel extends StatelessWidget {
  const _OrdersPanel({required this.data, required this.onViewAll});

  final ShopAdminDashboardData data;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final orders = data.recentOrders;
    return _PanelShell(
      title: 'Recent orders',
      trailing: TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: orders.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No orders yet', style: GoogleFonts.inter(color: _AdminShopHubScreenState._muted)),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(
                    children: [
                      _TableHead('Order', flex: 2),
                      _TableHead('Status', flex: 2),
                      _TableHead('Amount', flex: 1, align: TextAlign.end),
                    ],
                  ),
                ),
                for (var i = 0; i < orders.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18, color: _AdminShopHubScreenState._border),
                  _OrderRow(order: orders[i]),
                ],
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.text, {required this.flex, this.align = TextAlign.start});

  final String text;
  final int flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _AdminShopHubScreenState._muted, letterSpacing: 0.6),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final id = (order['id'] as String? ?? '').length > 8 ? (order['id'] as String).substring(0, 8) : order['id'];
    final status = order['status'] as String? ?? '—';
    final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final created = order['created_at'] as String?;
    final dt = created != null ? DateTime.tryParse(created) : null;
    final dateStr = dt != null ? DateFormat('dd MMM, HH:mm').format(dt) : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#$id', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: _AdminShopHubScreenState._muted)),
              ],
            ),
          ),
          Expanded(flex: 2, child: _StatusBadge(status: status)),
          Expanded(
            flex: 1,
            child: Text(
              NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount),
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = _AdminShopHubScreenState._muted;
    switch (status) {
      case 'paid':
      case 'delivered':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'pending_payment':
      case 'draft':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'processing':
      case 'shipped':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        break;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(
          status.replaceAll('_', ' '),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
        ),
      ),
    );
  }
}

class _OrderStatusChart extends StatelessWidget {
  const _OrderStatusChart({required this.data});

  final ShopAdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final entries = data.orderStatusCounts.entries.toList();
    if (entries.isEmpty) {
      return _PanelShell(
        title: 'Orders by status',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No order data yet', style: GoogleFonts.inter(color: _AdminShopHubScreenState._muted)),
        ),
      );
    }

    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    final colors = [const Color(0xFF059669), const Color(0xFF2563EB), const Color(0xFFF59E0B), const Color(0xFFEF4444), const Color(0xFF8B5CF6)];

    return _PanelShell(
      title: 'Orders by status',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 20),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY < 1 ? 1 : maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY < 2 ? 1 : (maxY / 4).ceilToDouble(),
                getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.inter(fontSize: 10, color: _AdminShopHubScreenState._muted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                      final label = entries[i].key.replaceAll('_', '\n');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(label, style: GoogleFonts.inter(fontSize: 9, color: _AdminShopHubScreenState._muted), textAlign: TextAlign.center),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value.toDouble(),
                        color: colors[i % colors.length],
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
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

class _CartsPanel extends StatelessWidget {
  const _CartsPanel({required this.data, required this.onViewOrders});

  final ShopAdminDashboardData data;
  final VoidCallback onViewOrders;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: 'Live shopping carts',
      trailing: Text('${data.activeCarts} active', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _AdminShopHubScreenState._shopGreen)),
      child: data.recentCarts.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No active carts', style: GoogleFonts.inter(color: _AdminShopHubScreenState._muted)),
            )
          : Column(
              children: [
                for (var i = 0; i < data.recentCarts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                      child: const Icon(Icons.person_outline, color: Color(0xFF0EA5E9), size: 20),
                    ),
                    title: Text('Customer · ${data.recentCarts[i].firebaseUid.length > 6 ? data.recentCarts[i].firebaseUid.substring(0, 6) : data.recentCarts[i].firebaseUid}…', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text('${data.recentCarts[i].itemCount} products · ${data.recentCarts[i].totalQty} qty'),
                    trailing: Text(
                      data.recentCarts[i].updatedAt != null ? DateFormat('HH:mm').format(data.recentCarts[i].updatedAt!) : '',
                      style: GoogleFonts.inter(fontSize: 11, color: _AdminShopHubScreenState._muted),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(onPressed: onViewOrders, child: const Text('Open orders')),
                ),
              ],
            ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction('Categories', Icons.category_rounded, const Color(0xFF6366F1), RouteNames.adminShopCategories),
      _QuickAction('Sub categories', Icons.account_tree_rounded, const Color(0xFF3B82F6), RouteNames.adminShopSubCategories),
      _QuickAction('Products', Icons.inventory_2_rounded, const Color(0xFF059669), RouteNames.adminShopProducts),
      _QuickAction('Inventory', Icons.warehouse_rounded, const Color(0xFF64748B), RouteNames.adminShopInventory),
      _QuickAction('Purchases', Icons.add_shopping_cart_rounded, const Color(0xFF0D9488), RouteNames.adminShopPurchases),
      _QuickAction('Suppliers', Icons.local_shipping_rounded, const Color(0xFF78716C), RouteNames.adminShopSuppliers),
      _QuickAction('Customers', Icons.people_outline_rounded, const Color(0xFF6366F1), RouteNames.adminShopCustomers),
      _QuickAction('Quotations', Icons.request_quote_rounded, const Color(0xFF8B5CF6), RouteNames.adminShopQuotations),
      _QuickAction('Reports', Icons.assessment_rounded, const Color(0xFF475569), RouteNames.adminShopReports),
      _QuickAction('Brands', Icons.branding_watermark_rounded, const Color(0xFFF59E0B), RouteNames.adminShopBrands),
      _QuickAction('Attributes', Icons.tune_rounded, const Color(0xFF7C3AED), RouteNames.adminShopAttributeMaster),
      _QuickAction('Attr. groups', Icons.view_module_rounded, const Color(0xFF8B5CF6), RouteNames.adminShopAttributeGroups),
      _QuickAction('Orders', Icons.receipt_long_rounded, const Color(0xFFEF4444), RouteNames.adminShopOrders),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manage store', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _AdminShopHubScreenState._text)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 520 ? 4 : 2;
            return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            for (final a in actions)
              Material(
                color: _AdminShopHubScreenState._card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => onNavigate(a.route),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _AdminShopHubScreenState._border),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(a.icon, color: a.color, size: 26),
                        const SizedBox(height: 8),
                        Text(a.label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
          },
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.color, this.route);
  final String label;
  final IconData icon;
  final Color color;
  final String route;
}

class _LowStockPanel extends StatelessWidget {
  const _LowStockPanel({required this.items, required this.onManage});

  final List<Map<String, dynamic>> items;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: 'Low stock alert',
      trailing: TextButton(onPressed: onManage, child: const Text('Manage inventory')),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C)),
              title: Text(items[i]['name'] as String? ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              subtitle: Text('SKU ${items[i]['sku']}'),
              trailing: Text('${items[i]['qty']} left', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFFEA580C))),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopProductsRow extends StatelessWidget {
  const _TopProductsRow({required this.products, required this.onViewAll});

  final List<Map<String, dynamic>> products;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Latest products', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(onPressed: onViewAll, child: const Text('View catalog')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final p = products[i];
              final price = (p['base_price'] as num?)?.toDouble() ?? 0;
              final active = p['is_active'] as bool? ?? true;
              return Container(
                width: 200,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _AdminShopHubScreenState._card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _AdminShopHubScreenState._border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(p['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13))),
                        if (!active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                            child: Text('Hidden', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(p['sku'] as String? ?? '', style: GoogleFonts.inter(fontSize: 11, color: _AdminShopHubScreenState._muted)),
                    Text(NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(price), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _AdminShopHubScreenState._shopGreen)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

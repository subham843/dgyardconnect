import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';
import '../data/marketplace_order_repository.dart';
import 'marketplace_format.dart';
import 'widgets/marketplace_status_chip.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceOrderDetailScreen extends StatefulWidget {
  const MarketplaceOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<MarketplaceOrderDetailScreen> createState() => _MarketplaceOrderDetailScreenState();
}

class _MarketplaceOrderDetailScreenState extends State<MarketplaceOrderDetailScreen> {
  final _repo = MarketplaceOrderRepository();
  bool _loading = true;
  Map<String, dynamic>? _header;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lines = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _repo.getOrderDoc(widget.orderId);
    final lines = await _repo.getOrderLines(widget.orderId);
    if (!mounted) return;
    setState(() {
      _header = doc?.data();
      _lines = lines;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyWidget = _loading
        ? const Center(child: CircularProgressIndicator())
        : _header == null
            ? const Center(child: Text('Order not found'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  MarketplaceStatusChip(
                    label: (_header!['status'] as String? ?? '').replaceAll('_', ' '),
                    tone: MarketplaceChipTone.neutral,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    marketplaceFormatInr((_header!['total_paise'] as num?)?.toInt() ?? 0),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Payment: ${_header!['payment_method']}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Text('Lines', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ..._lines.map((d) {
                    final m = d.data();
                    final title = m['title_snapshot'] as String? ?? '';
                    final qty = (m['quantity'] as num?)?.toInt() ?? 0;
                    final unit = (m['unit_price_paise'] as num?)?.toInt() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(child: Text('$title × $qty')),
                          Text(marketplaceFormatInr(unit * qty)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Text(
                    'Fulfillment is managed by D.G.Yard. Tracking and invoices appear here as operations progress.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Order detail')),
      body: Column(
        children: [
          Expanded(child: bodyWidget),
        ],
      ),
    );
  }
}

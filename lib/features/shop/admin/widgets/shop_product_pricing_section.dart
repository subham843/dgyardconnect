import 'package:flutter/material.dart';

import '../../domain/shop_pricing.dart';

/// Purchase → MRP → online (customer) → dealer; auto discount % from MRP.
class ShopProductPricingSection extends StatefulWidget {
  const ShopProductPricingSection({
    super.key,
    required this.costController,
    required this.mrpController,
    required this.onlineController,
    required this.dealerController,
  });

  final TextEditingController costController;
  final TextEditingController mrpController;
  final TextEditingController onlineController;
  final TextEditingController dealerController;

  @override
  State<ShopProductPricingSection> createState() => _ShopProductPricingSectionState();
}

class _ShopProductPricingSectionState extends State<ShopProductPricingSection> {
  @override
  void initState() {
    super.initState();
    for (final c in [
      widget.costController,
      widget.mrpController,
      widget.onlineController,
      widget.dealerController,
    ]) {
      c.addListener(_rebuid);
    }
  }

  @override
  void dispose() {
    for (final c in [
      widget.costController,
      widget.mrpController,
      widget.onlineController,
      widget.dealerController,
    ]) {
      c.removeListener(_rebuid);
    }
    super.dispose();
  }

  void _rebuid() {
    if (mounted) setState(() {});
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim());

  @override
  Widget build(BuildContext context) {
    final mrp = _parse(widget.mrpController);
    final online = _parse(widget.onlineController);
    final dealer = _parse(widget.dealerController);
    final onlineDisc = ShopPricing.discountLabel(mrp, online, 'Online (customer)');
    final dealerDisc = ShopPricing.discountLabel(mrp, dealer, 'Dealer / technician');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.costController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Purchase price',
            border: OutlineInputBorder(),
            helperText: 'Cost / purchase rate (inventory & accounts)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.mrpController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'MRP',
            border: OutlineInputBorder(),
            helperText: 'Maximum retail price — used to calculate discounts',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.onlineController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Online sales price *',
            border: OutlineInputBorder(),
            helperText: 'Shown to customers on shop',
          ),
        ),
        if (onlineDisc != null) _discountChip(context, onlineDisc),
        const SizedBox(height: 12),
        TextField(
          controller: widget.dealerController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Dealer price',
            border: OutlineInputBorder(),
            helperText: 'Shown to dealers & technicians',
          ),
        ),
        if (dealerDisc != null) _discountChip(context, dealerDisc),
      ],
    );
  }

  Widget _discountChip(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: Icon(Icons.percent, size: 18, color: Theme.of(context).colorScheme.primary),
          label: Text(text, style: Theme.of(context).textTheme.bodySmall),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

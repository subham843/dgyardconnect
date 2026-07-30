import 'package:flutter/material.dart';

import '../../domain/shop_pricing.dart';

/// Purchase receipt line: MRP + online + dealer with discount hints.
class AdminShopPurchaseLinePricingFields extends StatefulWidget {
  const AdminShopPurchaseLinePricingFields({
    super.key,
    required this.mrpController,
    required this.onlineController,
    required this.dealerController,
  });

  final TextEditingController mrpController;
  final TextEditingController onlineController;
  final TextEditingController dealerController;

  @override
  State<AdminShopPurchaseLinePricingFields> createState() => _AdminShopPurchaseLinePricingFieldsState();
}

class _AdminShopPurchaseLinePricingFieldsState extends State<AdminShopPurchaseLinePricingFields> {
  @override
  void initState() {
    super.initState();
    for (final c in [widget.mrpController, widget.onlineController, widget.dealerController]) {
      c.addListener(() => setState(() {}));
    }
  }

  double? _p(TextEditingController c) => double.tryParse(c.text.trim());

  @override
  Widget build(BuildContext context) {
    final mrp = _p(widget.mrpController);
    final onlineDisc = ShopPricing.discountLabel(mrp, _p(widget.onlineController), 'Online');
    final dealerDisc = ShopPricing.discountLabel(mrp, _p(widget.dealerController), 'Dealer');

    return Column(
      children: [
        TextField(
          controller: widget.mrpController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.onlineController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Online sales price',
            border: OutlineInputBorder(),
            helperText: 'Customer shop price',
          ),
        ),
        if (onlineDisc != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Align(alignment: Alignment.centerLeft, child: Text(onlineDisc, style: Theme.of(context).textTheme.bodySmall)),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.dealerController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Dealer price',
            border: OutlineInputBorder(),
            helperText: 'Dealer / technician price',
          ),
        ),
        if (dealerDisc != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(alignment: Alignment.centerLeft, child: Text(dealerDisc, style: Theme.of(context).textTheme.bodySmall)),
          ),
      ],
    );
  }
}

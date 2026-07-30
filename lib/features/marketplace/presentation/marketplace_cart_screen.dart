import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../state/marketplace_cart_controller.dart';
import 'marketplace_format.dart';
import 'widgets/marketplace_premium_shell.dart';

class MarketplaceCartScreen extends StatelessWidget {
  const MarketplaceCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<MarketplaceCartController>();
    final theme = Theme.of(context);

    final bodyWidget = cart.items.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Your cart is empty.',
                style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cart.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final line = cart.items[i];
              final sub = line.lineSubtotalPaise();
              final unit = line.unitPaiseForQuantity(line.quantity);
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.titleSnapshot,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${marketplaceFormatInr(unit)} × ${line.quantity}',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  onPressed: line.quantity > line.moq
                                      ? () => cart.setQuantity(line.id, line.quantity - 1)
                                      : null,
                                  icon: const Icon(Icons.remove, size: 20),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(36, 36),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('${line.quantity}', style: theme.textTheme.titleMedium),
                                ),
                                IconButton.filledTonal(
                                  onPressed: () => cart.setQuantity(line.id, line.quantity + 1),
                                  icon: const Icon(Icons.add, size: 20),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(36, 36),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            marketplaceFormatInr(sub),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          TextButton(
                            onPressed: () => cart.removeLine(line.id),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          Expanded(child: bodyWidget),
        ],
      ),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: theme.textTheme.titleMedium),
                      Text(
                        marketplaceFormatInr(cart.totalPaise),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push(RouteNames.marketplaceCheckout),
                    child: const Text('Checkout'),
                  ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../calculator/domain/calculator_models.dart';
import '../../data/repositories/public_store_repository.dart';
import '../../state/public_cart.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_text.dart';
import '../../v2/v2_tokens.dart';
import '../shop/widgets/store_atoms.dart';
import 'calculator_price_privacy.dart';

/// Quick view dialog for calculator suggested products.
Future<void> showCalculatorSuggestedQuickView(
  BuildContext context, {
  required CalculatorProductOption option,
  VoidCallback? onSelect,
}) {
  final isMobile = V2Responsive(context).isMobile;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) => Dialog(
      backgroundColor: V2Colors.surface,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? V2.s4 : V2.s12,
        vertical: V2.s8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V2.r2xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 560),
        child: _CalculatorSuggestedQuickViewBody(
          option: option,
          onSelect: () {
            Navigator.pop(dialogContext);
            onSelect?.call();
          },
          onViewDetails: (slug) {
            Navigator.pop(dialogContext);
            context.push('/product/$slug');
          },
        ),
      ),
    ),
  );
}

class _CalculatorSuggestedQuickViewBody extends StatefulWidget {
  const _CalculatorSuggestedQuickViewBody({
    required this.option,
    required this.onSelect,
    required this.onViewDetails,
  });

  final CalculatorProductOption option;
  final VoidCallback onSelect;
  final void Function(String slug) onViewDetails;

  @override
  State<_CalculatorSuggestedQuickViewBody> createState() =>
      _CalculatorSuggestedQuickViewBodyState();
}

class _CalculatorSuggestedQuickViewBodyState
    extends State<_CalculatorSuggestedQuickViewBody> {
  final _store = PublicStoreRepository();
  ProductDetailData? _detail;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _store.loadProductDetail(widget.option.productId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        if (detail == null) _error = 'Product details unavailable';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load product';
      });
    }
  }

  void _addToCart() {
    final p = _detail?.product;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for product to load, then try again'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    PublicCart.instance.addProduct(p);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.name} added to cart'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: V2Colors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = V2Responsive(context).isMobile;
    final opt = widget.option;
    final product = _detail?.product;
    final imageUrl = (product?.imageUrl ?? opt.imageUrl)?.trim() ?? '';
    final name = product?.name ?? opt.label;
    final brand = product?.brandName;
    final price = product?.price ?? opt.unitPrice;
    final mrp = product?.mrp;
    final desc = product?.shortDescription ?? product?.description;
    final sku = product?.sku ?? opt.sku;
    final specs = _detail?.specs.take(6).toList() ?? const [];

    Widget image() {
      if (imageUrl.isEmpty) {
        return const ColoredBox(
          color: Color(0xFFF3F3F5),
          child: Center(
            child: Icon(Icons.inventory_2_outlined, color: V2Colors.fgFaint, size: 48),
          ),
        );
      }
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Color(0xFFF3F3F5),
          child: Center(
            child: Icon(Icons.image_outlined, color: V2Colors.fgFaint, size: 48),
          ),
        ),
      );
    }

    Widget info() {
      if (_loading) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(V2.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((brand ?? '').isNotEmpty)
              Text(
                brand!.toUpperCase(),
                style: V2Text.micro().copyWith(color: V2Colors.ember),
              ),
            const SizedBox(height: 6),
            Text(name, style: V2Text.h3(context)),
            if ((sku ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'SKU $sku',
                style: V2Text.micro().copyWith(color: V2Colors.fgFaint),
              ),
            ],
            const SizedBox(height: V2.s4),
            if (!CalculatorPricePrivacy.canSeePrices)
              Text(
                CalculatorPricePrivacy.masked,
                style: V2Text.h3(context).copyWith(color: V2Colors.ink),
              )
            else if (price != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatINR(price),
                    style: V2Text.h3(context).copyWith(color: V2Colors.ink),
                  ),
                  if (mrp != null && mrp > price) ...[
                    const SizedBox(width: 10),
                    Text(
                      formatINR(mrp),
                      style: V2Text.body().copyWith(
                        color: V2Colors.fgSubtle,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              )
            else
              Text(
                'Price on request',
                style: V2Text.body().copyWith(color: V2Colors.fgSubtle),
              ),
            if (!CalculatorPricePrivacy.canSeePrices) ...[
              const SizedBox(height: 6),
              Text(
                'Login to show price',
                style: V2Text.micro().copyWith(color: V2Colors.fgSubtle),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: V2Text.small().copyWith(color: V2Colors.fgSubtle)),
            ],
            if ((desc ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: V2.s4),
              Text(
                desc!.trim(),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: V2Text.body(),
              ),
            ],
            if (specs.isNotEmpty) ...[
              const SizedBox(height: V2.s6),
              Text(
                'Key specs',
                style: V2Text.small().copyWith(
                  fontWeight: FontWeight.w700,
                  color: V2Colors.ink,
                ),
              ),
              const SizedBox(height: 8),
              for (final s in specs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          s.label,
                          style: V2Text.micro().copyWith(color: V2Colors.fgSubtle),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          s.value,
                          style: V2Text.small().copyWith(color: V2Colors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: V2.s8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: V2Colors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: widget.onSelect,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Use this'),
                  ),
                ),
                const SizedBox(width: V2.s2),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: V2Colors.plasma,
                      side: const BorderSide(color: V2Colors.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final slug = product?.slug ?? opt.productId;
                      widget.onViewDetails(slug);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Details'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('Add to cart'),
              ),
            ),
          ],
        ),
      );
    }

    final content = isMobile
        ? Column(
            children: [
              SizedBox(height: 200, width: double.infinity, child: image()),
              Expanded(child: SingleChildScrollView(child: info())),
            ],
          )
        : SizedBox(
            height: 460,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 360, child: image()),
                const VerticalDivider(width: 1, color: V2Colors.border),
                Expanded(child: SingleChildScrollView(child: info())),
              ],
            ),
          );

    return Stack(
      children: [
        content,
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    );
  }
}
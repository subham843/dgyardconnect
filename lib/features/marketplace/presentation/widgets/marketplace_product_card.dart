import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/marketplace_catalog_product.dart';
import '../marketplace_format.dart';

class MarketplaceProductCard extends StatelessWidget {
  const MarketplaceProductCard({super.key, required this.product});

  final MarketplaceCatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final subtitle = _catalogSubtitle(product);
    final startingAtPaise = product.effectiveUnitPaiseForQuantity(product.moq);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RouteNames.marketplaceProduct(product.id)),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: AppColors.surfaceVariant),
                          errorWidget: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _applyProductWordingRules(product.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Starting at ${marketplaceFormatInr(startingAtPaise)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.offerActive) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          product.offerDiscountPercent != null
                              ? 'Offer -${product.offerDiscountPercent}%'
                              : 'Offer',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (product.moq > 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        'MOQ ${product.moq}',
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _catalogSubtitle(MarketplaceCatalogProduct product) {
    final bits = <String>[];
    if (product.subcategoryName.trim().isNotEmpty) {
      bits.add(_applyProductWordingRules(product.subcategoryName.trim()));
    } else if (product.categoryName.trim().isNotEmpty) {
      bits.add(_applyProductWordingRules(product.categoryName.trim()));
    }
    for (final e in product.attributeSelections.entries.take(2)) {
      final rawKey = e.key.replaceAll('_', ' ').trim();
      final keyLower = rawKey.toLowerCase();
      final prettyVal = _applyProductWordingRules(e.value.toString().trim());

      if (keyLower == 'brands') {
        // Premium summary: show the brand value only.
        bits.add(_titleCasePreservingCaps(prettyVal));
        continue;
      }

      if (keyLower == 'camera type') {
        // Premium summary: show value + "Type" without a key label.
        final base = _titleCasePreservingCaps(prettyVal);
        bits.add(base.toLowerCase().endsWith('type') ? base : '$base Type');
        continue;
      }

      final prettyKey = _titleCasePreservingCaps(rawKey);
      bits.add('$prettyKey: $prettyVal');
    }
    return bits.join(' • ');
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
    );
  }

  static String _applyProductWordingRules(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;

    // Targeted premium re-wording for common CCTV catalog text.
    s = s.replaceAll(RegExp(r'2\s*mp\s*camera\s*cctv', caseSensitive: false), '2MP CCTV Camera');
    s = s.replaceAll(RegExp(r'\bhdd\b', caseSensitive: false), 'Hard Drive');

    // Title-case remaining fully-lowercase segments for premium presentation.
    final normalized = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isNotEmpty &&
        normalized == normalized.toLowerCase() &&
        RegExp(r'^[a-z0-9 ]+$').hasMatch(normalized)) {
      s = _titleCasePreservingCaps(normalized);
    }

    return s;
  }

  static String _titleCasePreservingCaps(String input) {
    final words = input.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
    return words
        .map((w) {
          if (w.length <= 3 && w.toLowerCase() == w) return w.toUpperCase();
          if (w.toUpperCase() == w) return w; // keep acronyms/brand caps
          if (w.length == 1) return w.toUpperCase();
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}

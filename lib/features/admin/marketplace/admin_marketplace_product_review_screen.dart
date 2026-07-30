import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/firestore_service.dart';
import '../../marketplace/data/marketplace_admin_actions.dart';
import '../../marketplace/data/marketplace_listing_repository.dart';
import '../../marketplace/data/marketplace_taxonomy_repository.dart';
import '../../marketplace/domain/marketplace_listing.dart';
import '../../marketplace/domain/marketplace_taxonomy.dart';

class AdminMarketplaceProductReviewScreen extends StatefulWidget {
  const AdminMarketplaceProductReviewScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<AdminMarketplaceProductReviewScreen> createState() => _AdminMarketplaceProductReviewScreenState();
}

class _AdminMarketplaceProductReviewScreenState extends State<AdminMarketplaceProductReviewScreen> {
  final _repo = MarketplaceListingRepository();
  final _tax = MarketplaceTaxonomyRepository();
  final _finalPrice = TextEditingController();
  final _rejectReason = TextEditingController();
  MarketplaceListing? _listing;
  bool _loading = true;
  bool _busy = false;
  bool _sendTaxonomySuggestion = true;

  String _sugCategoryId = '';
  String _sugSubcategoryId = '';
  String _sugCategoryName = '';
  String _sugSubcategoryName = '';
  Map<String, String> _sugAttrs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await _repo.getListing(widget.listingId);
    if (!mounted) return;
    setState(() {
      _listing = l;
      if (l != null) {
        _finalPrice.text = (l.proposedPricePaise / 100).toStringAsFixed(l.proposedPricePaise % 100 == 0 ? 0 : 2);
        _sugCategoryId = l.categoryId;
        _sugCategoryName = l.categoryName;
        if (l.usesProposedNewSubcategory) {
          _sugSubcategoryId = '';
          _sugSubcategoryName = '';
        } else {
          _sugSubcategoryId = l.subcategoryId;
          _sugSubcategoryName = l.subcategoryName;
        }
        _sugAttrs = Map<String, String>.from(l.attributeSelections);
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _finalPrice.dispose();
    _rejectReason.dispose();
    super.dispose();
  }

  Widget _suggestionAttributeDropdowns() {
    if (_sugCategoryId.isEmpty || _sugSubcategoryId.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<MarketplaceAttributeDef>>(
      stream: _tax.watchAttributes(_sugCategoryId, _sugSubcategoryId),
      builder: (context, attrSnap) {
        final defs = attrSnap.data ?? [];
        if (defs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: defs.map((def) {
            final cur = _sugAttrs[def.key];
            final valid = cur != null && def.values.contains(cur);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('sug_attr_${def.id}_$cur'),
                initialValue: valid ? cur : null,
                decoration: InputDecoration(
                  labelText: def.label + (def.required ? ' *' : ''),
                  border: const OutlineInputBorder(),
                ),
                items: def.values.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                onChanged: _busy
                    ? null
                    : (val) {
                        setState(() {
                          if (val == null) {
                            _sugAttrs.remove(def.key);
                          } else {
                            _sugAttrs = Map<String, String>.from(_sugAttrs)..[def.key] = val;
                          }
                        });
                      },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l = _listing;
    if (l == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('Listing not found')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review listing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Seller UID: ${l.sellerUid}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Text(l.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
          const SizedBox(height: 20),
          Text('Seller taxonomy', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '${l.categoryName.isNotEmpty ? l.categoryName : l.categoryId} → ${l.subcategoryName.isNotEmpty ? l.subcategoryName : l.subcategoryId}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
          if (l.usedOtherSubcategory && l.entryCategoryName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Via Others from: ${l.entryCategoryName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
            ),
          ],
          if (l.attributeSelections.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.attributeSelections.entries.map((e) => '${e.key}: ${e.value}').join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
            ),
          ],
          if (l.deletionRequested) ...[
            const SizedBox(height: 16),
            Material(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Seller requested removal from the buyer catalog. Approving deletes the live product and archives the listing.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (l.priceTiers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Seller quantity pricing (per unit)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...l.priceTiers.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${t.quantityLabel()}: ${(t.pricePaise / 100).toStringAsFixed(t.pricePaise % 100 == 0 ? 0 : 2)} INR',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ),
            ),
          ],
          if (l.usesProposedNewSubcategory || l.sellerProposedFeatureDefs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Seller-proposed subcategory & features',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Publishing creates this subcategory and attribute docs under “${l.categoryName.isNotEmpty ? l.categoryName : l.categoryId}”, then lists the product.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                  if (l.sellerProposedFeatureDefs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No extra features — only the new subcategory name.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...l.sellerProposedFeatureDefs.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.label} · key ${d.key}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.usesTextInput
                                  ? 'Free text (seller typed: ${l.attributeSelections[d.key] ?? '—'})'
                                  : d.values.join(', '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!l.deletionRequested)
            TextField(
              controller: _finalPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.catalogProductId != null && (l.catalogProductId ?? '').isNotEmpty
                    ? 'Final buyer base price (INR)'
                    : 'Final buyer price (INR)',
                helperText: l.priceTiers.isNotEmpty
                    ? 'Used to scale all quantity bands to desk-approved buyer pricing.'
                    : (l.usesProposedNewSubcategory
                        ? 'On publish, proposed taxonomy is created first, then the product goes live.'
                        : 'Includes D.G.Yard margin, logistics, risk buffer as priced by desk.'),
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _rejectReason,
            decoration: const InputDecoration(
              labelText: 'Reject reason',
              helperText: 'Required to reject. Seller sees this on the listing.',
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suggest category & features to seller'),
            subtitle: const Text('If on, seller can apply your picks after rejection. Turn off to clear any old suggestions.'),
            value: _sendTaxonomySuggestion,
            onChanged: _busy ? null : (v) => setState(() => _sendTaxonomySuggestion = v),
          ),
          if (_sendTaxonomySuggestion) ...[
            const SizedBox(height: 8),
            Text(
              'Adjust below so the seller sees exactly what to select when they re-open the listing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<MarketplaceCategoryNode>>(
              stream: _tax.watchCategories(activeOnly: true),
              builder: (context, catSnap) {
                final cats = catSnap.data ?? [];
                return DropdownButtonFormField<String>(
                  key: ValueKey<String>('sug_cat_$_sugCategoryId'),
                  initialValue: _sugCategoryId.isNotEmpty && cats.any((c) => c.id == _sugCategoryId) ? _sugCategoryId : null,
                  decoration: const InputDecoration(
                    labelText: 'Suggested category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('Select…')),
                    ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() {
                            _sugCategoryId = v ?? '';
                            _sugSubcategoryId = '';
                            _sugSubcategoryName = '';
                            _sugAttrs = {};
                            _sugCategoryName = '';
                            if (_sugCategoryId.isNotEmpty) {
                              for (final c in cats) {
                                if (c.id == _sugCategoryId) {
                                  _sugCategoryName = c.name;
                                  break;
                                }
                              }
                            }
                          });
                        },
                );
              },
            ),
            const SizedBox(height: 12),
            if (_sugCategoryId.isEmpty)
              Text('Pick a category for suggestions.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))
            else
              StreamBuilder<List<MarketplaceSubcategoryNode>>(
                stream: _tax.watchSubcategories(_sugCategoryId, activeOnly: true),
                builder: (context, subSnap) {
                  final subs = subSnap.data ?? [];
                  return DropdownButtonFormField<String>(
                    key: ValueKey<String>('sug_sub_${_sugCategoryId}_$_sugSubcategoryId'),
                    initialValue:
                        _sugSubcategoryId.isNotEmpty && subs.any((s) => s.id == _sugSubcategoryId) ? _sugSubcategoryId : null,
                    decoration: const InputDecoration(
                      labelText: 'Suggested subcategory',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: '', child: Text('Select…')),
                      ...subs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() {
                              _sugSubcategoryId = v ?? '';
                              _sugAttrs = {};
                              _sugSubcategoryName = '';
                              if (_sugSubcategoryId.isNotEmpty) {
                                for (final s in subs) {
                                  if (s.id == _sugSubcategoryId) {
                                    _sugSubcategoryName = s.name;
                                    break;
                                  }
                                }
                              }
                            });
                          },
                  );
                },
              ),
            if (_sugCategoryId.isNotEmpty && _sugSubcategoryId.isNotEmpty) ...[
              const SizedBox(height: 16),
              _suggestionAttributeDropdowns(),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        int? paise;
                        if (l.deletionRequested) {
                          paise = 0;
                        } else {
                          final rupees = double.tryParse(_finalPrice.text.trim());
                          paise = rupees == null ? null : (rupees * 100).round();
                        }
                        if (!l.deletionRequested && paise == null) return;
                        setState(() => _busy = true);
                        try {
                          final catalogId = await MarketplaceAdminActions.publishListingToCatalog(
                            listing: l,
                            finalBuyerPricePaise: paise ?? 0,
                          );
                          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                          await MarketplaceAdminActions.logAudit(
                            actorUid: uid,
                            action: l.deletionRequested
                                ? 'approve_listing_deletion'
                                : ((l.catalogProductId ?? '').isNotEmpty ? 'update_catalog_listing' : 'publish_listing'),
                            entityType: 'marketplace_listing',
                            entityId: l.id,
                            payload: {'catalog_product_id': catalogId, 'price_paise': paise},
                          );
                          if (context.mounted) {
                            final msg = l.deletionRequested
                                ? 'Product removed from catalog'
                                : ((l.catalogProductId ?? '').isNotEmpty ? 'Catalog updated' : 'Published catalog $catalogId');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            context.pop();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(
                  l.deletionRequested
                      ? 'Approve removal'
                      : ((l.catalogProductId ?? '').isNotEmpty ? 'Approve update' : 'Publish to buyer catalog'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (_rejectReason.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter reject reason')),
                          );
                          return;
                        }
                        if (_sendTaxonomySuggestion) {
                          if (_sugCategoryId.isEmpty || _sugSubcategoryId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Select suggested category and subcategory, or turn off suggestions.')),
                            );
                            return;
                          }
                          final snap = await FirestoreService.marketplaceCategoryAttributes(_sugCategoryId, _sugSubcategoryId)
                              .orderBy('sort_order')
                              .get();
                          if (!context.mounted) return;
                          for (final doc in snap.docs) {
                            final def = MarketplaceAttributeDef.fromDoc(doc);
                            if (def == null) continue;
                            if (def.required && (_sugAttrs[def.key] ?? '').trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Suggested features: select "${def.label}"')),
                              );
                              return;
                            }
                          }
                        }
                        setState(() => _busy = true);
                        try {
                          await MarketplaceAdminActions.rejectListing(
                            listingId: l.id,
                            reason: _rejectReason.text.trim(),
                            suggestedCategoryId: _sendTaxonomySuggestion ? _sugCategoryId : null,
                            suggestedSubcategoryId: _sendTaxonomySuggestion ? _sugSubcategoryId : null,
                            suggestedCategoryName: _sendTaxonomySuggestion ? _sugCategoryName : null,
                            suggestedSubcategoryName: _sendTaxonomySuggestion ? _sugSubcategoryName : null,
                            suggestedAttributeSelections: _sendTaxonomySuggestion ? _sugAttrs : null,
                          );
                          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                          await MarketplaceAdminActions.logAudit(
                            actorUid: uid,
                            action: 'reject_listing',
                            entityType: 'marketplace_listing',
                            entityId: l.id,
                            payload: {
                              'reason': _rejectReason.text.trim(),
                              'suggested_taxonomy': _sendTaxonomySuggestion,
                            },
                          );
                          if (context.mounted) {
                            context.pop();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Reject submission'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

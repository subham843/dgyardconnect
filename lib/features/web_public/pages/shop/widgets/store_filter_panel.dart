// Premium sidebar filters — fully driven by admin catalog facets.

import 'package:flutter/material.dart';

import '../../../v2/v2_colors.dart';
import '../../../v2/v2_tokens.dart';
import '../../../v2/v2_text.dart';
import '../../../data/models/public_store_models.dart';
import 'store_atoms.dart';
import 'store_filters.dart';

class StoreFilterPanel extends StatelessWidget {
  const StoreFilterPanel({
    super.key,
    required this.catalog,
    required this.engine,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  final StoreCatalog catalog;
  final StoreQueryEngine engine;
  final StoreFilters filters;
  final ValueChanged<StoreFilters> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final brandFacets = engine.brandFacets(filters);
    final bounds = engine.priceBounds(filters);
    final attrFacets = engine.attributeFacets(filters);

    return Container(
      padding: const EdgeInsets.all(V2.s6),
      decoration: BoxDecoration(
        color: V2Colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: V2Colors.surface.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: V2Colors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: V2Colors.surface,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: V2.s2),
                  Text('Filters', style: V2Text.bodyEmph()),
                ],
              ),
              const Spacer(),
              if (filters.hasRefinements)
                GestureDetector(
                  onTap: onClear,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Clear all',
                      style: V2Text.smallStrong().copyWith(
                        color: V2Colors.ember,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: V2.s4),
          _CategoryTree(
            categories: catalog.categories,
            filters: filters,
            onChanged: onChanged,
          ),
          if (brandFacets.isNotEmpty)
            _FilterSection(
              title: 'Brand',
              child: Column(
                children: [
                  for (final b in brandFacets)
                    _CheckRow(
                      label: b.name,
                      count: b.count,
                      checked: filters.brandIds.contains(b.id),
                      onTap: () {
                        final ids = {...filters.brandIds};
                        ids.contains(b.id) ? ids.remove(b.id) : ids.add(b.id);
                        onChanged(filters.copyWith(brandIds: ids));
                      },
                    ),
                ],
              ),
            ),
          if (bounds.max > bounds.min)
            _FilterSection(
              title: 'Price range',
              child: _PriceRange(
                bounds: bounds,
                filters: filters,
                onChanged: onChanged,
              ),
            ),
          _FilterSection(
            title: 'Availability',
            child: _CheckRow(
              label: 'In stock only',
              checked: filters.inStockOnly,
              onTap: () => onChanged(
                filters.copyWith(inStockOnly: !filters.inStockOnly),
              ),
            ),
          ),
          for (final entry in attrFacets.entries)
            _FilterSection(
              title: entry.key,
              child: Column(
                children: [
                  for (final value in entry.value)
                    _CheckRow(
                      label: value,
                      checked:
                          filters.attributes[entry.key]?.contains(value) ??
                          false,
                      onTap: () {
                        final attrs = {
                          for (final e in filters.attributes.entries)
                            e.key: {...e.value},
                        };
                        final set = attrs[entry.key] ??= <String>{};
                        set.contains(value)
                            ? set.remove(value)
                            : set.add(value);
                        onChanged(filters.copyWith(attributes: attrs));
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTree extends StatelessWidget {
  const _CategoryTree({
    required this.categories,
    required this.filters,
    required this.onChanged,
  });

  final List<PublicCategory> categories;
  final StoreFilters filters;
  final ValueChanged<StoreFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterSection(
      title: 'Category',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TreeRow(
            label: 'All products',
            active: filters.categoryId == null && filters.subCategoryId == null,
            onTap: () => onChanged(
              filters.copyWith(categoryId: null, subCategoryId: null),
            ),
          ),
          for (final c in categories)
            _CategoryNode(category: c, filters: filters, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CategoryNode extends StatelessWidget {
  const _CategoryNode({
    required this.category,
    required this.filters,
    required this.onChanged,
  });

  final PublicCategory category;
  final StoreFilters filters;
  final ValueChanged<StoreFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final isActiveCat = filters.categoryId == category.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TreeRow(
          label: category.name,
          count: category.productCount,
          active: isActiveCat && filters.subCategoryId == null,
          bold: true,
          onTap: () => onChanged(
            filters.copyWith(categoryId: category.id, subCategoryId: null),
          ),
        ),
        if (isActiveCat)
          Padding(
            padding: const EdgeInsets.only(left: V2.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in category.subcategories)
                  _TreeRow(
                    label: s.name,
                    count: s.productCount,
                    active: filters.subCategoryId == s.id,
                    onTap: () => onChanged(
                      filters.copyWith(
                        categoryId: category.id,
                        subCategoryId: s.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TreeRow extends StatefulWidget {
  const _TreeRow({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.bold = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;
  final bool bold;

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? V2Colors.ember
        : (_hover ? V2Colors.ink : V2Colors.fgMuted);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: V2Text.body().copyWith(
                    color: color,
                    fontWeight: widget.active || widget.bold
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.count != null && widget.count! > 0)
                Text(
                  '${widget.count}',
                  style: V2Text.small().copyWith(
                    color: V2Colors.fgSubtle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatefulWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;
  final int? count;

  @override
  State<_CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends State<_CheckRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.checked
                      ? V2Colors.ember
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: widget.checked
                        ? V2Colors.ember
                        : (_hover
                              ? V2Colors.ember
                              : V2Colors.borderStrong),
                    width: 1.5,
                  ),
                ),
                child: widget.checked
                    ? const Icon(
                        Icons.check,
                        size: 13,
                        color: V2Colors.surface,
                      )
                    : null,
              ),
              const SizedBox(width: V2.s2),
              Expanded(
                child: Text(
                  widget.label,
                  style: V2Text.body().copyWith(
                    color: V2Colors.fgMuted,
                    fontWeight: widget.checked
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.count != null)
                Text(
                  '${widget.count}',
                  style: V2Text.small().copyWith(
                    color: V2Colors.fgSubtle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRange extends StatelessWidget {
  const _PriceRange({
    required this.bounds,
    required this.filters,
    required this.onChanged,
  });

  final ({double min, double max}) bounds;
  final StoreFilters filters;
  final ValueChanged<StoreFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final lo = (filters.minPrice ?? bounds.min).clamp(bounds.min, bounds.max);
    final hi = (filters.maxPrice ?? bounds.max).clamp(bounds.min, bounds.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RangeSlider(
          min: bounds.min,
          max: bounds.max,
          divisions: 50,
          activeColor: V2Colors.ember,
          inactiveColor: V2Colors.borderSubtle,
          values: RangeValues(lo.toDouble(), hi.toDouble()),
          labels: RangeLabels(
            formatINR(lo.toDouble()),
            formatINR(hi.toDouble()),
          ),
          onChanged: (v) =>
              onChanged(filters.copyWith(minPrice: v.start, maxPrice: v.end)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatINR(lo.toDouble()), style: V2Text.smallStrong()),
            Text(formatINR(hi.toDouble()), style: V2Text.smallStrong()),
          ],
        ),
      ],
    );
  }
}

class _FilterSection extends StatefulWidget {
  const _FilterSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends State<_FilterSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: V2.s4),
          child: Divider(height: 1, color: V2Colors.border),
        ),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: V2Text.bodyEmph().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: V2Colors.fgSubtle,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: V2.s2),
            child: widget.child,
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
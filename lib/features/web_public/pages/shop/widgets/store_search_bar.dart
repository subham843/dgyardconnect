// Advanced store search with live suggestions, recent + popular searches.

import 'package:flutter/material.dart';

import '../../../v2/v2_colors.dart';
import '../../../v2/v2_tokens.dart';
import '../../../v2/v2_text.dart';

enum StoreSuggestionKind { product, brand, category, term }

class StoreSuggestion {
  StoreSuggestion({
    required this.label,
    required this.kind,
    this.sublabel,
    required this.onTap,
  });

  final String label;
  final String? sublabel;
  final StoreSuggestionKind kind;
  final VoidCallback onTap;

  IconData get icon {
    switch (kind) {
      case StoreSuggestionKind.product:
        return Icons.inventory_2_outlined;
      case StoreSuggestionKind.brand:
        return Icons.verified_outlined;
      case StoreSuggestionKind.category:
        return Icons.category_outlined;
      case StoreSuggestionKind.term:
        return Icons.search_rounded;
    }
  }
}

class StoreSearchBar extends StatefulWidget {
  const StoreSearchBar({
    super.key,
    required this.suggestionProvider,
    required this.onSubmit,
    required this.recentSearches,
    required this.popularSearches,
    this.initialQuery = '',
    this.hintText = 'Search products, brands, SKU, categories…',
  });

  final List<StoreSuggestion> Function(String query) suggestionProvider;
  final ValueChanged<String> onSubmit;
  final List<String> recentSearches;
  final List<String> popularSearches;
  final String initialQuery;
  final String hintText;

  @override
  State<StoreSearchBar> createState() => _StoreSearchBarState();
}

class _StoreSearchBarState extends State<StoreSearchBar> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _portal.show();
      } else {
        // Delay so a tap on a suggestion is registered before closing.
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted && !_focus.hasFocus) _portal.hide();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    _portal.hide();
    widget.onSubmit(q);
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: _buildField(),
      ),
    );
  }

  Widget _buildField() {
    return Container(
      decoration: BoxDecoration(
        color: V2Colors.surface,
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: V2Colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: (_) => setState(() {}),
        onSubmitted: _submit,
        textInputAction: TextInputAction.search,
        style: V2Text.body().copyWith(color: V2Colors.ink),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle:
              V2Text.body().copyWith(color: V2Colors.fgSubtle),
          prefixIcon: const Icon(Icons.search_rounded, color: V2Colors.fgSubtle),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: V2.s4, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final query = _controller.text.trim();
    final suggestions =
        query.isEmpty ? <StoreSuggestion>[] : widget.suggestionProvider(query);

    final box = context.findRenderObject();
    final width = box is RenderBox ? box.size.width : 480.0;

    return Positioned(
      width: width.clamp(280.0, 720.0),
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: const Offset(0, 64),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: V2Colors.surface,
              borderRadius: BorderRadius.circular(V2.rXl),
              border: Border.all(color: V2Colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(V2.s2),
              child: query.isEmpty
                  ? _emptyState()
                  : _suggestionList(suggestions, query),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.recentSearches.isNotEmpty) ...[
          _groupLabel('Recent searches'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.recentSearches
                .map((t) => _chip(t, Icons.history_rounded))
                .toList(),
          ),
          const SizedBox(height: V2.s4),
        ],
        if (widget.popularSearches.isNotEmpty) ...[
          _groupLabel('Popular searches'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.popularSearches
                .map((t) => _chip(t, Icons.trending_up_rounded))
                .toList(),
          ),
        ],
        if (widget.recentSearches.isEmpty && widget.popularSearches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(V2.s4),
            child: Text('Start typing to search the store',
                style: V2Text.small()),
          ),
      ],
    );
  }

  Widget _suggestionList(List<StoreSuggestion> suggestions, String query) {
    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(V2.s4),
        child: Text('No matches for “$query”', style: V2Text.small()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in suggestions)
          _SuggestionRow(
            suggestion: s,
            onTap: () {
              _focus.unfocus();
              _portal.hide();
              s.onTap();
            },
          ),
      ],
    );
  }

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Text(text.toUpperCase(),
            style: V2Text.micro()
                .copyWith(color: V2Colors.fgSubtle)),
      );

  Widget _chip(String text, IconData icon) {
    return InkWell(
      borderRadius: BorderRadius.circular(V2.rFull),
      onTap: () {
        _controller.text = text;
        _submit(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: V2Colors.bgSubtle,
          borderRadius: BorderRadius.circular(V2.rFull),
          border: Border.all(color: V2Colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: V2Colors.fgSubtle),
            const SizedBox(width: 6),
            Text(text, style: V2Text.micro()),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatefulWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});
  final StoreSuggestion suggestion;
  final VoidCallback onTap;

  @override
  State<_SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends State<_SuggestionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: V2.s2, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? V2Colors.bgSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(V2.rSm),
          ),
          child: Row(
            children: [
              Icon(s.icon, size: 18, color: V2Colors.ember),
              const SizedBox(width: V2.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.body()
                            .copyWith(color: V2Colors.ink)),
                    if (s.sublabel != null)
                      Text(s.sublabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V2Text.small()),
                  ],
                ),
              ),
              const Icon(Icons.north_west_rounded,
                  size: 14, color: V2Colors.fgSubtle),
            ],
          ),
        ),
      ),
    );
  }
}
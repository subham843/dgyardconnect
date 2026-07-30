// Defers building heavy sections until the user scrolls near them.

import 'package:flutter/material.dart';

class V2LazySection extends StatefulWidget {
  const V2LazySection({
    super.key,
    required this.scrollController,
    required this.loadAtOffset,
    required this.placeholderHeight,
    required this.child,
    this.preloadExtent = 480,
  });

  final ScrollController scrollController;
  final double loadAtOffset;
  final double placeholderHeight;
  final Widget child;
  final double preloadExtent;

  @override
  State<V2LazySection> createState() => _V2LazySectionState();
}

class _V2LazySectionState extends State<V2LazySection> {
  bool _built = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_maybeBuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuild());
  }

  @override
  void didUpdateWidget(covariant V2LazySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_maybeBuild);
      widget.scrollController.addListener(_maybeBuild);
      _maybeBuild();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_maybeBuild);
    super.dispose();
  }

  void _maybeBuild() {
    if (_built || !widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final viewportEnd = pos.pixels + pos.viewportDimension + widget.preloadExtent;
    if (viewportEnd >= widget.loadAtOffset) {
      setState(() => _built = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_built) {
      return SizedBox(height: widget.placeholderHeight);
    }
    return widget.child;
  }
}

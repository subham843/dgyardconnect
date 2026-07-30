import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../utils/brand_logo_tint.dart';
import '../utils/svg_recolor.dart';

/// Brand logo from Storage — PNG/JPG/WebP + SVG with optional tint.
class BrandKitLogoImage extends StatelessWidget {
  const BrandKitLogoImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.centerLeft,
    this.tintColor,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Color? tintColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    if (BrandLogoTint.isSvgUrl(trimmed)) {
      return _SvgLogo(
        key: ValueKey('svg-$trimmed-${tintColor?.toARGB32()}'),
        url: trimmed,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        tintColor: tintColor,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }

    Widget image;
    if (kIsWeb) {
      image = Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder ?? _defaultPlaceholder();
        },
        errorBuilder: (_, e, s) => errorWidget ?? _defaultError(),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: trimmed,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        placeholder: (_, _) => placeholder ?? _defaultPlaceholder(),
        errorWidget: (_, _, _) => errorWidget ?? _defaultError(),
      );
    }

    if (tintColor != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(tintColor!, BlendMode.srcIn),
        child: image,
      );
    }

    return image;
  }

  Widget _defaultPlaceholder() {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _defaultError() {
    return Icon(Icons.broken_image, color: Colors.grey[500], size: 24);
  }
}

class _SvgLogo extends StatefulWidget {
  const _SvgLogo({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.centerLeft,
    this.tintColor,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Color? tintColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<_SvgLogo> createState() => _SvgLogoState();
}

class _SvgLogoState extends State<_SvgLogo> {
  static final _cache = <String, String>{};

  String? _svg;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _SvgLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.tintColor != widget.tintColor) {
      _load();
    }
  }

  Future<void> _load() async {
    final cacheKey = widget.url;
    try {
      var raw = _cache[cacheKey];
      if (raw == null) {
        final res = await http.get(Uri.parse(widget.url));
        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }
        raw = res.body;
        _cache[cacheKey] = raw;
      }

      final tinted = widget.tintColor != null
          ? SvgRecolor.apply(raw, widget.tintColor!)
          : raw;

      if (!mounted) return;
      setState(() {
        _svg = tinted ?? raw;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _svg = null;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorWidget ?? Icon(Icons.broken_image, color: Colors.grey[500], size: 24);
    }

    if (_svg == null) {
      return widget.placeholder ??
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    return SvgPicture.string(
      _svg!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
    );
  }
}

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildAddressLocationMap({
  required double latitude,
  required double longitude,
  required double height,
}) {
  return _WebEmbedMap(
    latitude: latitude,
    longitude: longitude,
    height: height,
  );
}

class _WebEmbedMap extends StatefulWidget {
  const _WebEmbedMap({
    required this.latitude,
    required this.longitude,
    required this.height,
  });

  final double latitude;
  final double longitude;
  final double height;

  @override
  State<_WebEmbedMap> createState() => _WebEmbedMapState();
}

class _WebEmbedMapState extends State<_WebEmbedMap> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = _registerView(widget.latitude, widget.longitude);
  }

  @override
  void didUpdateWidget(_WebEmbedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _viewType = _registerView(widget.latitude, widget.longitude);
    }
  }

  /// Public embed URL — no Maps Embed API key required (unlike embed/v1/view).
  static String _embedUrl(double lat, double lng) =>
      'https://maps.google.com/maps?q=$lat,$lng&hl=en&z=15&output=embed';

  String _registerView(double lat, double lng) {
    final viewType =
        'dg-address-map-${lat.toStringAsFixed(5)}-${lng.toStringAsFixed(5)}-${DateTime.now().microsecondsSinceEpoch}';
    final src = _embedUrl(lat, lng);

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute('loading', 'lazy')
        ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
      return iframe;
    });
    return viewType;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: HtmlElementView(key: ValueKey(_viewType), viewType: _viewType),
      ),
    );
  }
}

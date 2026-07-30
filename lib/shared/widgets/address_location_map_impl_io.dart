import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/maps_config.dart';

Widget buildAddressLocationMap({
  required double latitude,
  required double longitude,
  required double height,
}) {
  return _MobileWebViewMap(
    latitude: latitude,
    longitude: longitude,
    height: height,
  );
}

class _MobileWebViewMap extends StatefulWidget {
  const _MobileWebViewMap({
    required this.latitude,
    required this.longitude,
    required this.height,
  });

  final double latitude;
  final double longitude;
  final double height;

  @override
  State<_MobileWebViewMap> createState() => _MobileWebViewMapState();
}

class _MobileWebViewMapState extends State<_MobileWebViewMap> {
  WebViewController? _controller;

  static String _buildHtml(double lat, double lng, String apiKey) {
    const html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #map { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    function initMap() {
      var center = { lat: LAT, lng: LNG };
      var map = new google.maps.Map(document.getElementById("map"), {
        zoom: 15,
        center: center,
        mapTypeId: "roadmap",
        zoomControl: true,
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: true,
      });
      new google.maps.Marker({
        position: center,
        map: map,
      });
    }
  </script>
  <script async defer src="https://maps.googleapis.com/maps/api/js?key=API_KEY&callback=initMap"></script>
</body>
</html>
''';
    return html
        .replaceAll('LAT', lat.toString())
        .replaceAll('LNG', lng.toString())
        .replaceAll('API_KEY', apiKey);
  }

  void _loadMap() {
    final apiKey = mapsApiKey;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(
        _buildHtml(widget.latitude, widget.longitude, apiKey),
        baseUrl: 'https://maps.googleapis.com/',
      );
  }

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  @override
  void didUpdateWidget(_MobileWebViewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _loadMap();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _controller != null
            ? WebViewWidget(controller: _controller!)
            : const SizedBox.shrink(),
      ),
    );
  }
}

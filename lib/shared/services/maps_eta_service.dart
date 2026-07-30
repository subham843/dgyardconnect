import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/maps_config.dart';

/// Driving ETA and reverse geocoding via Google Maps APIs (same key as [mapsApiKey]).
class MapsEtaService {
  MapsEtaService._();

  /// Returns driving duration in whole minutes, or null if unavailable.
  static Future<int?> drivingMinutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (mapsApiKey.isEmpty) return null;
    try {
      final uri = directionsUri(originLat, originLng, destLat, destLng, mode: 'driving');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (json?['status'] != 'OK') return null;
      final routes = json?['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final legs = (routes.first as Map<String, dynamic>)['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) return null;
      final dur = (legs.first as Map<String, dynamic>)['duration'] as Map<String, dynamic>?;
      final sec = (dur?['value'] as num?)?.toInt();
      if (sec == null || sec <= 0) return null;
      return (sec / 60).ceil().clamp(1, 999);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> formattedAddress(double lat, double lng) async {
    if (mapsApiKey.isEmpty) return null;
    try {
      final uri = geocodeReverseUri(lat, lng);
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (json?['status'] != 'OK') return null;
      final results = json?['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>?;
      final addr = first?['formatted_address'] as String?;
      if (addr == null || addr.trim().isEmpty) return null;
      return addr.trim();
    } catch (_) {
      return null;
    }
  }
}

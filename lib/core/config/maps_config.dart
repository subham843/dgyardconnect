import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase_options.dart';

/// API key for map and Places API. Lazy-loaded on web via `window.__dgLoadGoogleMaps`
/// in [web/index.html] (not on the critical path). See [ensureGoogleMapsJsLoaded].
/// Google Cloud Console setup:
/// - Enable: Maps JavaScript API, Places API (New), Geocoding API
/// - Application restrictions: None (dev) OR HTTP referrers: http://localhost:*, https://yourdomain.com/*
const String mapsWebApiKey = 'AIzaSyBR8xcLtJmtc_tjljKcgawfgR2VN0HHzMQ';

/// Resolves the key to use for the map and for address suggestions (Places API + Geocoding API).
String get mapsApiKey =>
    mapsWebApiKey.isNotEmpty ? mapsWebApiKey : DefaultFirebaseOptions.web.apiKey;

/// Places API (New) - Autocomplete endpoint.
/// POST https://places.googleapis.com/v1/places:autocomplete
/// Header: X-Goog-Api-Key
Uri get placesAutocompleteNewUri =>
    Uri.https('places.googleapis.com', 'v1/places:autocomplete');

/// Places API (New) - Place Details endpoint.
/// GET https://places.googleapis.com/v1/places/{placeId}
/// placeIdOrResource: "ChIJ..." or "places/ChIJ..."
Uri placesPlaceDetailsUri(String placeIdOrResource) {
  final id = placeIdOrResource.startsWith('places/')
      ? placeIdOrResource.substring(7)
      : placeIdOrResource;
  return Uri.https('places.googleapis.com', 'v1/places/$id');
}

/// Headers for Places API (New) - requires X-Goog-Api-Key.
Map<String, String> placesApiHeaders(String apiKey) => {
  'Content-Type': 'application/json',
  'X-Goog-Api-Key': apiKey,
};

/// Headers for Place Details (New) - requires FieldMask for location and address.
Map<String, String> placesDetailsHeaders(String apiKey) => {
  'Content-Type': 'application/json',
  'X-Goog-Api-Key': apiKey,
  'X-Goog-FieldMask': 'location,formattedAddress',
};

/// Request body for Places API (New) autocomplete.
Map<String, dynamic> placesAutocompleteRequestBody(String input) => {
  'input': input,
  'includedRegionCodes': ['in'],
  'languageCode': 'en',
};

/// Directions API - get route for in-app navigation (blue line on map).
/// REQUIRED: Enable "Directions API" in Google Cloud Console → APIs & Services → Enable APIs.
/// mode: driving, walking, bicycling
Uri directionsUri(
  double originLat,
  double originLng,
  double destLat,
  double destLng, {
  String mode = 'driving',
}) =>
    Uri.https('maps.googleapis.com', 'maps/api/directions/json', {
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      'mode': mode,
      'key': mapsApiKey,
    });

/// Geocoding API - reverse geocode lat/lng to address (street, mohalla, locality).
/// Enable "Geocoding API" in Google Cloud Console.
Uri geocodeReverseUri(double lat, double lng) =>
    Uri.https('maps.googleapis.com', 'maps/api/geocode/json', {
      'latlng': '$lat,$lng',
      'key': mapsApiKey,
      'language': 'en',
      'region': 'in',
    });

/// Optional: CORS proxy URL for web. Places API blocks direct browser requests.
/// Set to your Cloud Function or proxy URL that forwards to places.googleapis.com.
/// Example: 'https://us-central1-YOUR_PROJECT.cloudfunctions.net/placesProxy'
const String placesProxyUrl = '';

/// Whether to use proxy for Places API on web (avoids CORS).
bool get usePlacesProxy => kIsWeb && placesProxyUrl.isNotEmpty;

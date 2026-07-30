import 'maps_js_loader_stub.dart'
    if (dart.library.html) 'maps_js_loader_web.dart' as impl;

/// Ensures Maps JavaScript API is available before [GoogleMap] mounts on web.
Future<void> ensureGoogleMapsJsLoaded() => impl.ensureGoogleMapsJsLoaded();

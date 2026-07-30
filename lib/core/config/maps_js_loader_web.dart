import 'dart:js_interop';

@JS('__dgLoadGoogleMaps')
external JSPromise? _loadGoogleMaps();

Future<void> ensureGoogleMapsJsLoaded() async {
  final promise = _loadGoogleMaps();
  if (promise == null) return;
  await promise.toDart;
}

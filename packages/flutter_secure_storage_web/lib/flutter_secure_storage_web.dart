import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// WASM + dart2js compatible web storage (localStorage, no WebCrypto).
class FlutterSecureStorageWeb extends FlutterSecureStoragePlatform {
  static const _publicKey = 'publicKey';

  static void registerWith(Registrar registrar) {
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWeb();
  }

  String _storageKey(String key, Map<String, String> options) =>
      '${options[_publicKey] ?? 'default'}.$key';

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      web.window.localStorage.getItem(_storageKey(key, options)) != null;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    web.window.localStorage.removeItem(_storageKey(key, options));
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    final prefix = '${options[_publicKey] ?? 'default'}.';
    final keys = <String>[];
    for (var i = 0; i < web.window.localStorage.length; i++) {
      final itemKey = web.window.localStorage.key(i);
      if (itemKey != null && itemKey.startsWith(prefix)) {
        keys.add(itemKey);
      }
    }
    for (final itemKey in keys) {
      web.window.localStorage.removeItem(itemKey);
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      web.window.localStorage.getItem(_storageKey(key, options));

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final prefix = '${options[_publicKey] ?? 'default'}.';
    final result = <String, String>{};
    for (var i = 0; i < web.window.localStorage.length; i++) {
      final itemKey = web.window.localStorage.key(i);
      if (itemKey != null && itemKey.startsWith(prefix)) {
        final value = web.window.localStorage.getItem(itemKey);
        if (value != null) {
          result[itemKey.substring(prefix.length)] = value;
        }
      }
    }
    return result;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    web.window.localStorage.setItem(_storageKey(key, options), value);
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Saves and restores email/password for "Remember me" on the email login screen.
/// Uses secure storage so credentials are encrypted on device.
class SavedLoginService {
  SavedLoginService._();
  static const _storage = FlutterSecureStorage();
  static const _keyEmail = 'saved_login_email';
  static const _keyPassword = 'saved_login_password';

  static Future<void> save(String email, String password) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  static Future<({String email, String password})?> get() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }
}

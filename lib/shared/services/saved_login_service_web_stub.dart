/// Web stub — remember-me credentials are mobile-only.
class SavedLoginService {
  SavedLoginService._();

  static Future<void> save(String email, String password) async {}

  static Future<({String email, String password})?> get() async => null;

  static Future<void> clear() async {}
}

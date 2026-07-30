import 'package:shared_preferences/shared_preferences.dart';

class WalkthroughService {
  static const String generalKey = 'app_walkthrough_seen_v1';
  static const String dealerKey = 'dealer_walkthrough_seen_v1';
  static const String technicianKey = 'technician_walkthrough_seen_v1';
  static const String dealerHomeGuideKey = 'dealer_home_guide_seen_v1';
  static const String technicianHomeGuideKey = 'technician_home_guide_seen_v1';

  static Future<bool> isGeneralSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(generalKey) ?? false;
  }

  static Future<void> markGeneralSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(generalKey, true);
  }

  static Future<bool> isRoleSeen(String role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == 'dealer') return prefs.getBool(dealerKey) ?? false;
    if (role == 'technician') return prefs.getBool(technicianKey) ?? false;
    return true;
  }

  static Future<void> markRoleSeen(String role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == 'dealer') {
      await prefs.setBool(dealerKey, true);
      return;
    }
    if (role == 'technician') {
      await prefs.setBool(technicianKey, true);
    }
  }

  static Future<void> resetGeneral() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(generalKey);
  }

  static Future<void> resetRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == 'dealer') {
      await prefs.remove(dealerKey);
      return;
    }
    if (role == 'technician') {
      await prefs.remove(technicianKey);
    }
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(generalKey);
    await prefs.remove(dealerKey);
    await prefs.remove(technicianKey);
  }

  static Future<bool> isRoleHomeGuideSeen(String role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == 'dealer') return prefs.getBool(dealerHomeGuideKey) ?? false;
    if (role == 'technician') return prefs.getBool(technicianHomeGuideKey) ?? false;
    return true;
  }

  static Future<void> markRoleHomeGuideSeen(String role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == 'dealer') {
      await prefs.setBool(dealerHomeGuideKey, true);
      return;
    }
    if (role == 'technician') {
      await prefs.setBool(technicianHomeGuideKey, true);
    }
  }

  static Future<void> resetRoleHomeGuide(String role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == 'dealer') {
      await prefs.remove(dealerHomeGuideKey);
      return;
    }
    if (role == 'technician') {
      await prefs.remove(technicianHomeGuideKey);
    }
  }
}

import 'package:cloud_functions/cloud_functions.dart';

/// Count dealers/technicians in area via Cloud Functions (server reads users; client cannot).
class AreaCountService {
  /// Count approved technicians in dealer's area (by distance or city match).
  static Future<int> getTechnicianCountInArea(Map<String, dynamic>? dealerServiceArea) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getTechnicianCountInArea')
          .call<Map<String, dynamic>>(dealerServiceArea != null ? {'serviceArea': dealerServiceArea} : {});
      final count = result.data['count'];
      return (count is num) ? count.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Count approved dealers in technician's area (by distance or city match).
  static Future<int> getDealerCountInArea(Map<String, dynamic>? techServiceArea) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getDealerCountInArea')
          .call<Map<String, dynamic>>(techServiceArea != null ? {'serviceArea': techServiceArea} : {});
      final count = result.data['count'];
      return (count is num) ? count.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }
}

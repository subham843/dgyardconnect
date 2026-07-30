import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches town, state, country from Indian pincode via api.postalpincode.in
class PincodeService {
  static const _baseUrl = 'https://api.postalpincode.in/pincode';

  static Future<PincodeResult?> lookup(String pincode) async {
    final digits = pincode.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return null;
    try {
      final res = await http.get(Uri.parse('$_baseUrl/$digits')).timeout(
        const Duration(seconds: 10),
      );
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      final data = list.first as Map<String, dynamic>?;
      if (data?['Status'] != 'Success') return null;
      final offices = data!['PostOffice'] as List<dynamic>?;
      if (offices == null || offices.isEmpty) return null;
      final first = offices.first as Map<String, dynamic>;
      return PincodeResult(
        town: first['District'] as String? ?? first['Name'] as String? ?? '',
        state: first['State'] as String? ?? '',
        country: first['Country'] as String? ?? 'India',
      );
    } catch (_) {
      return null;
    }
  }
}

class PincodeResult {
  const PincodeResult({
    required this.town,
    required this.state,
    required this.country,
  });
  final String town;
  final String state;
  final String country;
}

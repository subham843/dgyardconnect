/// Result of "Where do you want to serve?" flow: center, radius, and user details.
class ServiceAreaResult {
  const ServiceAreaResult({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.fullName,
    required this.email,
    required this.buildingApartment,
    required this.houseFlatShopNumber,
    required this.landmark,
    this.addressLabel = '',
    this.city = '',
  });

  final double latitude;
  final double longitude;
  final double radiusKm;
  final String fullName;
  final String email;
  final String buildingApartment;
  final String houseFlatShopNumber;
  final String landmark;
  final String addressLabel;
  final String city;

  /// Build from a map (e.g. from GoRouter extra or Firestore).
  static ServiceAreaResult fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const ServiceAreaResult(
        latitude: 0, longitude: 0, radiusKm: 10,
        fullName: '', email: '', buildingApartment: '', houseFlatShopNumber: '', landmark: '',
      );
    }
    final lat = (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : 0.0;
    final lng = (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : 0.0;
    final radius = (map['radiusKm'] is num) ? (map['radiusKm'] as num).toDouble() : 10.0;
    return ServiceAreaResult(
      latitude: lat,
      longitude: lng,
      radiusKm: radius,
      fullName: map['fullName'] is String ? map['fullName'] as String : '',
      email: map['email'] is String ? map['email'] as String : '',
      buildingApartment: map['buildingApartment'] is String ? map['buildingApartment'] as String : '',
      houseFlatShopNumber: map['houseFlatShopNumber'] is String ? map['houseFlatShopNumber'] as String : '',
      landmark: map['landmark'] is String ? map['landmark'] as String : '',
      addressLabel: map['addressLabel'] is String ? map['addressLabel'] as String : '',
      city: map['city'] is String ? map['city'] as String : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'fullName': fullName,
      'email': email,
      'buildingApartment': buildingApartment,
      'houseFlatShopNumber': houseFlatShopNumber,
      'landmark': landmark,
      'addressLabel': addressLabel,
      'city': city,
    };
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
    };
    if (city.isNotEmpty) map['city'] = city;
    if (addressLabel.isNotEmpty) map['addressLabel'] = addressLabel;
    return map;
  }
}

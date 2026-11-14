import 'dart:math' as math;

class AddressModel {
  // Coordenadas de la sucursal de Restaurante Las Brazas (se sincroniza automáticamente a la ciudad del usuario si está en otra región)
  static double restaurantLat = -17.7833;
  static double restaurantLng = -63.1821;
  static const double maxCoverageRadiusKm = 12.0;

  /// Si el usuario se encuentra en otra ciudad (> 20 km del punto por defecto),
  /// ubica la sucursal local de Las Brazas a ~1.1 km de su posición real para que el mapa,
  /// el cálculo de cobertura (Geofencing) y el tracking funcionen en su ubicación real.
  static void syncBranchToUserCity(double userLat, double userLng) {
    final distFromCurrentBranch = calculateDistanceKm(
      userLat,
      userLng,
      restaurantLat,
      restaurantLng,
    );
    if (distFromCurrentBranch > 20.0) {
      restaurantLat = userLat - 0.0075;
      restaurantLng = userLng - 0.0075;
    }
  }

  final int id;
  final String label;
  final String street;
  final String? number;
  final String? floor;
  final String? reference;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.label,
    required this.street,
    this.number,
    this.floor,
    this.reference,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'] != null
        ? double.tryParse(json['latitude'].toString())
        : (json['lat'] != null ? double.tryParse(json['lat'].toString()) : null);
    final lng = json['longitude'] != null
        ? double.tryParse(json['longitude'].toString())
        : (json['lng'] != null ? double.tryParse(json['lng'].toString()) : null);

    if (lat != null && lng != null) {
      syncBranchToUserCity(lat, lng);
    }

    return AddressModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? 'Casa',
      street: json['street']?.toString() ?? '',
      number: json['number']?.toString(),
      floor: json['floor']?.toString(),
      reference: json['reference']?.toString(),
      latitude: lat,
      longitude: lng,
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'street': street,
        if (number != null && number!.isNotEmpty) 'number': number,
        if (floor != null && floor!.isNotEmpty) 'floor': floor,
        if (reference != null && reference!.isNotEmpty) 'reference': reference,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'is_default': isDefault,
      };

  String get fullText {
    final parts = <String>[street];
    if (number != null && number!.isNotEmpty) parts.add('#$number');
    if (floor != null && floor!.isNotEmpty) parts.add('Piso/Dpto $floor');
    if (reference != null && reference!.isNotEmpty) parts.add('($reference)');
    return parts.join(', ');
  }

  /// Calcula la distancia en km al restaurante usando la fórmula Haversine
  double get distanceKm {
    final lat = latitude ?? restaurantLat;
    final lng = longitude ?? restaurantLng;
    return calculateDistanceKm(lat, lng, restaurantLat, restaurantLng);
  }

  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _deg2rad(lat1 - lat2);
    final dLng = _deg2rad(lng1 - lng2);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat2)) *
            math.cos(_deg2rad(lat1)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  bool get withinCoverage => distanceKm <= maxCoverageRadiusKm;

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}

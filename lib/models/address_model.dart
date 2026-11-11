import 'dart:math' as math;

class AddressModel {
  // Coordenadas centrales de Restaurante Las Brazas (para Geofencing RF-21)
  static const double restaurantLat = -17.7833;
  static const double restaurantLng = -63.1821;
  static const double maxCoverageRadiusKm = 12.0;

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
    return AddressModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? 'Casa',
      street: json['street']?.toString() ?? '',
      number: json['number']?.toString(),
      floor: json['floor']?.toString(),
      reference: json['reference']?.toString(),
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
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

  /// Calcula la distancia en km al restaurante usando la fórmula Haversine (RF-21)
  double get distanceKm {
    final lat = latitude ?? restaurantLat;
    final lng = longitude ?? restaurantLng;
    const r = 6371.0;
    final dLat = _deg2rad(lat - restaurantLat);
    final dLng = _deg2rad(lng - restaurantLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(restaurantLat)) *
            math.cos(_deg2rad(lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  bool get withinCoverage => distanceKm <= maxCoverageRadiusKm;

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}


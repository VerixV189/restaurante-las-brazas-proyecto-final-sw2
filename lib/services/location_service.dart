import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:restaurante_movil/models/address_model.dart';

class DetectedPlace {
  final double latitude;
  final double longitude;
  final String street;
  final String? number;
  final String? zone;
  final String? city;
  final String displayName;

  DetectedPlace({
    required this.latitude,
    required this.longitude,
    required this.street,
    this.number,
    this.zone,
    this.city,
    required this.displayName,
  });
}

class LocationService {
  /// Obtiene la ubicación GPS real del dispositivo móvil (con fallback a última posición o geolocalización de red)
  /// y devuelve también el nombre real de la calle/zona mediante geocodificación inversa (OpenStreetMap Nominatim).
  static Future<DetectedPlace> getCurrentLocationWithAddress() async {
    double? lat;
    double? lng;

    // 1. Intentar obtener coordenadas exactas del chip GPS del teléfono
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (serviceEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always)) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          lat = lastPos.latitude;
          lng = lastPos.longitude;
        }
      }
    } catch (_) {
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          lat = lastPos.latitude;
          lng = lastPos.longitude;
        }
      } catch (_) {}
    }

    // 2. Si el GPS está apagado o sin señal bajo techo, usar geolocalización por red IP
    if (lat == null || lng == null) {
      final ipCoords = await _getNetworkLocationFallback();
      if (ipCoords != null) {
        lat = ipCoords.$1;
        lng = ipCoords.$2;
      }
    }

    final finalLat = lat ?? AddressModel.restaurantLat;
    final finalLng = lng ?? AddressModel.restaurantLng;

    // Sincronizar la sucursal de Las Brazas a la ciudad real del usuario
    AddressModel.syncBranchToUserCity(finalLat, finalLng);

    // 3. Hacer geocodificación inversa para obtener la calle y barrio real
    return reverseGeocode(finalLat, finalLng);
  }

  /// Convierte cualquier coordenada (lat, lng) en el nombre real de la calle, número y barrio
  static Future<DetectedPlace> reverseGeocode(double lat, double lng) async {
    AddressModel.syncBranchToUserCity(lat, lng);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&accept-language=es&addressdetails=1',
      );
      final res = await http.get(
        uri,
        headers: {
          'User-Agent': 'LasBrazasSteakhouseMobile/1.0 (contacto@lasbrazas.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = (data['address'] as Map<String, dynamic>?) ?? {};

        final road = (addr['road'] ??
                addr['pedestrian'] ??
                addr['residential'] ??
                addr['avenue'] ??
                addr['street'] ??
                addr['suburb'] ??
                addr['neighbourhood'] ??
                '')
            .toString()
            .trim();

        final houseNumber = addr['house_number']?.toString().trim();
        final zone = (addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['quarter'] ??
                addr['city_district'] ??
                '')
            .toString()
            .trim();
        final city = (addr['city'] ??
                addr['town'] ??
                addr['municipality'] ??
                addr['state'] ??
                '')
            .toString()
            .trim();

        final display = (data['display_name'] ?? '').toString().trim();

        return DetectedPlace(
          latitude: lat,
          longitude: lng,
          street: road.isNotEmpty
              ? road
              : (zone.isNotEmpty ? 'Zona $zone' : 'Ubicación GPS seleccionada'),
          number: houseNumber,
          zone: zone.isNotEmpty ? zone : null,
          city: city.isNotEmpty ? city : null,
          displayName: display.isNotEmpty
              ? display
              : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
        );
      }
    } catch (_) {}

    return DetectedPlace(
      latitude: lat,
      longitude: lng,
      street: 'Ubicación GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
      displayName: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
    );
  }

  static Future<(double, double)?> _getNetworkLocationFallback() async {
    for (final url in ['https://ipwho.is/', 'http://ip-api.com/json']) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final lat = double.tryParse((json['latitude'] ?? json['lat']).toString());
          final lng = double.tryParse((json['longitude'] ?? json['lon']).toString());
          if (lat != null && lng != null) {
            return (lat, lng);
          }
        }
      } catch (_) {}
    }
    return null;
  }
}


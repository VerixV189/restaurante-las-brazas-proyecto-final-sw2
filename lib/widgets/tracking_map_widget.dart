import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:restaurante_movil/models/address_model.dart';
import 'package:restaurante_movil/services/location_service.dart';

/// Mapa GPS real interactivo (OpenStreetMap + Geolocator) para:
/// 1) Obtener la ubicación GPS real del teléfono o tocar cualquier calle del mapa.
/// 2) Validar el radio de cobertura Geofencing de Las Brazas.
/// 3) Mostrar el tracking en vivo del repartidor hacia el domicilio del cliente.
class TrackingMapWidget extends StatefulWidget {
  final double? selectedLat;
  final double? selectedLng;
  final double driverProgress; // 0.0 (en restaurante) -> 1.0 (en domicilio)
  final bool showDriver;
  final ValueChanged<Offset>? onSelectCoordinate; // Offset(lat, lng)

  const TrackingMapWidget({
    super.key,
    this.selectedLat,
    this.selectedLng,
    this.driverProgress = 0.55,
    this.showDriver = false,
    this.onSelectCoordinate,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget> {
  final MapController _mapController = MapController();
  double _currentZoom = 15.0;
  bool _locatingGps = false;

  double get _targetLat =>
      widget.selectedLat ?? (AddressModel.restaurantLat + 0.005);
  double get _targetLng =>
      widget.selectedLng ?? (AddressModel.restaurantLng + 0.005);

  @override
  void didUpdateWidget(covariant TrackingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLat != widget.selectedLat ||
        oldWidget.selectedLng != widget.selectedLng) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.move(
            LatLng(_targetLat, _targetLng),
            _currentZoom,
          );
        } catch (_) {}
      });
    }
  }

  Future<void> _centerOnDeviceGps() async {
    if (_locatingGps) return;
    setState(() => _locatingGps = true);
    try {
      final place = await LocationService.getCurrentLocationWithAddress();
      if (!mounted) return;
      _mapController.move(LatLng(place.latitude, place.longitude), 16.0);
      setState(() => _currentZoom = 16.0);
      if (widget.onSelectCoordinate != null) {
        widget.onSelectCoordinate!(Offset(place.latitude, place.longitude));
      }
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  void _changeZoom(double delta) {
    final nextZoom = (_currentZoom + delta).clamp(11.0, 18.5);
    setState(() => _currentZoom = nextZoom);
    try {
      _mapController.move(LatLng(_targetLat, _targetLng), nextZoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final destPoint = LatLng(_targetLat, _targetLng);
    final restPoint = LatLng(
      AddressModel.restaurantLat,
      AddressModel.restaurantLng,
    );

    final p = widget.driverProgress.clamp(0.0, 1.0);
    final driverPoint = LatLng(
      restPoint.latitude + (destPoint.latitude - restPoint.latitude) * p,
      restPoint.longitude + (destPoint.longitude - restPoint.longitude) * p,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 235,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: destPoint,
                initialZoom: _currentZoom,
                onTap: widget.onSelectCoordinate == null
                    ? null
                    : (_, point) {
                        widget.onSelectCoordinate!(
                          Offset(point.latitude, point.longitude),
                        );
                      },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.restaurante_movil',
                ),
                // Zona de cobertura Geofencing (12 km)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: restPoint,
                      radius: AddressModel.maxCoverageRadiusKm * 1000,
                      useRadiusInMeter: true,
                      color: Colors.deepOrange.withValues(alpha: 0.08),
                      borderColor: Colors.deepOrange.withValues(alpha: 0.55),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                // Línea de ruta entre Sucursal Las Brazas y la Ubicación del Cliente
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [restPoint, destPoint],
                      color: Colors.deepPurple,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
                // Marcadores en tiempo real
                MarkerLayer(
                  markers: [
                    // Pin de Sucursal Las Brazas
                    Marker(
                      point: restPoint,
                      width: 110,
                      height: 58,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.shade800,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Las Brazas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.deepOrange,
                            size: 30,
                          ),
                        ],
                      ),
                    ),
                    // Pin de Ubicación del Cliente
                    Marker(
                      point: destPoint,
                      width: 120,
                      height: 62,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade800,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Tu ubicación',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.deepPurple,
                            size: 34,
                          ),
                        ],
                      ),
                    ),
                    // Pin en vivo del Repartidor
                    if (widget.showDriver)
                      Marker(
                        point: driverPoint,
                        width: 110,
                        height: 58,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Repartidor',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Etiqueta informativa superior
            Positioned(
              top: 8,
              left: 8,
              right: 52,
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gps_fixed,
                        size: 14,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.showDriver
                              ? 'Tracking GPS en Vivo • Repartidor en ruta'
                              : 'Toca el mapa o el botón GPS para fijar tu ubicación',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Controles de Mi GPS y Zoom (+/-)
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                children: [
                  Material(
                    color: Colors.white,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _centerOnDeviceGps,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _locatingGps
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                size: 20,
                                color: Colors.deepOrange,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _changeZoom(1.0),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.add, size: 18, color: Colors.black87),
                          ),
                        ),
                        const Divider(height: 1),
                        InkWell(
                          onTap: () => _changeZoom(-1.0),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.remove,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Coordenadas GPS exactas abajo a la derecha
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_targetLat.toStringAsFixed(5)}, ${_targetLng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

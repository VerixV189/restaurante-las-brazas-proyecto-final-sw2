import 'package:flutter/material.dart';
import 'package:restaurante_movil/models/address_model.dart';

/// Mapa GPS interactivo para:
/// 1) Seleccionar punto de entrega y validar radio de cobertura Geofencing (RF-05, RF-21).
/// 2) Mostrar el tracking en vivo del repartidor hacia el domicilio (RF-20).
class TrackingMapWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final lat = selectedLat ?? (AddressModel.restaurantLat + 0.015);
    final lng = selectedLng ?? (AddressModel.restaurantLng + 0.018);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapDown: onSelectCoordinate == null
                  ? null
                  : (details) {
                      final dx =
                          (details.localPosition.dx / constraints.maxWidth) -
                              0.5;
                      final dy =
                          (details.localPosition.dy / constraints.maxHeight) -
                              0.5;
                      final newLat = AddressModel.restaurantLat - (dy * 0.14);
                      final newLng = AddressModel.restaurantLng + (dx * 0.14);
                      onSelectCoordinate!(Offset(newLat, newLng));
                    },
              child: CustomPaint(
                painter: _GpsMapPainter(
                  targetLat: lat,
                  targetLng: lng,
                  driverProgress: driverProgress,
                  showDriver: showDriver,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
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
                            Text(
                              showDriver
                                  ? 'Tracking GPS en Vivo • Repartidor en ruta'
                                  : 'Toca el mapa para fijar tu pin GPS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
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
          },
        ),
      ),
    );
  }
}

class _GpsMapPainter extends CustomPainter {
  final double targetLat;
  final double targetLng;
  final double driverProgress;
  final bool showDriver;

  _GpsMapPainter({
    required this.targetLat,
    required this.targetLng,
    required this.driverProgress,
    required this.showDriver,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFEAF2EA);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Cuadrícula de calles simuladas
    final streetPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6;
    for (double x = 30; x < size.width; x += 55) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), streetPaint);
    }
    for (double y = 25; y < size.height; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), streetPaint);
    }

    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Zona de cobertura Geofencing (RF-21)
    final coverageFill = Paint()
      ..color = Colors.deepOrange.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final coverageBorder = Paint()
      ..color = Colors.deepOrange.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final radius = size.height * 0.42;
    canvas.drawCircle(center, radius, coverageFill);
    canvas.drawCircle(center, radius, coverageBorder);

    // Convertir lat/lng relativo a posición en el canvas
    final dx =
        ((targetLng - AddressModel.restaurantLng) / 0.14) * size.width;
    final dy =
        ((AddressModel.restaurantLat - targetLat) / 0.14) * size.height;
    final dest = Offset(
      (center.dx + dx).clamp(20.0, size.width - 20.0),
      (center.dy + dy).clamp(20.0, size.height - 20.0),
    );

    // Línea de ruta entre Restaurante y Cliente
    final routePaint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, dest, routePaint);

    // Pin del Restaurante Las Brazas (centro)
    final restPaint = Paint()..color = Colors.deepOrange;
    canvas.drawCircle(center, 9, restPaint);
    canvas.drawCircle(
      center,
      4,
      Paint()..color = Colors.white,
    );

    // Pin del Domicilio del Cliente
    final destPaint = Paint()..color = Colors.deepPurple;
    canvas.drawCircle(dest, 9, destPaint);
    canvas.drawCircle(
      dest,
      4,
      Paint()..color = Colors.white,
    );

    // Icono/Pin en vivo del repartidor (RF-20)
    if (showDriver) {
      final p = driverProgress.clamp(0.0, 1.0);
      final driverPos = Offset(
        center.dx + (dest.dx - center.dx) * p,
        center.dy + (dest.dy - center.dy) * p,
      );
      canvas.drawCircle(
        driverPos,
        12,
        Paint()..color = Colors.green.shade700,
      );
      canvas.drawCircle(
        driverPos,
        5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GpsMapPainter oldDelegate) {
    return oldDelegate.targetLat != targetLat ||
        oldDelegate.targetLng != targetLng ||
        oldDelegate.driverProgress != driverProgress ||
        oldDelegate.showDriver != showDriver;
  }
}


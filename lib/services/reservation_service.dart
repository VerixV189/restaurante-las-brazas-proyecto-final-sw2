import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/reservation_model.dart';
import 'package:restaurante_movil/services/http_client.dart';

class ReservationService {
  /// Zonas / Áreas disponibles con capacidad total (RF-12)
  static Future<List<AreaModel>> getAreas() async {
    final json = await HttpClient.get(ApiConstants.areas, auth: true);
    final list = json['data'] as List? ?? [];
    return list
        .map((e) => AreaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Validar aforo en tiempo real por fecha/hora y número de comensales (RF-12)
  static Future<List<AreaModel>> checkAvailability({
    required String dateFormatted, // 'YYYY-MM-DD HH:mm'
    required int guests,
  }) async {
    final json = await HttpClient.get(
      ApiConstants.reservationsAvailability,
      auth: true,
      queryParameters: {
        'date': dateFormatted,
        'guests': guests.toString(),
      },
    );
    final list = json['data'] as List? ?? [];
    return list
        .map((e) => AreaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crear nueva reservación móvil (RF-12)
  static Future<Map<String, dynamic>> createReservation({
    required String reservationDate, // 'YYYY-MM-DD HH:mm'
    required int adults,
    int children = 0,
    required int areaId,
    String? specialRequests,
  }) async {
    final json = await HttpClient.post(
      ApiConstants.reservations,
      auth: true,
      body: {
        'reservation_date': reservationDate,
        'adults': adults,
        'children': children,
        'area_id': areaId,
        if (specialRequests != null && specialRequests.trim().isNotEmpty)
          'special_requests': specialRequests.trim(),
      },
    );
    return {
      'message': json['message']?.toString() ??
          'Reserva registrada. Tu mesa se mantendrá por 15 minutos de tolerancia.',
      'reservation': ReservationModel.fromJson(
        json['data'] as Map<String, dynamic>,
      ),
    };
  }

  /// Obtener reservas activas e historial (RF-13)
  static Future<Map<String, List<ReservationModel>>> getReservations() async {
    final json = await HttpClient.get(ApiConstants.reservations, auth: true);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final activeRaw = data['active'] as List? ?? [];
    final historyRaw = data['history'] as List? ?? [];
    return {
      'active': activeRaw
          .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      'history': historyRaw
          .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    };
  }

  /// Cancelar reserva con anticipación mínima (RF-13)
  static Future<String> cancelReservation(int id) async {
    final json = await HttpClient.post(
      ApiConstants.reservationCancel(id),
      auth: true,
    );
    return json['message']?.toString() ?? 'Reserva cancelada.';
  }
}


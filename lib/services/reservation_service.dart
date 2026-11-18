import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/reservation_model.dart';
import 'package:restaurante_movil/services/auth_service.dart';
import 'package:restaurante_movil/services/http_client.dart';
import 'package:restaurante_movil/services/offline_cache_service.dart';

class ReservationService {
  /// Zonas / Áreas disponibles con capacidad total (con soporte Offline)
  static Future<List<AreaModel>> getAreas() async {
    try {
      final json = await HttpClient.get(ApiConstants.areas, auth: true);
      final list = json['data'] as List? ?? [];
      await OfflineCacheService.instance.cacheAreas(list);
      return list
          .map((e) => AreaModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await OfflineCacheService.instance.getCachedAreas();
      return cached.map(AreaModel.fromJson).toList();
    }
  }

  /// Validar aforo en tiempo real por fecha/hora y número de comensales
  static Future<List<AreaModel>> checkAvailability({
    required String dateFormatted,
    required int guests,
  }) async {
    try {
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
    } catch (_) {
      final cached = await OfflineCacheService.instance.getCachedAreas();
      return cached.map(AreaModel.fromJson).toList();
    }
  }

  /// Crear nueva reservación móvil
  static Future<Map<String, dynamic>> createReservation({
    required String reservationDate,
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

  /// Obtener reservas activas e historial estrictamente aisladas para el usuario actual
  static Future<Map<String, List<ReservationModel>>> getReservations() async {
    final user = await AuthService.getSavedUser();
    final uid = user?.id ?? 0;
    if (uid <= 0) return {'active': [], 'history': []};

    Map<String, dynamic> data;
    try {
      final json = await HttpClient.get(ApiConstants.reservations, auth: true);
      data = json['data'] as Map<String, dynamic>? ?? {};
      await OfflineCacheService.instance.cacheUserReservations(uid, data);
    } catch (_) {
      data = await OfflineCacheService.instance.getCachedUserReservations(uid);
    }

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

  /// Cancelar reserva con anticipación mínima
  static Future<String> cancelReservation(int id) async {
    final json = await HttpClient.post(
      ApiConstants.reservationCancel(id),
      auth: true,
    );
    return json['message']?.toString() ?? 'Reserva cancelada.';
  }
}

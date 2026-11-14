import 'dart:async';
import 'package:flutter/services.dart';
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/order_model.dart';
import 'package:restaurante_movil/services/http_client.dart';
import 'package:restaurante_movil/services/order_service.dart';
import 'package:restaurante_movil/services/reservation_service.dart';

class PushNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.lasbrazas/notifications',
  );

  static Timer? _syncTimer;
  static bool _initializedBaseline = false;
  static final Map<int, String> _lastOrderStep = {};
  static final Map<int, String> _lastReservationStatus = {};
  static final Set<String> _deliveredBackendNotifIds = {};

  /// Solicita permiso nativo de notificaciones en Android 13+ (POST_NOTIFICATIONS)
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  /// Muestra una notificación Push nativa del sistema operativo Android (barra de estado + banner flotante con sonido/vibración)
  static Future<void> showNativePush({
    required String title,
    required String body,
    int? id,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'id': id ?? (DateTime.now().millisecondsSinceEpoch % 100000),
        'title': title,
        'body': body,
      });
    } catch (_) {
      // Si se ejecuta en una plataforma de escritorio durante pruebas, se ignora silenciosamente
    }
  }

  /// Inicia el motor de sincronización en segundo plano que detecta cambios en vivo desde el backend:
  /// - Cambios de etapa de pedidos (Cocina KDS -> Listo -> En Camino -> Entregado)
  /// - Cambios de estado de reservaciones de mesas
  /// - Campañas y promociones enviadas desde `/api/v1/notifications`
  static void startRealtimeWatcher({
    required void Function({
      required String title,
      required String body,
      required String category,
      bool triggerNativePush,
    }) onNewNotification,
  }) {
    _syncTimer?.cancel();
    requestPermission();

    // Primera sincronización tras 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      _pollBackendEvents(onNewNotification);
    });

    // Sondeo continuo cada 10 segundos
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollBackendEvents(onNewNotification);
    });
  }

  static void stopRealtimeWatcher() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _initializedBaseline = false;
    _lastOrderStep.clear();
    _lastReservationStatus.clear();
  }

  static Future<void> _pollBackendEvents(
    void Function({
      required String title,
      required String body,
      required String category,
      bool triggerNativePush,
    }) onNewNotification,
  ) async {
    // 1. Verificar cambios de estado en Pedidos activos del cliente
    try {
      final orders = await OrderService.getHistory();
      for (final o in orders) {
        final currentStep = o.isCancelled ? 'cancelled' : o.tracking.current;
        final prevStep = _lastOrderStep[o.id];
        _lastOrderStep[o.id] = currentStep;

        if (_initializedBaseline &&
            prevStep != null &&
            prevStep != currentStep) {
          final alert = _buildOrderStateAlert(o, currentStep);
          if (alert != null) {
            onNewNotification(
              title: alert.$1,
              body: alert.$2,
              category: 'order',
              triggerNativePush: true,
            );
          }
        }
      }
    } catch (_) {}

    // 2. Verificar cambios en Reservas de mesas del cliente
    try {
      final resMap = await ReservationService.getReservations();
      final active = resMap['active'] ?? [];
      for (final r in active) {
        final prevStatus = _lastReservationStatus[r.id];
        _lastReservationStatus[r.id] = r.status;

        if (_initializedBaseline &&
            prevStatus != null &&
            prevStatus != r.status) {
          onNewNotification(
            title: '🪑 Actualización de tu Reserva #${r.id}',
            body:
                'Tu reservación para ${r.guestCount} personas el ${r.reservationDate} cambió a estado: ${r.statusLabel}. Recuerda la tolerancia de 15 min.',
            category: 'reservation',
            triggerNativePush: true,
          );
        }
      }
    } catch (_) {}

    // 3. Consultar endpoint de notificaciones / promociones del backend (/api/v1/notifications) si está habilitado
    try {
      final json = await HttpClient.get(ApiConstants.notifications, auth: true);
      final list = json['data'] as List? ?? [];
      for (final item in list) {
        if (item is Map) {
          final notifId = (item['id'] ?? item['title']).toString();
          if (_deliveredBackendNotifIds.contains(notifId)) continue;
          _deliveredBackendNotifIds.add(notifId);

          final title = item['title']?.toString() ?? '🔥 Aviso de Las Brazas';
          final body = item['body']?.toString() ??
              item['message']?.toString() ??
              'Tienes una nueva actualización en Las Brazas.';
          final category = item['type']?.toString() ?? 'promo';

          onNewNotification(
            title: title,
            body: body,
            category: category,
            triggerNativePush: true,
          );
        }
      }
    } catch (_) {}

    _initializedBaseline = true;
  }

  static (String, String)? _buildOrderStateAlert(
    OrderModel order,
    String step,
  ) {
    switch (step) {
      case 'in_kitchen':
        return (
          '👨‍🍳 ¡Tu Pedido #${order.id} entró a Cocina!',
          'El Maestro Parrillero aceptó tu orden y ya está preparando tus cortes a las brasas.'
        );
      case 'ready':
        return (
          '🔥 ¡Tu Pedido #${order.id} está Listo!',
          order.orderType == 'delivery'
              ? 'Tu orden ya salió de parrilla y está lista para ser recogida por el repartidor.'
              : 'Tu orden está lista para recoger en mostrador de Las Brazas.'
        );
      case 'on_the_way':
        return (
          '🛵 ¡Tu Pedido #${order.id} va En Camino!',
          'El repartidor recogió tu pedido y va rumbo a tu ubicación GPS.${order.deliveryPin != null ? ' Tu PIN de entrega es: ${order.deliveryPin}.' : ''}'
        );
      case 'delivered':
        return (
          '✅ ¡Pedido #${order.id} Entregado!',
          'Tu pedido fue entregado exitosamente. ¡Gracias por preferir Las Brazas Steakhouse!'
        );
      default:
        return null;
    }
  }
}


import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/delivery_order_model.dart';
import 'package:restaurante_movil/services/http_client.dart';

class DeliveryService {
  /// Pedidos de delivery pendientes sin repartidor (RF-17)
  static Future<List<DeliveryOrderModel>> getPendingOrders() async {
    final json = await HttpClient.get(ApiConstants.deliveryPending, auth: true);
    final list = json['data'] as List? ?? [];
    return list
        .map((e) => DeliveryOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Pedidos asignados al repartidor actual (RF-17)
  static Future<List<DeliveryOrderModel>> getMyOrders() async {
    final json = await HttpClient.get(ApiConstants.deliveryMine, auth: true);
    final list = json['data'] as List? ?? [];
    return list
        .map((e) => DeliveryOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tomar / Asignarse un pedido disponible (RF-17)
  static Future<String> takeOrder(int orderId) async {
    final json = await HttpClient.post(
      ApiConstants.deliveryTake(orderId),
      auth: true,
    );
    return json['message']?.toString() ?? 'Pedido asignado.';
  }

  /// Marcar que el repartidor recogió el pedido de cocina y salió a ruta (RF-15, RF-18)
  static Future<String> pickupOrder(int orderId) async {
    final json = await HttpClient.post(
      ApiConstants.deliveryPickup(orderId),
      auth: true,
    );
    return json['message']?.toString() ?? 'Pedido en camino.';
  }

  /// Confirmar entrega con PIN de 4 dígitos (RF-19)
  static Future<String> confirmDelivery({
    required int orderId,
    required String pin,
  }) async {
    final json = await HttpClient.post(
      ApiConstants.deliveryConfirm(orderId),
      auth: true,
      body: {'pin': pin.trim()},
    );
    return json['message']?.toString() ?? 'Entrega confirmada.';
  }
}


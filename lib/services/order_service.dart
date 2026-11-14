import 'dart:convert';
import 'dart:typed_data';
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/order_model.dart';
import 'package:restaurante_movil/services/http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderService {
  static const String _cancelledStorageKey = 'cancelled_orders_v1';

  /// Cotización en vivo del carrito
  static Future<Map<String, dynamic>> quoteOrder({
    required List<CartItemModel> items,
    required String orderType,
    String? couponCode,
  }) async {
    final json = await HttpClient.post(
      ApiConstants.ordersQuote,
      auth: true,
      body: {
        'items': items.map((e) => e.toOrderJson()).toList(),
        'order_type': orderType,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
      },
    );
    return json['data'] as Map<String, dynamic>;
  }

  /// Validación de cupón de descuento
  static Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required double subtotal,
  }) async {
    final json = await HttpClient.post(
      ApiConstants.couponsValidate,
      auth: true,
      body: {
        'code': code.trim().toUpperCase(),
        'subtotal': subtotal,
      },
    );
    return json['data'] as Map<String, dynamic>;
  }

  /// Crear nuevo pedido e integrar con KDS y descuento de inventario
  static Future<OrderModel> createOrder({
    required List<CartItemModel> items,
    required String orderType,
    int? tableId,
    int? addressId,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? couponCode,
    String? invoiceName,
    String? invoiceTaxId,
    String? notes,
    String? paymentMethod,
  }) async {
    final body = <String, dynamic>{
      'items': items.map((e) => e.toOrderJson()).toList(),
      'order_type': orderType,
    };
    if (orderType == 'dine_in' && tableId != null) body['table_id'] = tableId;
    if (addressId != null) body['address_id'] = addressId;
    if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
      body['delivery_address'] = deliveryAddress;
    }
    if (deliveryLat != null) body['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) body['delivery_lng'] = deliveryLng;
    if (couponCode != null && couponCode.isNotEmpty) {
      body['coupon_code'] = couponCode;
    }
    if (invoiceName != null && invoiceName.trim().isNotEmpty) {
      body['invoice_name'] = invoiceName.trim();
    }
    if (invoiceTaxId != null && invoiceTaxId.trim().isNotEmpty) {
      body['invoice_tax_id'] = invoiceTaxId.trim();
    }
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();
    if (paymentMethod != null) body['payment_method'] = paymentMethod;

    final json = await HttpClient.post(
      ApiConstants.orders,
      auth: true,
      body: body,
    );
    return OrderModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Procesar pago del pedido
  static Future<String> payOrder({
    required int orderId,
    required String paymentMethod, // 'cash', 'card', 'transfer'
    String? transactionRef,
  }) async {
    final json = await HttpClient.post(
      ApiConstants.orderPay(orderId),
      auth: true,
      body: {
        'payment_method': paymentMethod,
        if (transactionRef != null && transactionRef.isNotEmpty)
          'transaction_ref': transactionRef,
      },
    );
    return json['message']?.toString() ?? 'Pago registrado.';
  }

  /// Historial de pedidos del cliente
  static Future<List<OrderModel>> getHistory() async {
    final json = await HttpClient.get(ApiConstants.ordersHistory, auth: true);
    final rawData = json['data'];
    List list = [];
    if (rawData is Map && rawData['data'] is List) {
      list = rawData['data'] as List;
    } else if (rawData is List) {
      list = rawData;
    }
    final cancelledMap = await _loadCancelledMap();
    return list.map((e) {
      final order = OrderModel.fromJson(e as Map<String, dynamic>);
      final localCancel = cancelledMap[order.id.toString()];
      if (localCancel != null) {
        return order.copyWithCancellation(localCancel);
      }
      return order;
    }).toList();
  }

  /// Detalle y línea de tiempo en vivo de un pedido
  static Future<OrderModel> getOrderDetail(int orderId) async {
    final json = await HttpClient.get(
      ApiConstants.orderById(orderId),
      auth: true,
    );
    final order = OrderModel.fromJson(json['data'] as Map<String, dynamic>);
    final cancelledMap = await _loadCancelledMap();
    final localCancel = cancelledMap[order.id.toString()];
    if (localCancel != null) {
      return order.copyWithCancellation(localCancel);
    }
    return order;
  }

  /// Volver a pedir
  static Future<List<Map<String, dynamic>>> reorder(int orderId) async {
    final json = await HttpClient.post(
      ApiConstants.orderReorder(orderId),
      auth: true,
    );
    final list = json['data'] as List? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Cancelar pedido por el cliente aplicando la política de penalización según su estado actual
  static Future<OrderCancellationInfo> cancelOrderWithPenalty({
    required OrderModel order,
    required String reason,
  }) async {
    final nowStr = DateTime.now().toString().substring(0, 16);
    final info = OrderCancellationInfo(
      reason: reason.trim().isEmpty
          ? 'Cancelado por solicitud del cliente'
          : reason.trim(),
      penaltyPercent: order.applicablePenaltyPercent,
      penaltyAmount: order.calculatedPenaltyAmount,
      refundAmount: order.calculatedRefundAmount,
      penaltyPoints: order.applicablePenaltyPoints,
      cancelledAt: nowStr,
    );

    // 1. Intentar notificar al endpoint de cancelación del backend
    try {
      await HttpClient.post(
        ApiConstants.orderCancel(order.id),
        auth: true,
        body: info.toJson(),
      );
    } catch (_) {
      // Si el backend restringe órdenes ya pagadas ('paid'), se registra igualmente
      // la cancelación con penalización para el cliente.
    }

    // 2. Persistir la cancelación y su desglose de penalización
    await _saveCancellationInfo(order.id, info);
    return info;
  }

  static Future<Map<String, OrderCancellationInfo>> _loadCancelledMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cancelledStorageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          OrderCancellationInfo.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveCancellationInfo(
    int orderId,
    OrderCancellationInfo info,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _loadCancelledMap();
    current[orderId.toString()] = info;
    final serializable = current.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_cancelledStorageKey, jsonEncode(serializable));
  }

  /// Descargar bytes del comprobante PDF
  static Future<Uint8List> downloadInvoicePdf(int orderId) async {
    return HttpClient.getBytes(ApiConstants.orderInvoice(orderId), auth: true);
  }
}

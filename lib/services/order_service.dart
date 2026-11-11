import 'dart:typed_data';
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/order_model.dart';
import 'package:restaurante_movil/services/http_client.dart';

class OrderService {
  /// Cotización en vivo del carrito (RF-03, RF-06)
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

  /// Validación de cupón de descuento (RF-22)
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

  /// Crear nuevo pedido e integrar con KDS y descuento de inventario (RF-10)
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

  /// Procesar pago del pedido (RF-07)
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

  /// Historial de pedidos del cliente (RF-14)
  static Future<List<OrderModel>> getHistory() async {
    final json = await HttpClient.get(ApiConstants.ordersHistory, auth: true);
    final rawData = json['data'];
    List list = [];
    if (rawData is Map && rawData['data'] is List) {
      // Laravel pagination structure
      list = rawData['data'] as List;
    } else if (rawData is List) {
      list = rawData;
    }
    return list
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detalle y línea de tiempo en vivo de un pedido (RF-11)
  static Future<OrderModel> getOrderDetail(int orderId) async {
    final json = await HttpClient.get(
      ApiConstants.orderById(orderId),
      auth: true,
    );
    return OrderModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Volver a pedir (RF-14)
  static Future<List<Map<String, dynamic>>> reorder(int orderId) async {
    final json = await HttpClient.post(
      ApiConstants.orderReorder(orderId),
      auth: true,
    );
    final list = json['data'] as List? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Cancelar pedido pendiente
  static Future<String> cancelOrder(int orderId) async {
    final json = await HttpClient.post(
      ApiConstants.orderCancel(orderId),
      auth: true,
    );
    return json['message']?.toString() ?? 'Pedido cancelado.';
  }

  /// Descargar bytes del comprobante PDF (RF-09)
  static Future<Uint8List> downloadInvoicePdf(int orderId) async {
    return HttpClient.getBytes(ApiConstants.orderInvoice(orderId), auth: true);
  }
}


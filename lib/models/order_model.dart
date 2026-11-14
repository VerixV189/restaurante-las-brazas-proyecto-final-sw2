class OrderTrackingModel {
  final String current;
  final List<String> steps;

  OrderTrackingModel({
    required this.current,
    required this.steps,
  });

  factory OrderTrackingModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return OrderTrackingModel(
        current: 'received',
        steps: const ['received', 'in_kitchen', 'ready', 'delivered'],
      );
    }
    return OrderTrackingModel(
      current: json['current']?.toString() ?? 'received',
      steps: (json['steps'] is List)
          ? (json['steps'] as List).map((e) => e.toString()).toList()
          : const ['received', 'in_kitchen', 'ready', 'delivered'],
    );
  }

  static String stepLabel(String step) {
    switch (step) {
      case 'received':
        return 'Recibido';
      case 'in_kitchen':
        return 'En Cocina (KDS)';
      case 'ready':
        return 'Listo para Entrega';
      case 'on_the_way':
        return 'En Camino';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return step;
    }
  }
}

class OrderItemModel {
  final int dishId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  OrderItemModel({
    required this.dishId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      dishId: (json['dish_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Platillo',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString(),
    );
  }
}

class OrderModel {
  final int id;
  final String orderType;
  final String status;
  final OrderTrackingModel tracking;
  final double subtotal;
  final double discount;
  final double tax;
  final double deliveryFee;
  final double total;
  final String? createdAt;
  final int itemsCount;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? deliveryPin;
  final String? couponCode;
  final String? notes;
  final String? invoiceName;
  final String? invoiceTaxId;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderType,
    required this.status,
    required this.tracking,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.deliveryFee,
    required this.total,
    this.createdAt,
    required this.itemsCount,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryPin,
    this.couponCode,
    this.notes,
    this.invoiceName,
    this.invoiceTaxId,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] is List)
        ? (json['items'] as List)
            .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <OrderItemModel>[];

    final dLat = json['delivery_lat'] != null
        ? double.tryParse(json['delivery_lat'].toString())
        : (json['latitude'] != null
            ? double.tryParse(json['latitude'].toString())
            : null);
    final dLng = json['delivery_lng'] != null
        ? double.tryParse(json['delivery_lng'].toString())
        : (json['longitude'] != null
            ? double.tryParse(json['longitude'].toString())
            : null);

    return OrderModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderType: json['order_type']?.toString() ?? 'delivery',
      status: json['status']?.toString() ?? 'pending',
      tracking: OrderTrackingModel.fromJson(
        json['tracking'] is Map<String, dynamic>
            ? json['tracking'] as Map<String, dynamic>
            : null,
      ),
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(json['tax']?.toString() ?? '0') ?? 0.0,
      deliveryFee:
          double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at']?.toString(),
      itemsCount: (json['items_count'] as num?)?.toInt() ?? itemsList.length,
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryLat: dLat,
      deliveryLng: dLng,
      deliveryPin: json['delivery_pin']?.toString(),
      couponCode: json['coupon_code']?.toString(),
      notes: json['notes']?.toString(),
      invoiceName: json['invoice_name']?.toString(),
      invoiceTaxId: json['invoice_tax_id']?.toString(),
      items: itemsList,
    );
  }

  String get orderTypeLabel {
    switch (orderType) {
      case 'delivery':
        return 'Delivery a Domicilio';
      case 'takeaway':
        return 'Para Recoger (Takeaway)';
      case 'dine_in':
        return 'En Mesa (Salón)';
      default:
        return orderType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'in_kitchen':
        return 'En Cocina';
      case 'ready':
        return 'Listo';
      case 'served':
        return 'Entregado';
      case 'paid':
        return 'Pagado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }
}


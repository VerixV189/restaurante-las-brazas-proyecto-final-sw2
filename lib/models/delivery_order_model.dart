import 'package:restaurante_movil/models/order_model.dart';

class DeliveryOrderModel {
  final int id;
  final String status;
  final OrderTrackingModel tracking;
  final String customer;
  final String? phone;
  final String? address;
  final double? lat;
  final double? lng;
  final double total;
  final String? navigationUrl;

  DeliveryOrderModel({
    required this.id,
    required this.status,
    required this.tracking,
    required this.customer,
    this.phone,
    this.address,
    this.lat,
    this.lng,
    required this.total,
    this.navigationUrl,
  });

  factory DeliveryOrderModel.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      tracking: OrderTrackingModel.fromJson(
        json['tracking'] is Map<String, dynamic>
            ? json['tracking'] as Map<String, dynamic>
            : null,
      ),
      customer: json['customer']?.toString() ?? 'Cliente Las Brazas',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      lat: json['lat'] != null
          ? double.tryParse(json['lat'].toString())
          : null,
      lng: json['lng'] != null
          ? double.tryParse(json['lng'].toString())
          : null,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      navigationUrl: json['navigation_url']?.toString(),
    );
  }
}


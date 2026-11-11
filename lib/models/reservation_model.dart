class AreaModel {
  final int id;
  final String name;
  final String? description;
  final int capacity;
  int? seatsLeft;
  bool isAvailable;

  AreaModel({
    required this.id,
    required this.name,
    this.description,
    this.capacity = 0,
    this.seatsLeft,
    this.isAvailable = true,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: (json['id'] as num?)?.toInt() ??
          (json['area_id'] as num?)?.toInt() ??
          0,
      name: json['name']?.toString() ?? 'Salón Principal',
      description: json['description']?.toString(),
      capacity: (json['capacity'] as num?)?.toInt() ?? 20,
      seatsLeft: (json['seats_left'] as num?)?.toInt(),
      isAvailable: json['available'] ?? true,
    );
  }
}

class ReservationModel {
  final int id;
  final int areaId;
  final String reservationDate;
  final int guestCount;
  final int childrenCount;
  final String status;
  final String? specialRequests;
  final String? tableNumber;

  ReservationModel({
    required this.id,
    required this.areaId,
    required this.reservationDate,
    required this.guestCount,
    this.childrenCount = 0,
    required this.status,
    this.specialRequests,
    this.tableNumber,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final tableObj = json['table'];
    return ReservationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      areaId: (json['area_id'] as num?)?.toInt() ?? 1,
      reservationDate: json['reservation_date']?.toString() ?? '',
      guestCount: (json['guest_count'] as num?)?.toInt() ?? 1,
      childrenCount: (json['children_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      specialRequests: json['special_requests']?.toString(),
      tableNumber: tableObj is Map
          ? tableObj['table_number']?.toString()
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente de Confirmar';
      case 'confirmed':
        return 'Confirmada';
      case 'seated':
        return 'En Mesa';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }
}


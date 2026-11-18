class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role = 'Cliente',
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? fallbackToken}) {
    final userMap = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : json;

    String resolvedRole = userMap['role']?.toString() ?? '';
    if (resolvedRole.isEmpty && userMap['roles'] is List) {
      final rolesList = userMap['roles'] as List;
      if (rolesList.isNotEmpty) {
        final first = rolesList.first;
        if (first is Map && first['name'] != null) {
          resolvedRole = first['name'].toString();
        } else {
          resolvedRole = first.toString();
        }
      }
    }
    if (resolvedRole.isEmpty) {
      resolvedRole = 'Cliente';
    }

    return UserModel(
      id: (userMap['id'] as num?)?.toInt() ?? 0,
      name: userMap['name']?.toString() ?? 'Comensal',
      email: userMap['email']?.toString() ?? '',
      phone: userMap['phone']?.toString(),
      role: resolvedRole,
      token: json['token']?.toString() ?? fallbackToken ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': {
          'id': id,
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
        },
      };

  bool get isAdmin {
    final r = role.toLowerCase().trim();
    return r == 'admin' ||
        r == 'administrador' ||
        r == 'gerente' ||
        r == 'superadmin';
  }

  bool get isDriver {
    final r = role.toLowerCase().trim();
    return r == 'repartidor' || r == 'delivery' || r == 'driver';
  }

  bool get isDriverOrAdmin => isAdmin || isDriver;

  bool get isCustomer => !isDriverOrAdmin;
}

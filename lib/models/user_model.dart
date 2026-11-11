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
    return UserModel(
      id: (userMap['id'] as num?)?.toInt() ?? 0,
      name: userMap['name']?.toString() ?? 'Comensal',
      email: userMap['email']?.toString() ?? '',
      phone: userMap['phone']?.toString(),
      role: userMap['role']?.toString() ?? 'Cliente',
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

  bool get isDriverOrAdmin =>
      role.toLowerCase() == 'repartidor' ||
      role.toLowerCase() == 'administrador';
}

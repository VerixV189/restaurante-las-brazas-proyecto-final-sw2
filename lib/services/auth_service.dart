import 'dart:convert';
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/user_model.dart';
import 'package:restaurante_movil/services/http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'token';
  static const _userKey = 'user_profile';

  static Future<UserModel> login(String email, String password) async {
    final json = await HttpClient.post(
      ApiConstants.login,
      body: {
        'email': email.trim(),
        'password': password,
        'device_name': 'flutter_mobile',
      },
    );
    final user = UserModel.fromJson(json as Map<String, dynamic>);
    await _saveSession(user);
    return user;
  }

  static Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final json = await HttpClient.post(
      ApiConstants.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'device_name': 'flutter_mobile',
      },
    );
    final user = UserModel.fromJson(json as Map<String, dynamic>);
    await _saveSession(user);
    return user;
  }

  static Future<UserModel?> fetchMe() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final json = await HttpClient.get(ApiConstants.me, auth: true);
      final user = UserModel.fromJson(
        json as Map<String, dynamic>,
        fallbackToken: token,
      );
      await _saveSession(user);
      return user;
    } catch (_) {
      return getSavedUser();
    }
  }

  static Future<void> _saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user.token.isNotEmpty) {
      await prefs.setString(_tokenKey, user.token);
    }
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    final token = prefs.getString(_tokenKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map, fallbackToken: token);
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      await HttpClient.post(ApiConstants.logout, auth: true);
    } catch (_) {
      // Ignorar si el token ya expiró en el backend
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<UserModel> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstants.login),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final user = UserModel.fromJson(json);

      // guardar token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', user.token);

      return user;
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Error al iniciar sesión');
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}

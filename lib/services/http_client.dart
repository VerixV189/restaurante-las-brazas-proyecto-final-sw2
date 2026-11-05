import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:restaurante_movil/services/auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class HttpClient {
  static const Duration _timeout = Duration(seconds: 10);

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await AuthService.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String url, {bool auth = false}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers(auth: auth))
          .timeout(_timeout);
      return _handle(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor');
    }
  }

  static Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: await _headers(auth: auth),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeout);
      return _handle(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No se pudeo conectar con el servidor');
    }
  }

  // Devuelve el JSON completo o lanza ApiException
  static dynamic _handle(http.Response response) {
    final json = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    if (response.statusCode == 401) {
      throw ApiException('Sesión expirada, inicia sesión de nuevo', 401);
    }
    throw ApiException(
      json['message'] ?? 'Error del servidor',
      response.statusCode,
    );
  }
}

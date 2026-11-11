import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
  static const Duration _timeout = Duration(seconds: 15);

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<dynamic> get(
    String url, {
    bool auth = false,
    Map<String, String>? queryParameters,
  }) async {
    try {
      Uri uri = Uri.parse(url);
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final response = await http
          .get(uri, headers: await _headers(auth: auth))
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
      throw ApiException('No se pudo conectar con el servidor');
    }
  }

  static Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: await _headers(auth: auth),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeout);
      return _handle(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor');
    }
  }

  static Future<dynamic> delete(
    String url, {
    bool auth = false,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: await _headers(auth: auth),
          )
          .timeout(_timeout);
      return _handle(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor');
    }
  }

  static Future<Uint8List> getBytes(String url, {bool auth = true}) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/pdf',
      };
      if (auth) {
        final token = await AuthService.getToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      throw ApiException(
        'No se pudo descargar el comprobante (${response.statusCode})',
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Error de red al descargar el comprobante PDF');
    }
  }

  static dynamic _handle(http.Response response) {
    dynamic json;
    try {
      json = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    } catch (_) {
      json = {'message': 'Respuesta inválida del servidor'};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    if (response.statusCode == 401) {
      final msg = (json is Map && json['message'] != null)
          ? json['message'].toString()
          : 'Sesión expirada o credenciales inválidas';
      throw ApiException(msg, 401);
    }
    if (json is Map) {
      if (json['errors'] is Map) {
        final errorsMap = json['errors'] as Map;
        for (final entry in errorsMap.values) {
          if (entry is List && entry.isNotEmpty) {
            throw ApiException(entry.first.toString(), response.statusCode);
          }
        }
      }
      if (json['message'] != null) {
        throw ApiException(json['message'].toString(), response.statusCode);
      }
    }
    throw ApiException('Error del servidor (${response.statusCode})', response.statusCode);
  }
}

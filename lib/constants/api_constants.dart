import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Lee la URL base del .env
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8010';

  static String get _api => '$baseUrl/api/v1';

  // Endpoints de autenticacion
  static String get health => '$_api/health';
  static String get login => '$_api/auth/login';
  static String get register => '$_api/auth/register';
  static String get me => '$_api/auth/me';
  static String get logout => '$_api/auth/logout';

  // Endpoints de Catalogo
  static String get categories => '$_api/categories';
  static String get dishes => '$_api/dishes';
  static String dishById(int id) => '$_api/dishes/$id';
}

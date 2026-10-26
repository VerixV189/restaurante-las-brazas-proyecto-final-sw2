class ApiConstants {
  // Lee la URL base del .env
  static final String baseUrl = const String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  // Endpoints de autenticacion
  static final String login = '$baseUrl/api/login';
  static final String logout = '$baseUrl/api/logout';
  static final String userInfo = '$baseUrl/api/user';
}

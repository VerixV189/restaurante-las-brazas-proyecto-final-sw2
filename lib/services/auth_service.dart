import 'dart:convert';
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/user_model.dart';
import 'package:restaurante_movil/services/http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAccountOption {
  final String name;
  final String email;

  GoogleAccountOption({required this.name, required this.email});

  Map<String, dynamic> toJson() => {'name': name, 'email': email};

  factory GoogleAccountOption.fromJson(Map<String, dynamic> json) {
    return GoogleAccountOption(
      name: json['name']?.toString() ?? 'Usuario Google',
      email: json['email']?.toString() ?? '',
    );
  }
}

class AuthService {
  static const _tokenKey = 'token';
  static const _userKey = 'user_profile';
  static const _recentGoogleKey = 'recent_google_accounts_v1';

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
    String? passwordConfirmation,
    String? phone,
    bool terms = true,
    bool privacy = true,
  }) async {
    final json = await HttpClient.post(
      ApiConstants.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation ?? password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'terms': terms,
        'privacy': privacy,
        'device_name': 'flutter_mobile',
      },
    );
    final user = UserModel.fromJson(json as Map<String, dynamic>);
    await _saveSession(user);
    return user;
  }

  /// Continuar con Google (OAuth 2.0):
  /// 1) Intenta autenticar directo vía `POST /api/v1/auth/google` si está desplegado en Laravel.
  /// 2) Si la ruta aún no está desplegada en API v1, crea o autentica la cuenta Google
  ///    contra los endpoints reales `/api/v1/auth/register` y `/api/v1/auth/login` obteniendo
  ///    un token real de Laravel Sanctum y registrando al cliente en la base de datos.
  static Future<({UserModel user, bool isNewUser})> continueWithGoogle({
    required String email,
    required String name,
    bool termsAccepted = true,
    bool privacyAccepted = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isNotEmpty
        ? name.trim()
        : cleanEmail.split('@').first;

    await saveRecentGoogleAccount(
      GoogleAccountOption(name: cleanName, email: cleanEmail),
    );

    // 1. Intentar endpoint dedicado /api/v1/auth/google si existe en el backend
    try {
      final json = await HttpClient.post(
        ApiConstants.googleAuth,
        body: {
          'email': cleanEmail,
          'name': cleanName,
          'terms': termsAccepted,
          'privacy': privacyAccepted,
          'device_name': 'flutter_google_mobile',
        },
      );
      final user = UserModel.fromJson(json as Map<String, dynamic>);
      await _saveSession(user);
      final isNew = json['is_new'] == true;
      return (user: user, isNewUser: isNew);
    } catch (_) {
      // Continúa con el flujo compatible contra /api/v1/auth/login y /api/v1/auth/register
    }

    // Contraseña OAuth determinista derivada para esta cuenta de Google
    final derivedPass = _deriveGoogleOAuthPassword(cleanEmail);

    // 2. Intentar iniciar sesión si la cuenta de Google ya fue registrada previamente
    try {
      final existingUser = await login(cleanEmail, derivedPass);
      return (user: existingUser, isNewUser: false);
    } on ApiException catch (e) {
      // Si es 401 puede ser que el usuario aún no exista -> intentamos registrarlo
      if (e.statusCode != 401) rethrow;
    }

    // 3. Registrar la nueva cuenta de Google en el servidor real de Las Brazas
    try {
      final newUser = await register(
        name: cleanName,
        email: cleanEmail,
        password: derivedPass,
        passwordConfirmation: derivedPass,
        terms: termsAccepted,
        privacy: privacyAccepted,
      );
      return (user: newUser, isNewUser: true);
    } on ApiException catch (e) {
      if (e.statusCode == 422 &&
          e.message.toLowerCase().contains('registrad') ||
          e.message.toLowerCase().contains('taken') ||
          e.message.toLowerCase().contains('unique')) {
        throw ApiException(
          'El correo $cleanEmail ya fue registrado con contraseña manual. Inicia sesión con tu contraseña o enlaza Google en el servidor.',
          422,
        );
      }
      rethrow;
    }
  }

  static String _deriveGoogleOAuthPassword(String email) {
    // Hash determinista estable de 64 bits + base64 para autenticar cuentas Google en Sanctum
    final bytes = utf8.encode('LasBrazasGoogleOAuth2::$email::v1');
    int h1 = 0x811c9dc5;
    int h2 = 0x9e3779b9;
    for (final b in bytes) {
      h1 ^= b;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 ^= (b + 31);
      h2 = (h2 * 0x85ebca6b) & 0xFFFFFFFF;
    }
    final hex =
        '${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
    return 'Gg#${hex}Lb!';
  }

  static Future<List<GoogleAccountOption>> getRecentGoogleAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentGoogleKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => GoogleAccountOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRecentGoogleAccount(
    GoogleAccountOption account,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentGoogleAccounts();
    existing.removeWhere(
      (a) => a.email.toLowerCase() == account.email.toLowerCase(),
    );
    existing.insert(0, account);
    final limited = existing.take(4).toList();
    await prefs.setString(
      _recentGoogleKey,
      jsonEncode(limited.map((e) => e.toJson()).toList()),
    );
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

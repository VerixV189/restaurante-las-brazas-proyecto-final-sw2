import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String defaultBaseUrl = 'https://lasbrazas.ramio.tech';
  static const String _prefsKey = 'custom_base_url';
  static const String _geminiKeyPrefs = 'custom_gemini_api_key';
  static String? _overrideBaseUrl;
  static String? _overrideGeminiKey;

  /// Inicializa la URL y Gemini API Key guardadas en el dispositivo (si existen)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.trim().isNotEmpty) {
      // Migrar automáticamente si tenía guardada la IP antigua sin el dominio HTTPS
      if (saved.contains('3.210.205.227')) {
        _overrideBaseUrl = defaultBaseUrl;
        await prefs.setString(_prefsKey, defaultBaseUrl);
      } else {
        _overrideBaseUrl = normalizeBaseUrl(saved);
      }
    }
    final savedGemini = prefs.getString(_geminiKeyPrefs);
    if (savedGemini != null && savedGemini.trim().isNotEmpty) {
      _overrideGeminiKey = savedGemini.trim();
    }
  }

  /// Normaliza cualquier URL, dominio o IP (incluso si pegan https://lasbrazas.ramio.tech/api/v1/health)
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty || url.contains('3.210.205.227')) {
      return defaultBaseUrl;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final isLocal = url.startsWith('127.') ||
          url.startsWith('10.') ||
          url.startsWith('192.168.') ||
          url.startsWith('localhost');
      url = isLocal ? 'http://$url' : 'https://$url';
    }
    url = url.replaceAll(
      RegExp(r'/api/v1/health/?$', caseSensitive: false),
      '',
    );
    url = url.replaceAll(RegExp(r'/api/v1/?$', caseSensitive: false), '');
    url = url.replaceAll(RegExp(r'/api/?$', caseSensitive: false), '');
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Guarda y aplica en caliente una nueva URL de backend sin recompilar
  static Future<void> setCustomBaseUrl(String? rawUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      _overrideBaseUrl = null;
      await prefs.remove(_prefsKey);
    } else {
      final normalized = normalizeBaseUrl(rawUrl);
      _overrideBaseUrl = normalized;
      await prefs.setString(_prefsKey, normalized);
    }
  }

  /// Guarda y aplica en caliente una API Key de Google Gemini
  static Future<void> setCustomGeminiKey(String? rawKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (rawKey == null || rawKey.trim().isEmpty) {
      _overrideGeminiKey = null;
      await prefs.remove(_geminiKeyPrefs);
    } else {
      _overrideGeminiKey = rawKey.trim();
      await prefs.setString(_geminiKeyPrefs, _overrideGeminiKey!);
    }
  }

  static String? get customBaseUrl => _overrideBaseUrl;

  static String get geminiApiKey =>
      _overrideGeminiKey ?? (dotenv.env['GEMINI_API_KEY']?.trim() ?? '');

  // Lee la URL personalizada en memoria o la del .env
  static String get baseUrl =>
      _overrideBaseUrl ??
      normalizeBaseUrl(dotenv.env['BASE_URL'] ?? defaultBaseUrl);

  static String get _api => '$baseUrl/api/v1';

  // Conectividad
  static String get health => '$_api/health';

  // Endpoints de Autenticación
  static String get login => '$_api/auth/login';
  static String get register => '$_api/auth/register';
  static String get me => '$_api/auth/me';
  static String get logout => '$_api/auth/logout';

  // Endpoints de Catálogo y Menú
  static String get categories => '$_api/categories';
  static String get dishes => '$_api/dishes';
  static String dishById(int id) => '$_api/dishes/$id';

  // Endpoints de Direcciones del Cliente
  static String get addresses => '$_api/customer/addresses';
  static String addressById(int id) => '$_api/customer/addresses/$id';

  // Endpoints de Pedidos, Cotización, Cupones y Facturación
  static String get ordersQuote => '$_api/orders/quote';
  static String get couponsValidate => '$_api/coupons/validate';
  static String get orders => '$_api/orders';
  static String get ordersHistory => '$_api/orders/history';
  static String orderById(int id) => '$_api/orders/$id';
  static String orderPay(int id) => '$_api/orders/$id/pay';
  static String orderInvoice(int id) => '$_api/orders/$id/invoice';
  static String orderReorder(int id) => '$_api/orders/$id/reorder';
  static String orderCancel(int id) => '$_api/orders/$id/cancel';

  // Endpoints de Reservas y Zonas
  static String get areas => '$_api/areas';
  static String get reservationsAvailability =>
      '$_api/reservations/availability';
  static String get reservations => '$_api/reservations';
  static String reservationCancel(int id) => '$_api/reservations/$id/cancel';

  // Endpoints de Repartidor / Delivery
  static String get deliveryPending => '$_api/delivery/pending';
  static String get deliveryMine => '$_api/delivery/mine';
  static String deliveryTake(int id) => '$_api/delivery/$id/take';
  static String deliveryPickup(int id) => '$_api/delivery/$id/pickup';
  static String deliveryConfirm(int id) => '$_api/delivery/$id/confirm';

  // Endpoints de Asistente IA
  static String get aiChatV1 => '$_api/ai/chat';
  static String get aiChat => '$baseUrl/ai/chat';
}

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String _prefsKey = 'custom_base_url';
  static String? _overrideBaseUrl;

  /// Inicializa la URL personalizada guardada en el dispositivo (si existe)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _overrideBaseUrl = normalizeBaseUrl(saved);
    }
  }

  /// Normaliza cualquier URL o IP (incluso si pegan http://3.210.205.227/api/v1/health)
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return 'http://3.210.205.227';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    // Si el usuario pegó la ruta completa (/api/v1/health o /api/v1), dejamos solo el host[:puerto]
    url = url.replaceAll(RegExp(r'/api/v1/health/?$', caseSensitive: false), '');
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

  static String? get customBaseUrl => _overrideBaseUrl;

  // Lee la URL personalizada en memoria o la del .env
  static String get baseUrl =>
      _overrideBaseUrl ??
      normalizeBaseUrl(dotenv.env['BASE_URL'] ?? 'http://3.210.205.227');

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

  // Endpoints de Direcciones del Cliente (RF-05, RF-13)
  static String get addresses => '$_api/customer/addresses';
  static String addressById(int id) => '$_api/customer/addresses/$id';

  // Endpoints de Pedidos, Cotización, Cupones y Facturación (RF-03 a RF-11, RF-14, RF-22)
  static String get ordersQuote => '$_api/orders/quote';
  static String get couponsValidate => '$_api/coupons/validate';
  static String get orders => '$_api/orders';
  static String get ordersHistory => '$_api/orders/history';
  static String orderById(int id) => '$_api/orders/$id';
  static String orderPay(int id) => '$_api/orders/$id/pay';
  static String orderInvoice(int id) => '$_api/orders/$id/invoice';
  static String orderReorder(int id) => '$_api/orders/$id/reorder';
  static String orderCancel(int id) => '$_api/orders/$id/cancel';

  // Endpoints de Reservas y Zonas (RF-12, RF-13)
  static String get areas => '$_api/areas';
  static String get reservationsAvailability =>
      '$_api/reservations/availability';
  static String get reservations => '$_api/reservations';
  static String reservationCancel(int id) => '$_api/reservations/$id/cancel';

  // Endpoints de Repartidor / Delivery (RF-17, RF-18, RF-19)
  static String get deliveryPending => '$_api/delivery/pending';
  static String get deliveryMine => '$_api/delivery/mine';
  static String deliveryTake(int id) => '$_api/delivery/$id/take';
  static String deliveryPickup(int id) => '$_api/delivery/$id/pickup';
  static String deliveryConfirm(int id) => '$_api/delivery/$id/confirm';

  // Endpoint de Asistente IA (RF-26, RF-27)
  static String get aiChat => '$baseUrl/ai/chat';
}

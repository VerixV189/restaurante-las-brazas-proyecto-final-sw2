import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService extends ChangeNotifier {
  OfflineCacheService._();
  static final OfflineCacheService instance = OfflineCacheService._();

  static const String _categoriesCacheKey = 'pwa_offline_categories_v1';
  static const String _dishesCacheKey = 'pwa_offline_dishes_v1';
  static const String _areasCacheKey = 'pwa_offline_areas_v1';
  static const String _manualOfflinePrefKey = 'pwa_manual_offline_mode';
  static const String _lastUserIdKey = 'security_last_user_id';
  static const String _lastUserWasStaffKey = 'security_last_user_was_staff';

  bool _serverReachable = true;
  bool _manualOffline = false;
  bool _checking = false;
  DateTime? _lastSyncAt;

  bool get isOffline => _manualOffline || !_serverReachable;
  bool get isOnline => !isOffline;
  bool get isManualOffline => _manualOffline;
  bool get isChecking => _checking;
  DateTime? get lastSyncAt => _lastSyncAt;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _manualOffline = prefs.getBool(_manualOfflinePrefKey) ?? false;
    notifyListeners();
    if (!_manualOffline) {
      unawaited(verifyConnection());
    }
  }

  /// Permite al usuario alternar entre Modo Offline y Modo Conectado desde el botón de estado
  Future<bool> toggleManualOfflineMode() async {
    _manualOffline = !_manualOffline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_manualOfflinePrefKey, _manualOffline);
    if (!_manualOffline) {
      await verifyConnection();
    } else {
      notifyListeners();
    }
    return isOffline;
  }

  /// Intenta reconectar con el servidor y desactivar el modo offline manual
  Future<bool> reconnect() async {
    _manualOffline = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_manualOfflinePrefKey, false);
    return verifyConnection();
  }

  /// Verifica en vivo si el backend responde en `/api/v1/health`
  Future<bool> verifyConnection() async {
    if (_manualOffline) {
      notifyListeners();
      return false;
    }
    _checking = true;
    notifyListeners();
    try {
      final res = await http
          .get(
            Uri.parse(ApiConstants.health),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
      _serverReachable = res.statusCode >= 200 && res.statusCode < 400;
      if (_serverReachable) {
        _lastSyncAt = DateTime.now();
      }
    } catch (_) {
      _serverReachable = false;
    } finally {
      _checking = false;
      notifyListeners();
    }
    return _serverReachable;
  }

  void reportNetworkSuccess() {
    if (!_serverReachable) {
      _serverReachable = true;
      _lastSyncAt = DateTime.now();
      notifyListeners();
    } else {
      _lastSyncAt = DateTime.now();
    }
  }

  void reportNetworkFailure() {
    if (_serverReachable) {
      _serverReachable = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // AISLAMIENTO ESTRICTO DE DATOS ENTRE ADMINISTRADOR / REPARTIDOR Y CLIENTE
  // ===========================================================================

  /// Se ejecuta cuando cualquier usuario (especialmente Administrador) cierra sesión.
  /// Borra todos los datos privados de sesión y garantiza que ningún cliente posterior
  /// pueda ver pedidos, entregas, direcciones ni estados del Administrador.
  Future<void> purgeSessionOnLogout(UserModel? loggingOutUser) async {
    final prefs = await SharedPreferences.getInstance();

    // Limpiar claves globales heredadas para que nunca se filtren entre cuentas
    await prefs.remove('cancelled_orders_v1');
    await prefs.remove('loyalty_points');
    await prefs.remove('dietary_prefs');

    if (loggingOutUser != null) {
      final uid = loggingOutUser.id;
      // Si quien cierra sesión es Administrador o Repartidor, purgar absolutamente toda su caché local
      if (loggingOutUser.isDriverOrAdmin) {
        await _purgeAllKeysForUserId(prefs, uid);
      }
    }

    // Además, si había claves temporales de staff/admin, eliminarlas
    final allKeys = prefs.getKeys().toList();
    for (final k in allKeys) {
      if (k.startsWith('staff_cache_') || k.startsWith('admin_cache_')) {
        await prefs.remove(k);
      }
    }
  }

  /// Se ejecuta cuando un usuario inicia sesión.
  /// Si el usuario anterior era Administrador/Repartidor o un ID distinto,
  /// purga cualquier rastro del administrador antes de activar la sesión del cliente.
  Future<void> enforceUserIsolationOnLogin(UserModel newUser) async {
    final prefs = await SharedPreferences.getInstance();
    final prevUserId = prefs.getInt(_lastUserIdKey);
    final prevWasStaff = prefs.getBool(_lastUserWasStaffKey) ?? false;

    // Eliminar cualquier clave global antigua sin ID de usuario
    await prefs.remove('cancelled_orders_v1');
    await prefs.remove('loyalty_points');
    await prefs.remove('dietary_prefs');

    if (prevUserId != null && (prevWasStaff || prevUserId != newUser.id)) {
      if (prevWasStaff) {
        await _purgeAllKeysForUserId(prefs, prevUserId);
      }
    }

    await prefs.setInt(_lastUserIdKey, newUser.id);
    await prefs.setBool(_lastUserWasStaffKey, newUser.isDriverOrAdmin);
  }

  Future<void> _purgeAllKeysForUserId(
    SharedPreferences prefs,
    int userId,
  ) async {
    final suffix = '_u_$userId';
    final keysToDelete =
        prefs.getKeys().where((k) => k.endsWith(suffix)).toList();
    for (final k in keysToDelete) {
      await prefs.remove(k);
    }
  }

  // ===========================================================================
  // CACHÉ OFFLINE DE CATÁLOGO PÚBLICO (Categorías, Platillos y Áreas)
  // ===========================================================================

  Future<void> cacheCategories(List<dynamic> rawList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesCacheKey, jsonEncode(rawList));
  }

  Future<List<Map<String, dynamic>>> getCachedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesCacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }
    return _fallbackCategories;
  }

  Future<void> cacheDishes(List<dynamic> rawList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dishesCacheKey, jsonEncode(rawList));
  }

  Future<List<Map<String, dynamic>>> getCachedDishes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dishesCacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }
    return _fallbackDishes;
  }

  Future<void> cacheAreas(List<dynamic> rawList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_areasCacheKey, jsonEncode(rawList));
  }

  Future<List<Map<String, dynamic>>> getCachedAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_areasCacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }
    return _fallbackAreas;
  }

  // ===========================================================================
  // CACHÉ OFFLINE AISLADA POR USUARIO (Pedidos, Reservas y Direcciones)
  // ===========================================================================

  /// Guarda pedidos únicamente bajo el ID del usuario actual (y nunca persiste datos de Admin si se desloguea)
  Future<void> cacheUserOrders(int userId, List<dynamic> rawList) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orders_cache_u_$userId', jsonEncode(rawList));
  }

  Future<List<Map<String, dynamic>>> getCachedUserOrders(int userId) async {
    if (userId <= 0) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('orders_cache_u_$userId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheUserAddresses(int userId, List<dynamic> rawList) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('addresses_cache_u_$userId', jsonEncode(rawList));
  }

  Future<List<Map<String, dynamic>>> getCachedUserAddresses(int userId) async {
    if (userId <= 0) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('addresses_cache_u_$userId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheUserReservations(
    int userId,
    Map<String, dynamic> rawMap,
  ) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reservations_cache_u_$userId', jsonEncode(rawMap));
  }

  Future<Map<String, dynamic>> getCachedUserReservations(int userId) async {
    if (userId <= 0) return {'active': [], 'history': []};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('reservations_cache_u_$userId');
    if (raw == null || raw.isEmpty) return {'active': [], 'history': []};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {'active': [], 'history': []};
    }
  }

  // Respaldo inicial por si abre la app por primera vez sin internet
  static const List<Map<String, dynamic>> _fallbackCategories = [
    {
      'id': 1,
      'name': 'Entradas',
      'slug': 'entradas',
      'description': 'Botanas y aperitivos a la brasa',
      'icon': 'Utensils',
      'is_active': true,
      'dishes_count': 2,
    },
    {
      'id': 2,
      'name': 'Cortes & Parrilladas',
      'slug': 'cortes-y-parrilladas',
      'description': 'Especialidades a la leña y carbón',
      'icon': 'Flame',
      'is_active': true,
      'dishes_count': 3,
    },
    {
      'id': 7,
      'name': 'Bebidas',
      'slug': 'bebidas',
      'description': 'Refrescos, aguas y coctelería',
      'icon': 'GlassWater',
      'is_active': true,
      'dishes_count': 1,
    },
  ];

  static const List<Map<String, dynamic>> _fallbackDishes = [
    {
      'id': 6,
      'category_id': 2,
      'category_name': 'Cortes & Parrilladas',
      'name': 'Arrachera Las Brazas (300g)',
      'description':
          'Corte insignia marinado por 24 horas, acompañado de cebollitas cambray, chiles toreados y guacamole.',
      'price': 320,
      'image_url':
          'https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=800&q=80',
      'prep_time_minutes': 20,
      'is_available': true,
      'is_meat': true,
      'meat_cooking_terms': [
        'Vuelta y vuelta (Sellado)',
        'Término Medio (A punto)',
        'Tres Cuartos (Jugoso)',
        'Bien Cocido',
      ],
    },
    {
      'id': 7,
      'category_id': 2,
      'category_name': 'Cortes & Parrilladas',
      'name': 'Bife de Chorizo Angus Madurado (400g)',
      'description':
          'Corte argentino de lomo angosto con 28 días de maduración Dry-Aged al quebracho.',
      'price': 420,
      'image_url':
          'https://images.unsplash.com/photo-1600891964092-4316c288032e?auto=format&fit=crop&w=800&q=80',
      'prep_time_minutes': 22,
      'is_available': true,
      'is_meat': true,
      'meat_cooking_terms': [
        'Vuelta y vuelta (Sellado)',
        'Término Medio (A punto)',
        'Tres Cuartos (Jugoso)',
        'Bien Cocido',
      ],
    },
    {
      'id': 8,
      'category_id': 2,
      'category_name': 'Cortes & Parrilladas',
      'name': 'Picaña Prime a la Espada (350g)',
      'description':
          'Tapa de cuadril premium asada en espada estilo rodizio con costra de sal marina gruesa.',
      'price': 380,
      'image_url':
          'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?auto=format&fit=crop&w=800&q=80',
      'prep_time_minutes': 20,
      'is_available': true,
      'is_meat': true,
      'meat_cooking_terms': [
        'Vuelta y vuelta (Sellado)',
        'Término Medio (A punto)',
        'Tres Cuartos (Jugoso)',
        'Bien Cocido',
      ],
    },
    {
      'id': 1,
      'category_id': 1,
      'category_name': 'Entradas',
      'name': 'Queso Fundido con Chistorra',
      'description':
          'Servido en cazuela de barro caliente con queso gouda, chistorra navarra y tortillas de harina.',
      'price': 145,
      'image_url':
          'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=800&q=80',
      'prep_time_minutes': 10,
      'is_available': true,
      'is_meat': false,
      'meat_cooking_terms': [],
    },
    {
      'id': 28,
      'category_id': 7,
      'category_name': 'Bebidas',
      'name': 'Agua Mineral / Refresco Línea (500ml)',
      'description': 'Servido bien frío en copa con hielo cristalino y limón.',
      'price': 45,
      'image_url':
          'https://images.unsplash.com/photo-1556881286-fc6915169721?auto=format&fit=crop&w=800&q=80',
      'prep_time_minutes': 2,
      'is_available': true,
      'is_meat': false,
      'meat_cooking_terms': [],
    },
  ];

  static const List<Map<String, dynamic>> _fallbackAreas = [
    {
      'id': 1,
      'name': 'Salón Principal',
      'description': 'Ambiente climatizado junto a la parrilla central',
      'capacity': 40,
      'seats_left': 24,
      'is_available': true,
    },
    {
      'id': 2,
      'name': 'Terraza al Aire Libre',
      'description': 'Espacio abierto ideal para cenas y grupos',
      'capacity': 28,
      'seats_left': 16,
      'is_available': true,
    },
    {
      'id': 3,
      'name': 'Salón Ejecutivo VIP',
      'description': 'Privacidad y atención personalizada de sommelier',
      'capacity': 16,
      'seats_left': 10,
      'is_available': true,
    },
  ];
}

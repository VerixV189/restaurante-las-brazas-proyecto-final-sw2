import 'package:flutter/material.dart';
import 'package:restaurante_movil/models/user_model.dart';
import 'package:restaurante_movil/services/auth_service.dart';
import 'package:restaurante_movil/services/offline_cache_service.dart';
import 'package:restaurante_movil/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String title;
  final String body;
  final String category; // 'promo' | 'order' | 'reservation'
  final DateTime createdAt;
  bool read;

  AppNotification({
    required this.title,
    required this.body,
    this.category = 'promo',
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  ThemeMode _themeMode = ThemeMode.system;
  int _loyaltyPoints = 120;
  List<String> _dietaryPreferences = [];
  List<AppNotification> _notifications = _defaultWelcomeNotifications();

  static List<AppNotification> _defaultWelcomeNotifications() => [
        AppNotification(
          title: '🔥 ¡Bienvenido a Las Brazas Steakhouse!',
          body:
              'Usa el cupón BRAZAS10 para 10% de descuento o disfruta envío gratis en pedidos mayores a \$50.',
          category: 'promo',
        ),
      ];

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isDriverOrAdmin => _user?.isDriverOrAdmin ?? false;
  ThemeMode get themeMode => _themeMode;
  int get loyaltyPoints => _loyaltyPoints;
  double get cashbackBalance => _loyaltyPoints * 0.10; // 10 pts = $1.00
  List<String> get dietaryPreferences => List.unmodifiable(_dietaryPreferences);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.read).length;

  String get _pointsPrefKey => 'loyalty_points_u_${_user?.id ?? 0}';
  String get _dietPrefKey => 'dietary_prefs_u_${_user?.id ?? 0}';

  Future<void> initialize() async {
    await OfflineCacheService.instance.init();
    _user = await AuthService.getSavedUser();
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    if (_user != null) {
      await OfflineCacheService.instance.enforceUserIsolationOnLogin(_user!);
      _loyaltyPoints = prefs.getInt(_pointsPrefKey) ?? 120;
      _dietaryPreferences = prefs.getStringList(_dietPrefKey) ?? [];
      _startRealtimePushWatcher();
      notifyListeners();

      final fresh = await AuthService.fetchMe();
      if (fresh != null) {
        _user = fresh;
        notifyListeners();
      }
    } else {
      _loyaltyPoints = 120;
      _dietaryPreferences = [];
      notifyListeners();
    }
  }

  void _startRealtimePushWatcher() {
    PushNotificationService.startRealtimeWatcher(
      onNewNotification: ({
        required String title,
        required String body,
        required String category,
        bool triggerNativePush = true,
      }) {
        pushNotification(
          title: title,
          body: body,
          category: category,
          triggerNativePush: triggerNativePush,
        );
      },
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
            ? 'light'
            : 'system';
    await prefs.setString('theme_mode', value);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool isCurrentlyDark) async {
    await setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Al iniciar sesión con un nuevo usuario (ej. Cliente después de un Admin),
  /// aísla completamente la sesión y purga cualquier dato de administrador previo.
  Future<void> setUser(UserModel user) async {
    _user = user;
    _notifications = _defaultWelcomeNotifications();
    await OfflineCacheService.instance.enforceUserIsolationOnLogin(user);
    final prefs = await SharedPreferences.getInstance();
    _loyaltyPoints = prefs.getInt(_pointsPrefKey) ?? 120;
    _dietaryPreferences = prefs.getStringList(_dietPrefKey) ?? [];
    _startRealtimePushWatcher();
    notifyListeners();
  }

  Future<void> addLoyaltyPoints(int points, {String? reason}) async {
    _loyaltyPoints += points;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsPrefKey, _loyaltyPoints);
    if (reason != null) {
      pushNotification(
        title: '🎁 +$points Puntos Las Brazas',
        body: reason,
        category: 'promo',
        triggerNativePush: false,
      );
    }
    notifyListeners();
  }

  Future<bool> redeemPoints(int pointsToRedeem) async {
    if (_loyaltyPoints < pointsToRedeem) return false;
    _loyaltyPoints -= pointsToRedeem;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsPrefKey, _loyaltyPoints);
    pushNotification(
      title: '🎟️ ¡Cupón BRAZAS10 Activado!',
      body:
          'Canjeaste $pointsToRedeem puntos de fidelidad por un 10% de descuento aplicado en tu carrito.',
      category: 'promo',
    );
    notifyListeners();
    return true;
  }

  /// Aplica la reversión de puntos del pedido cancelado + penalización en puntos de lealtad
  Future<void> applyCancellationPenalty({
    required int orderId,
    required int earnedPointsToRevert,
    required int penaltyPoints,
    required double penaltyAmount,
    required double refundAmount,
  }) async {
    final totalPointsDeducted = earnedPointsToRevert + penaltyPoints;
    _loyaltyPoints = (_loyaltyPoints - totalPointsDeducted).clamp(0, 999999);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsPrefKey, _loyaltyPoints);
    pushNotification(
      title: '⚠️ Pedido #$orderId Cancelado con Penalización',
      body:
          'Cargo por cancelación: -\$${penaltyAmount.toStringAsFixed(2)} • Reembolso neto: \$${refundAmount.toStringAsFixed(2)} • Penalización de fidelidad: -$penaltyPoints pts.',
      category: 'order',
    );
    notifyListeners();
  }

  Future<void> toggleDietaryPreference(String pref) async {
    if (_dietaryPreferences.contains(pref)) {
      _dietaryPreferences.remove(pref);
    } else {
      _dietaryPreferences.add(pref);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dietPrefKey, _dietaryPreferences);
    notifyListeners();
  }

  void pushNotification({
    required String title,
    required String body,
    String category = 'order',
    bool triggerNativePush = true,
  }) {
    _notifications.insert(
      0,
      AppNotification(title: title, body: body, category: category),
    );
    if (triggerNativePush) {
      PushNotificationService.showNativePush(title: title, body: body);
    }
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  /// Cierra sesión purgando todos los datos en memoria y caché de Administrador/Staff
  /// para que ningún usuario posterior pueda visualizar datos de la cuenta anterior.
  Future<void> logout() async {
    final previousUser = _user;
    PushNotificationService.stopRealtimeWatcher();
    await OfflineCacheService.instance.purgeSessionOnLogout(previousUser);
    await AuthService.logout();
    _user = null;
    _loyaltyPoints = 120;
    _dietaryPreferences = [];
    _notifications = _defaultWelcomeNotifications();
    notifyListeners();
  }
}

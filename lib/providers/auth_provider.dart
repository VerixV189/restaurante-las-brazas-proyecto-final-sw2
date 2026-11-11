import 'package:flutter/material.dart';
import 'package:restaurante_movil/models/user_model.dart';
import 'package:restaurante_movil/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String title;
  final String body;
  final DateTime createdAt;
  bool read;

  AppNotification({
    required this.title,
    required this.body,
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  int _loyaltyPoints = 120; // Programa de Puntos / Cashback inicial (RF-23)
  List<String> _dietaryPreferences = [];
  final List<AppNotification> _notifications = [
    AppNotification(
      title: '🔥 ¡Bienvenido a Las Brazas!',
      body: 'Usa el cupón BRAZAS10 o disfruta envío gratis en pedidos mayores a \$50.',
    ),
  ];

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  int get loyaltyPoints => _loyaltyPoints;
  double get cashbackBalance => _loyaltyPoints * 0.10; // 10 pts = $1.00
  List<String> get dietaryPreferences => List.unmodifiable(_dietaryPreferences);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.read).length;

  Future<void> initialize() async {
    _user = await AuthService.getSavedUser();
    final prefs = await SharedPreferences.getInstance();
    _loyaltyPoints = prefs.getInt('loyalty_points') ?? 120;
    _dietaryPreferences = prefs.getStringList('dietary_prefs') ?? [];
    notifyListeners();
    if (_user != null) {
      final fresh = await AuthService.fetchMe();
      if (fresh != null) {
        _user = fresh;
        notifyListeners();
      }
    }
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> addLoyaltyPoints(int points, {String? reason}) async {
    _loyaltyPoints += points;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('loyalty_points', _loyaltyPoints);
    if (reason != null) {
      pushNotification(
        title: '🎁 +$points Puntos Las Brazas',
        body: reason,
      );
    }
    notifyListeners();
  }

  Future<bool> redeemPoints(int pointsToRedeem) async {
    if (_loyaltyPoints < pointsToRedeem) return false;
    _loyaltyPoints -= pointsToRedeem;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('loyalty_points', _loyaltyPoints);
    notifyListeners();
    return true;
  }

  Future<void> toggleDietaryPreference(String pref) async {
    if (_dietaryPreferences.contains(pref)) {
      _dietaryPreferences.remove(pref);
    } else {
      _dietaryPreferences.add(pref);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dietary_prefs', _dietaryPreferences);
    notifyListeners();
  }

  void pushNotification({required String title, required String body}) {
    _notifications.insert(
      0,
      AppNotification(title: title, body: body),
    );
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }
}


import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:restaurante_movil/models/address_model.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/services/order_service.dart';

class CartProvider extends ChangeNotifier {
  static const double standardDeliveryFee = 3.00;
  static const double freeDeliveryThreshold = 50.00;

  final List<CartItemModel> _items = [];
  String _orderType = 'delivery'; // 'delivery', 'takeaway', 'dine_in'
  int _selectedTableId = 1;
  AddressModel? _selectedAddress;

  String? _couponCode;
  double _discount = 0.0;
  bool _freeShippingCoupon = false;
  double _tax = 0.0;
  List<int>? _backendEstimatedMinutes;

  List<CartItemModel> get items => List.unmodifiable(_items);
  String get orderType => _orderType;
  int get selectedTableId => _selectedTableId;
  AddressModel? get selectedAddress => _selectedAddress;
  String? get couponCode => _couponCode;
  double get discount => _discount;
  double get tax => _tax;

  int get totalItemsCount =>
      _items.fold(0, (acc, item) => acc + item.quantity);

  bool get isEmpty => _items.isEmpty;

  double get subtotal =>
      _items.fold(0.0, (acc, item) => acc + item.subtotal);

  double get deliveryFee {
    if (_orderType != 'delivery' || _items.isEmpty) return 0.0;
    if (_freeShippingCoupon || subtotal >= freeDeliveryThreshold) return 0.0;
    return standardDeliveryFee;
  }

  double get total =>
      math.max(0.0, subtotal - _discount + _tax + deliveryFee);

  /// Tiempo estimado [min, max] en minutos (RF-06)
  List<int> get estimatedMinutes {
    if (_backendEstimatedMinutes != null &&
        _backendEstimatedMinutes!.length >= 2) {
      return _backendEstimatedMinutes!;
    }
    if (_items.isEmpty) return const [25, 40];
    final maxPrep = _items.fold<int>(
      15,
      (prev, e) => math.max(prev, e.dish.prepTimeMinutes),
    );
    final base = maxPrep + (_orderType == 'delivery' ? 30 : 0);
    return [base, base + 15];
  }

  void setOrderType(String type) {
    if (_orderType == type) return;
    _orderType = type;
    notifyListeners();
    syncQuoteWithBackend();
  }

  void setSelectedTableId(int tableId) {
    _selectedTableId = tableId;
    notifyListeners();
  }

  void setSelectedAddress(AddressModel? address) {
    _selectedAddress = address;
    notifyListeners();
  }

  void addItem(CartItemModel newItem) {
    final index =
        _items.indexWhere((existing) => existing.variantKey == newItem.variantKey);
    if (index >= 0) {
      _items[index].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
    notifyListeners();
    syncQuoteWithBackend();
  }

  void updateQuantity(int index, int newQuantity) {
    if (index < 0 || index >= _items.length) return;
    if (newQuantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = newQuantity;
    }
    if (_items.isEmpty) {
      clearCoupon();
    }
    notifyListeners();
    syncQuoteWithBackend();
  }

  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    if (_items.isEmpty) {
      clearCoupon();
    }
    notifyListeners();
    syncQuoteWithBackend();
  }

  Future<String> applyCoupon(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw Exception('Ingresa un código de cupón válido.');
    }
    try {
      final data = await OrderService.validateCoupon(
        code: normalized,
        subtotal: subtotal,
      );
      _couponCode = data['code']?.toString() ?? normalized;
      _discount =
          double.tryParse(data['discount']?.toString() ?? '0') ?? 0.0;
      _freeShippingCoupon = data['free_shipping'] == true;
      notifyListeners();
      await syncQuoteWithBackend();
      return 'Cupón $_couponCode aplicado correctamente.';
    } catch (e) {
      // Soporte local para códigos de demostración indicados en los requisitos (RF-22)
      if (normalized == 'BRAZAS10') {
        _couponCode = 'BRAZAS10';
        _discount = double.parse((subtotal * 0.10).toStringAsFixed(2));
        _freeShippingCoupon = false;
        notifyListeners();
        return 'Cupón BRAZAS10 (10% desc.) aplicado.';
      }
      if (normalized == 'ENVIOGRATIS') {
        _couponCode = 'ENVIOGRATIS';
        _discount = 0.0;
        _freeShippingCoupon = true;
        notifyListeners();
        return 'Cupón ENVIOGRATIS aplicado.';
      }
      rethrow;
    }
  }

  void clearCoupon() {
    _couponCode = null;
    _discount = 0.0;
    _freeShippingCoupon = false;
    notifyListeners();
  }

  /// Sincroniza la cotización con `/api/v1/orders/quote` si el backend está disponible
  Future<void> syncQuoteWithBackend() async {
    if (_items.isEmpty) return;
    try {
      final quote = await OrderService.quoteOrder(
        items: _items,
        orderType: _orderType,
        couponCode: _couponCode,
      );
      _tax = double.tryParse(quote['tax']?.toString() ?? '0') ?? 0.0;
      if (quote['discount'] != null) {
        _discount =
            double.tryParse(quote['discount'].toString()) ?? _discount;
      }
      if (quote['estimated_minutes'] is List) {
        final mins = (quote['estimated_minutes'] as List)
            .map((e) => (e as num).toInt())
            .toList();
        if (mins.length >= 2) {
          _backendEstimatedMinutes = mins;
        }
      }
      notifyListeners();
    } catch (_) {
      // Mantiene el cálculo local si falla o el cupón es local
    }
  }

  /// Carga ítems desde la función "Volver a pedir" (RF-14)
  void loadFromReorder(
    List<Map<String, dynamic>> rawItems,
    List<DishModel> catalog,
  ) {
    for (final raw in rawItems) {
      final dishId = (raw['dish_id'] as num?)?.toInt();
      if (dishId == null) continue;
      final match = catalog.where((d) => d.id == dishId).toList();
      if (match.isNotEmpty) {
        addItem(
          CartItemModel(
            dish: match.first,
            quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
            customNotes: raw['notes']?.toString(),
          ),
        );
      }
    }
  }

  void clear() {
    _items.clear();
    _couponCode = null;
    _discount = 0.0;
    _freeShippingCoupon = false;
    _tax = 0.0;
    _backendEstimatedMinutes = null;
    notifyListeners();
  }
}


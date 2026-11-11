import 'package:restaurante_movil/models/dish_model.dart';

class CartItemModel {
  final DishModel dish;
  int quantity;
  final String? cookingTerm;
  final String? sideDish;
  final List<String> extras;
  final String? customNotes;

  CartItemModel({
    required this.dish,
    this.quantity = 1,
    this.cookingTerm,
    this.sideDish,
    this.extras = const [],
    this.customNotes,
  });

  double get unitPrice => dish.price;
  double get subtotal => unitPrice * quantity;

  /// Clave única para distinguir el mismo platillo con diferentes variantes
  String get variantKey =>
      '${dish.id}|${cookingTerm ?? ''}|${sideDish ?? ''}|${extras.join(',')}|${customNotes ?? ''}';

  /// Notas formateadas para enviarse a Cocina (KDS) en `items.*.notes` (máx 255 chars)
  String? get formattedNotes {
    final parts = <String>[];
    if (cookingTerm != null && cookingTerm!.isNotEmpty) {
      parts.add('Término: $cookingTerm');
    }
    if (sideDish != null && sideDish!.isNotEmpty) {
      parts.add('Guarnición: $sideDish');
    }
    if (extras.isNotEmpty) {
      parts.add('Extras: ${extras.join(', ')}');
    }
    if (customNotes != null && customNotes!.trim().isNotEmpty) {
      parts.add('Nota: ${customNotes!.trim()}');
    }
    if (parts.isEmpty) return null;
    final joined = parts.join(' | ');
    return joined.length > 250 ? joined.substring(0, 250) : joined;
  }

  Map<String, dynamic> toOrderJson() => {
        'dish_id': dish.id,
        'quantity': quantity,
        if (formattedNotes != null) 'notes': formattedNotes,
      };
}


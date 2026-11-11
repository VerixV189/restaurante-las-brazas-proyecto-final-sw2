import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/cart_screen.dart';
import 'package:restaurante_movil/widgets/brand_logo.dart';

class DishDetailScreen extends StatefulWidget {
  final DishModel dish;
  const DishDetailScreen({super.key, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  static const List<String> _availableSideDishes = [
    'Papas a la francesa',
    'Ensalada fresca de la casa',
    'Cebollitas cambray y chiles toreados',
    'Puré de papa rústico',
    'Verduras al grill',
  ];

  static const List<String> _availableExtras = [
    'Guacamole extra',
    'Porción de tortillas recién hechas',
    'Salsa chimichurri de la casa',
    'Queso fundido extra',
  ];

  String? _selectedCookingTerm;
  String? _selectedSideDish;
  final Set<String> _selectedExtras = {};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.dish.isMeat && widget.dish.meatCookingTerms.isNotEmpty) {
      _selectedCookingTerm = widget.dish.meatCookingTerms.first;
    } else if (widget.dish.isMeat) {
      _selectedCookingTerm = 'Término Medio (A punto)';
    }
    _selectedSideDish = _availableSideDishes.first;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<String> get _cookingTerms {
    if (widget.dish.meatCookingTerms.isNotEmpty) {
      return widget.dish.meatCookingTerms;
    }
    return const [
      'Vuelta y vuelta (Sellado)',
      'Término Medio (A punto)',
      'Tres Cuartos (Jugoso)',
      'Bien Cocido',
    ];
  }

  void _addToCart() {
    final cart = context.read<CartProvider>();
    final item = CartItemModel(
      dish: widget.dish,
      quantity: _quantity,
      cookingTerm: widget.dish.isMeat ? _selectedCookingTerm : null,
      sideDish: _selectedSideDish,
      extras: _selectedExtras.toList(),
      customNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    cart.addItem(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_quantity}x ${widget.dish.name} agregado al carrito'),
        action: SnackBarAction(
          label: 'VER CARRITO',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    final total = dish.price * _quantity;

    return Scaffold(
      appBar: AppBar(title: Text(dish.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Stack(
            children: [
              dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                  ? Image.network(
                      dish.imageUrl!,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const SizedBox(
                        height: 220,
                        child: Center(child: BrandLogo(size: 130)),
                      ),
                    )
                  : const SizedBox(
                      height: 220,
                      child: Center(child: BrandLogo(size: 130)),
                    ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.orangeAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Prep: ${dish.prepTimeMinutes} min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dish.categoryName.isNotEmpty)
                  Chip(
                    label: Text(dish.categoryName),
                    visualDensity: VisualDensity.compact,
                  ),
                Text(
                  dish.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${dish.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  dish.description ?? 'Especialidad preparada al momento.',
                  style: const TextStyle(fontSize: 15),
                ),
                const Divider(height: 32),

                // RF-02: Término de la carne (si aplica)
                if (dish.isMeat) ...[
                  const Row(
                    children: [
                      Icon(Icons.whatshot, color: Colors.deepOrange, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Término de la Carne (Obligatorio)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._cookingTerms.map(
                    (term) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _selectedCookingTerm == term
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _selectedCookingTerm == term
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      title: Text(term),
                      onTap: () => setState(() => _selectedCookingTerm = term),
                    ),
                  ),
                  const Divider(height: 24),
                ],

                // RF-02: Guarnición a elegir
                Row(
                  children: [
                    Icon(
                      Icons.dinner_dining,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Guarnición de Acompañamiento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _availableSideDishes.map((side) {
                    final selected = _selectedSideDish == side;
                    return ChoiceChip(
                      label: Text(side),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedSideDish = side),
                    );
                  }).toList(),
                ),
                const Divider(height: 28),

                // RF-02: Extras y complementos
                const Text(
                  'Complementos y Extras de Cocina',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ..._availableExtras.map((extra) {
                  final checked = _selectedExtras.contains(extra);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(extra),
                    value: checked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedExtras.add(extra);
                        } else {
                          _selectedExtras.remove(extra);
                        }
                      });
                    },
                  );
                }),
                const Divider(height: 28),

                // RF-02: Notas de cocina
                const Text(
                  'Notas para Cocina (KDS)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Ej. "Sin cebolla", "Salsa aparte", "Poca sal"',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: dish.isAvailable ? _addToCart : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(
                      'Agregar • \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

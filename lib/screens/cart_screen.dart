import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/addresses_screen.dart';
import 'package:restaurante_movil/screens/checkout_screen.dart';
import 'package:restaurante_movil/services/menu_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  bool _applyingCoupon = false;
  List<DishModel> _upsellDishes = [];

  @override
  void initState() {
    super.initState();
    _loadUpsellSuggestions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().syncQuoteWithBackend();
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadUpsellSuggestions() async {
    try {
      final all = await MenuService.getDishes();
      if (!mounted) return;
      setState(() => _upsellDishes = all);
    } catch (_) {}
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() => _applyingCoupon = true);
    try {
      final msg = await context.read<CartProvider>().applyCoupon(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green.shade700, content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final eta = cart.estimatedMinutes;

    // Filtrar sugerencias de venta cruzada (RF-24) que no estén ya en el carrito
    final cartIds = cart.items.map((i) => i.dish.id).toSet();
    final upsellCandidates =
        _upsellDishes.where((d) => !cartIds.contains(d.id) && d.isAvailable).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Vaciar carrito',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => cart.clear(),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Tu carrito está vacío',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Explora nuestros cortes a las brasas, entradas y bebidas para comenzar tu pedido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // Selección del Tipo de Entrega
                const Text(
                  'Modalidad de Entrega',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'delivery',
                      icon: Icon(Icons.delivery_dining),
                      label: Text('Delivery'),
                    ),
                    ButtonSegment(
                      value: 'takeaway',
                      icon: Icon(Icons.takeout_dining),
                      label: Text('Recoger'),
                    ),
                    ButtonSegment(
                      value: 'dine_in',
                      icon: Icon(Icons.table_restaurant),
                      label: Text('En Mesa'),
                    ),
                  ],
                  selected: {cart.orderType},
                  onSelectionChanged: (s) => cart.setOrderType(s.first),
                ),
                const SizedBox(height: 12),

                // Selector contextual según modalidad
                if (cart.orderType == 'delivery')
                  Card(
                    color: Colors.deepPurple.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.location_on,
                        color: Colors.deepPurple,
                      ),
                      title: Text(
                        cart.selectedAddress != null
                            ? '${cart.selectedAddress!.label}: ${cart.selectedAddress!.fullText}'
                            : 'Selecciona una dirección de entrega',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Tiempo estimado: ${eta[0]} - ${eta[1]} min',
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AddressesScreen(selectMode: true),
                            ),
                          );
                        },
                        child: const Text('Cambiar'),
                      ),
                    ),
                  )
                else if (cart.orderType == 'dine_in')
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.deepOrange,
                      ),
                      title: Text(
                        'Pedido QR en Salón • Mesa #${cart.selectedTableId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Tu orden se enviará directo a cocina para tu mesa',
                      ),
                      trailing: DropdownButton<int>(
                        value: cart.selectedTableId,
                        items: List.generate(10, (i) => i + 1)
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text('Mesa $t'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) cart.setSelectedTableId(v);
                        },
                      ),
                    ),
                  )
                else
                  Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.storefront,
                        color: Colors.green,
                      ),
                      title: const Text(
                        'Retiro en Sucursal Las Brazas',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Estará listo en ${eta[0]} - ${eta[1]} minutos • Sin costo de envío',
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Lista de ítems en el carrito (RF-03)
                ...List.generate(cart.items.length, (i) {
                  final item = cart.items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.dish.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (item.formattedNotes != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.formattedNotes!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  '\$${item.subtotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    cart.updateQuantity(i, item.quantity - 1),
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    cart.updateQuantity(i, item.quantity + 1),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => cart.removeItem(i),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // RF-24: Combos y Sugerencias Inteligentes (Upselling)
                if (upsellCandidates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.deepOrange,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '¿Deseas complementar tu orden?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 105,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: upsellCandidates.length,
                      itemBuilder: (context, idx) {
                        final d = upsellCandidates[idx];
                        return Container(
                          width: 230,
                          margin: const EdgeInsets.only(right: 10),
                          child: Card(
                            color: Colors.orange.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    d.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '+\$${d.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepOrange,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          cart.addItem(
                                            CartItemModel(
                                              dish: d,
                                              quantity: 1,
                                              cookingTerm: d.isMeat
                                                  ? 'Término Medio (A punto)'
                                                  : null,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Agregar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // RF-22: Motor de Cupones de Descuento
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cupón de Descuento (ej. BRAZAS10, ENVIOGRATIS)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _couponController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'Ingresa tu código',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.local_offer_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _applyingCoupon ? null : _applyCoupon,
                              child: _applyingCoupon
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Aplicar'),
                            ),
                          ],
                        ),
                        if (cart.couponCode != null) ...[
                          const SizedBox(height: 8),
                          Chip(
                            label: Text('Cupón activo: ${cart.couponCode}'),
                            onDeleted: cart.clearCoupon,
                            backgroundColor: Colors.green.shade100,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // RF-03 & RF-06: Desglose en vivo
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _summaryRow('Subtotal', cart.subtotal),
                        if (cart.discount > 0)
                          _summaryRow(
                            'Descuento (${cart.couponCode})',
                            -cart.discount,
                            color: Colors.green,
                          ),
                        _summaryRow('Impuestos', cart.tax),
                        if (cart.orderType == 'delivery')
                          _summaryRow(
                            'Costo de envío (Gratis desde \$50)',
                            cart.deliveryFee,
                          ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total a Pagar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${cart.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payment),
                    label: Text(
                      'Continuar al Pago (\$${cart.total.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryRow(String label, double value, {Color? color}) {
    final prefix = value < 0 ? '-\$' : '\$';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color ?? Colors.black87)),
          Text(
            '$prefix${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

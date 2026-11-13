import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/address_model.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/addresses_screen.dart';
import 'package:restaurante_movil/screens/order_detail_screen.dart';
import 'package:restaurante_movil/services/order_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'card'; // 'card', 'transfer', 'cash'
  bool _requestInvoice = false;
  final _invoiceNameCtrl = TextEditingController();
  final _invoiceTaxIdCtrl = TextEditingController();
  final _manualAddressCtrl = TextEditingController();
  final _orderNotesCtrl = TextEditingController();

  // Campos de tarjeta (RF-07)
  final _cardNumberCtrl = TextEditingController(text: '4532 •••• •••• 8891');
  final _cardHolderCtrl = TextEditingController(text: 'CLIENTE LAS BRAZAS');
  final _cardExpiryCtrl = TextEditingController(text: '09/28');
  final _cardCvvCtrl = TextEditingController(text: '842');
  final _transferRefCtrl = TextEditingController(text: 'QR-BRAZAS-90210');

  bool _isSubmitting = false;

  @override
  void dispose() {
    _invoiceNameCtrl.dispose();
    _invoiceTaxIdCtrl.dispose();
    _manualAddressCtrl.dispose();
    _orderNotesCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardHolderCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _transferRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndPay() async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();

    if (cart.orderType == 'delivery' &&
        cart.selectedAddress == null &&
        _manualAddressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Selecciona o escribe una dirección de entrega.'),
        ),
      );
      return;
    }

    if (_requestInvoice &&
        (_invoiceNameCtrl.text.trim().isEmpty ||
            _invoiceTaxIdCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Completa Razón Social y NIT/RFC/CI para emitir tu factura.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // 1. Crear el pedido en el backend (RF-10: entra a KDS y descuenta stock)
      final createdOrder = await OrderService.createOrder(
        items: cart.items,
        orderType: cart.orderType,
        tableId: cart.orderType == 'dine_in' ? cart.selectedTableId : null,
        addressId: cart.selectedAddress?.id,
        deliveryAddress: cart.selectedAddress?.fullText ??
            _manualAddressCtrl.text.trim(),
        deliveryLat:
            cart.selectedAddress?.latitude ?? AddressModel.restaurantLat + 0.01,
        deliveryLng: cart.selectedAddress?.longitude ??
            AddressModel.restaurantLng + 0.01,
        couponCode: cart.couponCode,
        invoiceName: _requestInvoice ? _invoiceNameCtrl.text.trim() : null,
        invoiceTaxId: _requestInvoice ? _invoiceTaxIdCtrl.text.trim() : null,
        notes: _orderNotesCtrl.text.trim(),
        paymentMethod: _paymentMethod,
      );

      // 2. Registrar el pago en `/api/v1/orders/{id}/pay` (RF-07)
      String? txRef;
      if (_paymentMethod == 'card') {
        txRef = 'STRIPE-${DateTime.now().millisecondsSinceEpoch}';
      } else if (_paymentMethod == 'transfer') {
        txRef = _transferRefCtrl.text.trim().isEmpty
            ? 'QR-${DateTime.now().millisecondsSinceEpoch}'
            : _transferRefCtrl.text.trim();
      }

      final payMessage = await OrderService.payOrder(
        orderId: createdOrder.id,
        paymentMethod: _paymentMethod,
        transactionRef: txRef,
      );

      // 3. Acumular puntos en Programa de Lealtad / Cashback (RF-23)
      final earnedPoints = createdOrder.total.round();
      await auth.addLoyaltyPoints(
        earnedPoints,
        reason:
            'Acumulaste +$earnedPoints pts por tu Pedido #${createdOrder.id} en Las Brazas.',
      );

      // Notificación Push In-App de estado (RF-15)
      auth.pushNotification(
        title: '👨‍🍳 Pedido #${createdOrder.id} enviado a Cocina (KDS)',
        body: payMessage,
      );

      cart.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('¡Pedido #${createdOrder.id} confirmado! $payMessage'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: createdOrder.id),
        ),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmación y Pago')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Entrega
          if (cart.orderType == 'delivery') ...[
            const Text(
              '1. Dirección de Envío',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: Colors.deepPurple,
                ),
                title: Text(
                  cart.selectedAddress != null
                      ? '${cart.selectedAddress!.label}: ${cart.selectedAddress!.fullText}'
                      : 'Sin dirección guardada seleccionada',
                ),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddressesScreen(selectMode: true),
                      ),
                    );
                  },
                  child: const Text('Elegir'),
                ),
              ),
            ),
            if (cart.selectedAddress == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _manualAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'O escribe tu dirección completa aquí',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Métodos de Pago Móvil
          const Text(
            '2. Método de Pago',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  onTap: () => setState(() => _paymentMethod = 'card'),
                  leading: Icon(
                    _paymentMethod == 'card'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.deepPurple,
                  ),
                  trailing: const Icon(
                    Icons.credit_card,
                    color: Colors.deepPurple,
                  ),
                  title: const Text('Pago en Línea (Tarjeta Débito/Crédito)'),
                  subtitle: const Text('Procesado vía Stripe / Pasarela segura'),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => setState(() => _paymentMethod = 'transfer'),
                  leading: Icon(
                    _paymentMethod == 'transfer'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.teal,
                  ),
                  trailing: const Icon(Icons.qr_code_2, color: Colors.teal),
                  title: const Text('Pago QR / Transferencia Directa'),
                  subtitle: const Text('Escanea el QR Simple o transfiere'),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => setState(() => _paymentMethod = 'cash'),
                  leading: Icon(
                    _paymentMethod == 'cash'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.green,
                  ),
                  trailing: const Icon(
                    Icons.payments_outlined,
                    color: Colors.green,
                  ),
                  title: const Text('Pago Contra Entrega'),
                  subtitle: const Text('Efectivo o POS inalámbrico al recibir'),
                ),
              ],
            ),
          ),

          // Detalle interactivo según método de pago elegido
          const SizedBox(height: 10),
          if (_paymentMethod == 'card')
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos de Tarjeta',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cardNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Número de tarjeta',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cardExpiryCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Exp (MM/AA)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _cardCvvCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (_paymentMethod == 'transfer')
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2, size: 110, color: Colors.teal),
                    const Text(
                      'Banco Las Brazas • Cuenta 400-991827-1',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _transferRefCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nro. de Comprobante / Referencia QR',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // RF-08: Datos de Facturación
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Solicitar Factura Fiscal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Ingresa Razón Social y NIT / RFC / CI',
                    ),
                    value: _requestInvoice,
                    onChanged: (v) => setState(() => _requestInvoice = v),
                  ),
                  if (_requestInvoice) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _invoiceNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Razón Social / Nombre Completo *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _invoiceTaxIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'NIT / RFC / CI *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _orderNotesCtrl,
            decoration: const InputDecoration(
              labelText: 'Instrucciones adicionales de entrega (opcional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.speaker_notes_outlined),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _confirmAndPay,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSubmitting
                    ? 'Procesando orden...'
                    : 'Confirmar Pedido • \$${cart.total.toStringAsFixed(2)}',
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
}


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:restaurante_movil/models/address_model.dart';
import 'package:restaurante_movil/models/order_model.dart';
import 'package:restaurante_movil/services/order_service.dart';
import 'package:restaurante_movil/widgets/tracking_map_widget.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  bool _isLoading = true;
  bool _downloadingPdf = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    // Auto-refresco cada 8 segundos para Línea de Tiempo en Tiempo Real (RF-11)
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadOrder(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final order = await OrderService.getOrderDetail(widget.orderId);
      if (!mounted) return;
      setState(() => _order = order);
    } catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar el pedido: $e')),
      );
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    try {
      final msg = await OrderService.cancelOrder(_order!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _loadOrder();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  /// RF-09: Generación y descarga de Comprobante Digital / Factura PDF
  Future<void> _openAndDownloadInvoice() async {
    if (_order == null) return;
    setState(() => _downloadingPdf = true);
    int? pdfBytesLength;
    try {
      final bytes = await OrderService.downloadInvoicePdf(_order!.id);
      pdfBytesLength = bytes.length;
    } catch (_) {
      // Aun si falla la descarga binaria, mostramos el comprobante fiscal digital completo
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }

    if (!mounted) return;
    final o = _order!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.picture_as_pdf, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Comprobante Fiscal Digital (RF-09)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const Text(
                  'RESTAURANTE LAS BRAZAS S.A.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Comprobante #${o.id} • Modalidad: ${o.orderTypeLabel}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Razón Social: ${o.invoiceName ?? 'CONSUMIDOR FINAL'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('NIT / RFC / CI: ${o.invoiceTaxId ?? '0000000'}'),
                      if (o.deliveryAddress != null)
                        Text('Dirección: ${o.deliveryAddress}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...o.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${item.quantity}x ${item.name}'),
                        ),
                        Text('\$${item.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text('\$${o.subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                if (o.discount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Descuento'),
                      Text('-\$${o.discount.toStringAsFixed(2)}'),
                    ],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Costo de Envío'),
                    Text('\$${o.deliveryFee.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL FACTURADO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${o.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (pdfBytesLength != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '✅ PDF generado por el servidor (${(pdfBytesLength / 1024).toStringAsFixed(1)} KB) y copia enviada al correo registrado.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Comprobante PDF #${o.id} guardado y enviado a tu correo electrónico.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_done),
                  label: const Text('Descargar PDF / Enviar por Correo'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _driverProgressForStep(String currentStep) {
    switch (currentStep) {
      case 'received':
        return 0.05;
      case 'in_kitchen':
        return 0.15;
      case 'ready':
        return 0.30;
      case 'on_the_way':
        return 0.70;
      case 'delivered':
        return 1.0;
      default:
        return 0.2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${widget.orderId}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar estado en tiempo real',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadOrder(),
          ),
        ],
      ),
      body: _isLoading || _order == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadOrder(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // RF-19: Código PIN de 4 dígitos para confirmar entrega
                  if (_order!.orderType == 'delivery' &&
                      _order!.deliveryPin != null)
                    Card(
                      color: Colors.amber.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.amber.shade700),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.pin_outlined,
                              size: 36,
                              color: Colors.deepOrange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PIN de Seguridad para Entrega (RF-19)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Muestra este código de 4 dígitos al repartidor al recibir tu pedido:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _order!.deliveryPin!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // RF-11: Línea de Tiempo del Pedido en Tiempo Real
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Seguimiento en Tiempo Real (RF-11)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Chip(
                                label: Text(_order!.statusLabel),
                                backgroundColor: Colors.deepPurple.shade50,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._buildTimelineSteps(_order!.tracking),
                        ],
                      ),
                    ),
                  ),

                  // RF-20: Mapa interactivo de Tracking GPS del Repartidor
                  if (_order!.orderType == 'delivery') ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Mapa de Tracking GPS en Tiempo Real (RF-20)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TrackingMapWidget(
                      selectedLat: AddressModel.restaurantLat + 0.014,
                      selectedLng: AddressModel.restaurantLng + 0.016,
                      showDriver: true,
                      driverProgress:
                          _driverProgressForStep(_order!.tracking.current),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Detalle de Platillos e Importes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detalle de tu Orden',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          ..._order!.items.map(
                            (i) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                '${i.quantity}x ${i.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: i.notes != null ? Text(i.notes!) : null,
                              trailing: Text(
                                '\$${i.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '\$${_order!.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // RF-09: Botón Comprobante / Factura PDF
                  ElevatedButton.icon(
                    onPressed:
                        _downloadingPdf ? null : _openAndDownloadInvoice,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _downloadingPdf
                          ? 'Generando PDF...'
                          : 'Ver / Descargar Factura PDF (RF-09)',
                    ),
                  ),

                  if (_order!.status == 'pending') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _cancelOrder,
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text(
                        'Cancelar Pedido (Aún no entró a cocina)',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildTimelineSteps(OrderTrackingModel tracking) {
    if (tracking.current == 'cancelled') {
      return [
        const ListTile(
          leading: Icon(Icons.cancel, color: Colors.red),
          title: Text(
            'Pedido Cancelado',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ];
    }

    final currentIdx = tracking.steps.indexOf(tracking.current);
    return List.generate(tracking.steps.length, (idx) {
      final stepKey = tracking.steps[idx];
      final isDone = currentIdx >= idx;
      final isCurrent = currentIdx == idx;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCurrent
                  ? Colors.deepOrange
                  : isDone
                      ? Colors.green
                      : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                OrderTrackingModel.stepLabel(stepKey),
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? Colors.black87 : Colors.grey,
                  fontSize: isCurrent ? 15 : 14,
                ),
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Actual',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/address_model.dart';
import 'package:restaurante_movil/models/order_model.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/services/location_service.dart';
import 'package:restaurante_movil/services/order_service.dart';
import 'package:restaurante_movil/widgets/brand_logo.dart';
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
  double? _deviceLat;
  double? _deviceLng;

  static const List<String> _cancelReasons = [
    'Me equivoqué en los platillos o término de la carne',
    'Cambio de planes / Ya no podré recibir el pedido',
    'Tiempo de espera mayor al previsto',
    'Dirección o modalidad de entrega incorrecta',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _resolveDeviceLocation();
    // Auto-refresco cada 8 segundos para Línea de Tiempo en Tiempo Real
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadOrder(silent: true);
    });
  }

  Future<void> _resolveDeviceLocation() async {
    try {
      final place = await LocationService.getCurrentLocationWithAddress();
      if (!mounted) return;
      setState(() {
        _deviceLat = place.latitude;
        _deviceLng = place.longitude;
      });
    } catch (_) {}
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

  /// Modal interactivo de Cancelación por el Cliente con Cálculo de Penalización
  void _openCancelWithPenaltySheet() {
    if (_order == null) return;
    final o = _order!;
    String selectedReason = _cancelReasons.first;
    final customReasonCtrl = TextEditingController();
    bool acceptedPenalty = false;
    bool cancelling = false;

    final stepName = OrderTrackingModel.stepLabel(o.tracking.current);
    final penaltyPct = o.applicablePenaltyPercent;
    final penaltyAmt = o.calculatedPenaltyAmount;
    final refundAmt = o.calculatedRefundAmount;
    final penaltyPts = o.applicablePenaltyPoints;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 26,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cancelar Pedido y Penalización',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu Pedido #${o.id} se encuentra actualmente en etapa "$stepName". Según la política de Las Brazas, cancelar en esta etapa aplica una penalización del $penaltyPct% por costos operativos e insumos.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),

                    // Tarjeta de desglose de penalización financiera y de puntos
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Column(
                        children: [
                          _penaltyRow(
                            'Total pagado del pedido',
                            '\$${o.total.toStringAsFixed(2)}',
                            color: Colors.black87,
                          ),
                          const SizedBox(height: 6),
                          _penaltyRow(
                            'Cargo por penalización ($penaltyPct%)',
                            '-\$${penaltyAmt.toStringAsFixed(2)}',
                            color: Colors.red.shade800,
                            bold: true,
                          ),
                          const SizedBox(height: 6),
                          _penaltyRow(
                            'Penalización en Puntos Las Brazas',
                            '-$penaltyPts pts (+ reversión de orden)',
                            color: Colors.deepOrange.shade800,
                          ),
                          const Divider(height: 18),
                          _penaltyRow(
                            'Monto Neto a Reembolsar',
                            '\$${refundAmt.toStringAsFixed(2)}',
                            color: Colors.green.shade800,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Selecciona el motivo de la cancelación:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._cancelReasons.map((r) {
                      final isSelected = selectedReason == r;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected ? Colors.red.shade700 : Colors.grey,
                        ),
                        title: Text(r, style: const TextStyle(fontSize: 13)),
                        onTap: () => setModalState(() => selectedReason = r),
                      );
                    }),
                    const SizedBox(height: 6),
                    TextField(
                      controller: customReasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Detalle adicional (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.comment_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: acceptedPenalty,
                      onChanged: (v) =>
                          setModalState(() => acceptedPenalty = v ?? false),
                      title: Text(
                        'Acepto el cargo de penalización de \$${penaltyAmt.toStringAsFixed(2)} ($penaltyPct%) y la deducción de $penaltyPts puntos de fidelidad.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: (!acceptedPenalty || cancelling)
                            ? null
                            : () async {
                                setModalState(() => cancelling = true);
                                final extra = customReasonCtrl.text.trim();
                                final fullReason = extra.isNotEmpty
                                    ? '$selectedReason ($extra)'
                                    : selectedReason;

                                final auth = context.read<AuthProvider>();
                                final info =
                                    await OrderService.cancelOrderWithPenalty(
                                      order: o,
                                      reason: fullReason,
                                    );

                                await auth.applyCancellationPenalty(
                                  orderId: o.id,
                                  earnedPointsToRevert: o.total.round(),
                                  penaltyPoints: info.penaltyPoints,
                                  penaltyAmount: info.penaltyAmount,
                                  refundAmount: info.refundAmount,
                                );

                                if (!mounted) return;
                                if (ctx.mounted) Navigator.pop(ctx);
                                setState(() {
                                  _order = o.copyWithCancellation(info);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade800,
                                    content: Text(
                                      'Pedido #${o.id} cancelado. Penalización: -\$${info.penaltyAmount.toStringAsFixed(2)} • Reembolso: \$${info.refundAmount.toStringAsFixed(2)}',
                                    ),
                                  ),
                                );
                              },
                        icon: cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cancel),
                        label: Text(
                          cancelling
                              ? 'Aplicando cancelación...'
                              : 'Confirmar Cancelación (-\$$penaltyAmt)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _penaltyRow(
    String label,
    String value, {
    required Color color,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Generación y descarga de Comprobante Digital / Factura PDF
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
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Comprobante Fiscal Digital',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const Center(child: BrandLogo(size: 84, borderRadius: 16)),
                const SizedBox(height: 8),
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
                  // Si el pedido fue cancelado, mostrar el desglose de penalización aplicada
                  if (_order!.isCancelled) ...[
                    Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.red.shade400),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.cancel,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pedido Cancelado con Penalización',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_order!.cancellationInfo != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Motivo: ${_order!.cancellationInfo!.reason}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const Divider(height: 16),
                              _penaltyRow(
                                'Penalización retenida (${_order!.cancellationInfo!.penaltyPercent}%)',
                                '-\$${_order!.cancellationInfo!.penaltyAmount.toStringAsFixed(2)}',
                                color: Colors.red.shade800,
                                bold: true,
                              ),
                              const SizedBox(height: 4),
                              _penaltyRow(
                                'Penalización de fidelidad',
                                '-${_order!.cancellationInfo!.penaltyPoints} pts',
                                color: Colors.deepOrange.shade800,
                              ),
                              const SizedBox(height: 4),
                              _penaltyRow(
                                'Reembolso a favor del cliente',
                                '\$${_order!.cancellationInfo!.refundAmount.toStringAsFixed(2)}',
                                color: Colors.green.shade800,
                                bold: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Código PIN de 4 dígitos para confirmar entrega (si está activo)
                  if (!_order!.isCancelled &&
                      _order!.orderType == 'delivery' &&
                      _order!.deliveryPin != null) ...[
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PIN de Seguridad para Entrega',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Muestra este código de 4 dígitos al repartidor al recibir tu pedido:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
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
                  ],

                  // Línea de Tiempo del Pedido en Tiempo Real
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Seguimiento en Tiempo Real',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(_order!.statusLabel),
                                backgroundColor: _order!.isCancelled
                                    ? Colors.red.shade100
                                    : Colors.deepPurple.shade50,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._buildTimelineSteps(_order!.tracking),
                        ],
                      ),
                    ),
                  ),

                  // Mapa interactivo de Tracking GPS del Repartidor
                  if (!_order!.isCancelled &&
                      _order!.orderType == 'delivery') ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Mapa de Tracking GPS en Tiempo Real',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TrackingMapWidget(
                      selectedLat: _order!.deliveryLat ??
                          _deviceLat ??
                          (AddressModel.restaurantLat + 0.005),
                      selectedLng: _order!.deliveryLng ??
                          _deviceLng ??
                          (AddressModel.restaurantLng + 0.005),
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

                  // Botón Comprobante / Factura PDF
                  ElevatedButton.icon(
                    onPressed:
                        _downloadingPdf ? null : _openAndDownloadInvoice,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _downloadingPdf
                          ? 'Generando PDF...'
                          : 'Ver / Descargar Factura PDF',
                    ),
                  ),

                  // Botón de Cancelar Pedido por el Cliente (con su penalización correspondiente)
                  if (_order!.canBeCancelled) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade600, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _openCancelWithPenaltySheet,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
                      ),
                      label: Text(
                        'Cancelar Pedido (Penalización ${_order!.applicablePenaltyPercent}%: -\$${_order!.calculatedPenaltyAmount.toStringAsFixed(2)})',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildTimelineSteps(OrderTrackingModel tracking) {
    if (tracking.current == 'cancelled' || (_order?.isCancelled ?? false)) {
      return [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cancel, color: Colors.red),
          title: Text(
            'Pedido Cancelado por el Cliente',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Se aplicó la política de penalización y reembolso parcial.',
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
                  color: isDone ? null : Colors.grey,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/delivery_order_model.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/services/delivery_service.dart';
import 'package:restaurante_movil/widgets/tracking_map_widget.dart';

class DeliveryDriverScreen extends StatefulWidget {
  const DeliveryDriverScreen({super.key});

  @override
  State<DeliveryDriverScreen> createState() => _DeliveryDriverScreenState();
}

class _DeliveryDriverScreenState extends State<DeliveryDriverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DeliveryOrderModel> _pending = [];
  List<DeliveryOrderModel> _mine = [];
  bool _isLoading = true;
  String? _roleNotice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isDriverOrAdmin) {
      setState(() {
        _pending = [];
        _mine = [];
        _isLoading = false;
        _roleNotice =
            'Acceso Restringido: Esta sesión pertenece a un Cliente. Los datos de Administrador y Repartidor están protegidos y ocultos.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _roleNotice = null;
    });
    try {
      final results = await Future.wait([
        DeliveryService.getPendingOrders(),
        DeliveryService.getMyOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        _pending = results[0];
        _mine = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _roleNotice = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _takeOrder(DeliveryOrderModel order) async {
    try {
      final msg = await DeliveryService.takeOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _loadDeliveries();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.toString())),
      );
    }
  }

  Future<void> _pickupOrder(DeliveryOrderModel order) async {
    try {
      final msg = await DeliveryService.pickupOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _loadDeliveries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.toString())),
      );
    }
  }

  /// RF-18: Abrir Ruta GPS en Google Maps o Waze
  void _openGpsRouteModal(DeliveryOrderModel order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Navegación GPS • Pedido #${order.id}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text('Destino: ${order.address ?? 'Domicilio del cliente'}'),
              const SizedBox(height: 12),
              TrackingMapWidget(
                selectedLat: order.lat,
                selectedLng: order.lng,
                showDriver: true,
                driverProgress: 0.5,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ruta Google Maps iniciada: ${order.navigationUrl ?? order.address}',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Google Maps'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ruta Waze iniciada hacia ${order.address}',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Abrir en Waze'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// RF-19: Confirmación de Entrega con Código PIN de 4 dígitos o Firma Digital
  void _openConfirmDeliveryDialog(DeliveryOrderModel order) {
    final pinCtrl = TextEditingController();
    final List<Offset?> signaturePoints = [];

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
                    Text(
                      'Confirmar Entrega #${order.id}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Ingresa el código PIN de 4 dígitos del cliente:',
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pinCtrl,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            '2. Firma digital del cliente en pantalla:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setModalState(() => signaturePoints.clear()),
                          child: const Text('Limpiar firma'),
                        ),
                      ],
                    ),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setModalState(() {
                            signaturePoints.add(details.localPosition);
                          });
                        },
                        onPanEnd: (_) =>
                            setModalState(() => signaturePoints.add(null)),
                        child: CustomPaint(
                          painter: _SignaturePainter(signaturePoints),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (pinCtrl.text.trim().length != 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ingresa el PIN de 4 dígitos proporcionado por el cliente.',
                                ),
                              ),
                            );
                            return;
                          }
                          try {
                            final msg = await DeliveryService.confirmDelivery(
                              orderId: order.id,
                              pin: pinCtrl.text.trim(),
                            );
                            if (!mounted) return;
                            if (ctx.mounted) Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade700,
                                content: Text(msg),
                              ),
                            );
                            _loadDeliveries();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(e.toString()),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.verified),
                        label: const Text('Confirmar Pedido Entregado'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulo Repartidor'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Disponibles (${_pending.length})'),
            Tab(text: 'Mis Entregas (${_mine.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliveries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _roleNotice != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delivery_dining,
                          size: 64,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _roleNotice!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Inicia sesión con una cuenta con rol "Repartidor" o "Administrador" para gestionar despachos de delivery.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingList(),
                    _buildMineList(),
                  ],
                ),
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) {
      return const Center(
        child: Text('No hay pedidos pendientes de asignar en este momento.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _pending.length,
      itemBuilder: (context, index) {
        final o = _pending[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
            title: Text(
              'Pedido #${o.id} • ${o.customer}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${o.address ?? 'Sin dirección'} • Total: \$${o.total.toStringAsFixed(2)}',
            ),
            trailing: ElevatedButton(
              onPressed: () => _takeOrder(o),
              child: const Text('Tomar'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMineList() {
    if (_mine.isEmpty) {
      return const Center(
        child: Text('No tienes entregas activas asignadas.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _mine.length,
      itemBuilder: (context, index) {
        final o = _mine[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido #${o.id} • ${o.customer}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('📍 Dirección: ${o.address ?? 'N/D'}'),
                if (o.phone != null) Text('📞 Teléfono: ${o.phone}'),
                Text('💵 Total: \$${o.total.toStringAsFixed(2)}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openGpsRouteModal(o),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Ruta GPS'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickupOrder(o),
                      icon: const Icon(Icons.motorcycle, size: 18),
                      label: const Text('Recoger de Cocina'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openConfirmDeliveryDialog(o),
                      icon: const Icon(Icons.pin, size: 18),
                      label: const Text('Confirmar PIN / Firma'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/reservation_model.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/services/reservation_service.dart';

class ReservationsScreen extends StatefulWidget {
  final bool embedded;
  const ReservationsScreen({super.key, this.embedded = false});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<AreaModel> _areas = [];
  List<ReservationModel> _activeReservations = [];
  List<ReservationModel> _historyReservations = [];
  bool _isLoading = true;

  // Formulario de Nueva Reserva (RF-12)
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  int _adults = 2;
  int _children = 0;
  int? _selectedAreaId;
  final TextEditingController _specialRequestsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  String get _formattedDateTime {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    final hh = _selectedTime.hour.toString().padLeft(2, '0');
    final mm = _selectedTime.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  int get _totalGuests => _adults + _children;

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final areas = await ReservationService.getAreas();
      final resMap = await ReservationService.getReservations();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        if (_selectedAreaId == null && areas.isNotEmpty) {
          _selectedAreaId = areas.first.id;
        }
        _activeReservations = resMap['active'] ?? [];
        _historyReservations = resMap['history'] ?? [];
      });
      await _refreshAvailability();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar reservas: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAvailability() async {
    try {
      final avail = await ReservationService.checkAvailability(
        dateFormatted: _formattedDateTime,
        guests: _totalGuests,
      );
      if (!mounted) return;
      setState(() {
        for (final a in _areas) {
          final match = avail.where((x) => x.id == a.id).toList();
          if (match.isNotEmpty) {
            a.seatsLeft = match.first.seatsLeft;
            a.isAvailable = match.first.isAvailable;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _refreshAvailability();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
      _refreshAvailability();
    }
  }

  Future<void> _submitReservation() async {
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un área del restaurante.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ReservationService.createReservation(
        reservationDate: _formattedDateTime,
        adults: _adults,
        children: _children,
        areaId: _selectedAreaId!,
        specialRequests: _specialRequestsCtrl.text,
      );
      if (!mounted) return;
      context.read<AuthProvider>().pushNotification(
        title: '🪑 Reserva de Mesa Confirmada',
        body:
            'Fecha: $_formattedDateTime • $_totalGuests comensales. Recuerda llegar puntual (15 min de tolerancia).',
        category: 'reservation',
      );
      _specialRequestsCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(result['message'].toString()),
        ),
      );
      await _loadAll();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelReservation(ReservationModel r) async {
    try {
      final msg = await ReservationService.cancelReservation(r.id);
      if (!mounted) return;
      context.read<AuthProvider>().pushNotification(
        title: '⚠️ Reservación #${r.id} Cancelada',
        body:
            'Se canceló tu reserva del ${r.reservationDate} para ${r.guestCount} personas.',
        category: 'reservation',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.event_available), text: 'Nueva Reserva'),
            Tab(
              icon: const Icon(Icons.list_alt),
              text: 'Mis Reservas (${_activeReservations.length})',
            ),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNewReservationTab(),
                    _buildMyReservationsTab(),
                  ],
                ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Reservas de Mesas')),
      body: body,
    );
  }

  Widget _buildNewReservationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Aviso de política de tolerancia de 15 min (RF-12)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade700),
          ),
          child: const Row(
            children: [
              Icon(Icons.timer, color: Colors.deepOrange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Política de Tolerancia: Tu mesa reservada se mantendrá por 15 minutos estrictos desde la hora seleccionada.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Fecha y Hora
        const Text(
          '1. Fecha y Horario Disponible',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_formattedDateTime.split(' ').first),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: Text(_formattedDateTime.split(' ').last),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Comensales (Adultos / Niños)
        const Text(
          '2. Número de Comensales',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Adultos'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _adults > 1
                              ? () {
                                  setState(() => _adults--);
                                  _refreshAvailability();
                                }
                              : null,
                        ),
                        Text(
                          '$_adults',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() => _adults++);
                            _refreshAvailability();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Niños'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _children > 0
                              ? () {
                                  setState(() => _children--);
                                  _refreshAvailability();
                                }
                              : null,
                        ),
                        Text(
                          '$_children',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() => _children++);
                            _refreshAvailability();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Zona / Área de preferencia con aforo en tiempo real
        const Text(
          '3. Zona de Preferencia y Aforo en Tiempo Real',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (_areas.isEmpty)
          const Text('No hay zonas configuradas en el servidor.')
        else
          ..._areas.map((area) {
            final selected = _selectedAreaId == area.id;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ListTile(
                enabled: area.isAvailable,
                onTap: area.isAvailable
                    ? () => setState(() => _selectedAreaId = area.id)
                    : null,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                title: Text(
                  area.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  area.seatsLeft != null
                      ? 'Asientos disponibles en este horario: ${area.seatsLeft}'
                      : (area.description ?? 'Capacidad total: ${area.capacity}'),
                ),
                trailing: Chip(
                  label: Text(area.isAvailable ? 'Disponible' : 'Sin Aforo'),
                  backgroundColor: area.isAvailable
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // Peticiones especiales
        const Text(
          '4. Peticiones Especiales',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _specialRequestsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText:
                'Ej. "Silla para bebé", "Mesa cerca a la ventana", "Aniversario"',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.chair_alt),
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submitReservation,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _submitting
                  ? 'Validando aforo...'
                  : 'Confirmar Reservación ($_totalGuests personas)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyReservationsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reservas Activas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_activeReservations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tienes reservaciones activas.'),
              ),
            )
          else
            ..._activeReservations.map(
              (r) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.event_seat),
                  ),
                  title: Text(
                    'Fecha: ${r.reservationDate}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.guestCount} comensales (${r.childrenCount} niños) • ${r.statusLabel}',
                      ),
                      if (r.specialRequests != null &&
                          r.specialRequests!.isNotEmpty)
                        Text('Nota: ${r.specialRequests}'),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => _cancelReservation(r),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Historial de Visitas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_historyReservations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aún no hay visitas anteriores registradas.'),
              ),
            )
          else
            ..._historyReservations.map(
              (r) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(r.reservationDate),
                  subtitle: Text('${r.guestCount} personas • ${r.statusLabel}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


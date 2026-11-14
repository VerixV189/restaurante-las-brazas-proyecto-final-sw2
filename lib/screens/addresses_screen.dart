import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/address_model.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/services/customer_service.dart';
import 'package:restaurante_movil/services/location_service.dart';
import 'package:restaurante_movil/widgets/tracking_map_widget.dart';

class AddressesScreen extends StatefulWidget {
  final bool selectMode;
  const AddressesScreen({super.key, this.selectMode = false});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  DetectedPlace? _cachedCurrentPlace;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _warmUpDeviceLocation();
  }

  Future<void> _warmUpDeviceLocation() async {
    try {
      final place = await LocationService.getCurrentLocationWithAddress();
      if (!mounted) return;
      setState(() => _cachedCurrentPlace = place);
    } catch (_) {}
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final list = await CustomerService.getAddresses();
      if (!mounted) return;
      setState(() => _addresses = list);
      final cart = context.read<CartProvider>();
      if (cart.selectedAddress == null && list.isNotEmpty) {
        final def = list.where((a) => a.isDefault).toList();
        cart.setSelectedAddress(def.isNotEmpty ? def.first : list.first);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar direcciones: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(AddressModel addr) async {
    try {
      await CustomerService.deleteAddress(addr.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección eliminada.')),
      );
      _loadAddresses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _openAddressModal({AddressModel? existing}) {
    String label = existing?.label ?? 'Casa';
    final streetCtrl = TextEditingController(
      text: existing?.street ?? (_cachedCurrentPlace?.street ?? ''),
    );
    final numberCtrl = TextEditingController(
      text: existing?.number ?? (_cachedCurrentPlace?.number ?? ''),
    );
    final floorCtrl = TextEditingController(text: existing?.floor ?? '');
    final refCtrl = TextEditingController(
      text: existing?.reference ??
          (_cachedCurrentPlace?.zone != null
              ? 'Zona ${_cachedCurrentPlace!.zone}'
              : ''),
    );
    double lat = existing?.latitude ??
        _cachedCurrentPlace?.latitude ??
        (AddressModel.restaurantLat + 0.004);
    double lng = existing?.longitude ??
        _cachedCurrentPlace?.longitude ??
        (AddressModel.restaurantLng + 0.004);
    bool isDefault = existing?.isDefault ?? _addresses.isEmpty;
    bool saving = false;
    bool detectingGps = false;
    String? detectedSummary = _cachedCurrentPlace?.displayName;
    bool autoFetchedOnce = false;

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
            Future<void> detectGpsNow() async {
              setModalState(() => detectingGps = true);
              try {
                final place =
                    await LocationService.getCurrentLocationWithAddress();
                if (!ctx.mounted) return;
                setModalState(() {
                  lat = place.latitude;
                  lng = place.longitude;
                  detectedSummary = place.displayName;
                  if (place.street.isNotEmpty) {
                    streetCtrl.text = place.street;
                  }
                  if (place.number != null && place.number!.isNotEmpty) {
                    numberCtrl.text = place.number!;
                  }
                  if (place.zone != null &&
                      place.zone!.isNotEmpty &&
                      refCtrl.text.trim().isEmpty) {
                    refCtrl.text = 'Zona ${place.zone}';
                  }
                });
              } finally {
                if (ctx.mounted) {
                  setModalState(() => detectingGps = false);
                }
              }
            }

            if (existing == null &&
                !autoFetchedOnce &&
                _cachedCurrentPlace == null) {
              autoFetchedOnce = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) detectGpsNow();
              });
            }

            final previewAddr = AddressModel(
              id: existing?.id ?? 0,
              label: label,
              street: streetCtrl.text,
              latitude: lat,
              longitude: lng,
            );
            final distKm = previewAddr.distanceKm;
            final inZone = previewAddr.withinCoverage;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            existing == null
                                ? 'Nueva Dirección de Entrega'
                                : 'Editar Dirección',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: detectingGps ? null : detectGpsNow,
                          icon: detectingGps
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                            detectingGps ? 'Ubicando...' : 'Usar mi GPS',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Casa', 'Oficina', 'Pareja', 'Otro'].map((l) {
                        return ChoiceChip(
                          label: Text(l),
                          selected: label == l,
                          onSelected: (_) => setModalState(() => label = l),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ubicación en Mapa GPS y Cobertura en Vivo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TrackingMapWidget(
                      selectedLat: lat,
                      selectedLng: lng,
                      onSelectCoordinate: (coord) async {
                        setModalState(() {
                          lat = coord.dx;
                          lng = coord.dy;
                          detectingGps = true;
                        });
                        final place = await LocationService.reverseGeocode(
                          coord.dx,
                          coord.dy,
                        );
                        if (!ctx.mounted) return;
                        setModalState(() {
                          detectingGps = false;
                          detectedSummary = place.displayName;
                          if (place.street.isNotEmpty) {
                            streetCtrl.text = place.street;
                          }
                          if (place.number != null &&
                              place.number!.isNotEmpty) {
                            numberCtrl.text = place.number!;
                          }
                        });
                      },
                    ),
                    if (detectedSummary != null &&
                        detectedSummary!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.pin_drop_outlined,
                            size: 15,
                            color: Colors.deepOrange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              detectedSummary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: inZone
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: inZone ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            inZone ? Icons.check_circle : Icons.warning_amber,
                            color: inZone ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inZone
                                  ? 'Dentro de zona de cobertura (${distKm.toStringAsFixed(1)} km de Las Brazas)'
                                  : 'Fuera del radio de reparto (${distKm.toStringAsFixed(1)} km > ${AddressModel.maxCoverageRadiusKm.toInt()} km máx.)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: inZone
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: streetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Calle / Avenida *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.signpost_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: numberCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Número',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: floorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Piso / Dpto',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Punto de referencia (ej. Portón negro)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usar como dirección predeterminada'),
                      value: isDefault,
                      onChanged: (v) =>
                          setModalState(() => isDefault = v ?? false),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (streetCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ingresa la calle o avenida'),
                                    ),
                                  );
                                  return;
                                }
                                if (!inZone) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text(
                                        'Selecciona un punto dentro de la zona de cobertura del restaurante.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => saving = true);
                                try {
                                  final model = AddressModel(
                                    id: existing?.id ?? 0,
                                    label: label,
                                    street: streetCtrl.text.trim(),
                                    number: numberCtrl.text.trim(),
                                    floor: floorCtrl.text.trim(),
                                    reference: refCtrl.text.trim(),
                                    latitude: lat,
                                    longitude: lng,
                                    isDefault: isDefault,
                                  );
                                  final saved = existing == null
                                      ? await CustomerService.createAddress(model)
                                      : await CustomerService.updateAddress(
                                          existing.id,
                                          model,
                                        );
                                  if (!mounted) return;
                                  context
                                      .read<CartProvider>()
                                      .setSelectedAddress(saved);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadAddresses();
                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Guardar Dirección'),
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
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectMode ? 'Seleccionar Dirección' : 'Mis Direcciones',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddressModal(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nueva Dirección'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_off_outlined,
                          size: 56,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aún no tienes direcciones guardadas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Registra Casa, Oficina o Pareja con tu ubicación GPS real para tus envíos a domicilio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openAddressModal(),
                          icon: const Icon(Icons.my_location),
                          label: const Text('Detectar mi ubicación y agregar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final a = _addresses[index];
                    final isSelected = cart.selectedAddress?.id == a.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Icon(
                            a.label == 'Oficina'
                                ? Icons.business
                                : a.label == 'Pareja'
                                    ? Icons.favorite
                                    : Icons.home,
                            color: Colors.deepPurple,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              a.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (a.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Principal',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(a.fullText),
                            const SizedBox(height: 2),
                            Text(
                              'Distancia: ${a.distanceKm.toStringAsFixed(1)} km • ${a.withinCoverage ? 'Cobertura activa' : 'Fuera de zona'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: a.withinCoverage
                                    ? Colors.green.shade700
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _openAddressModal(existing: a);
                            } else if (val == 'delete') {
                              _deleteAddress(a);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                        onTap: () {
                          cart.setSelectedAddress(a);
                          if (widget.selectMode) {
                            Navigator.pop(context, a);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

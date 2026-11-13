import 'package:flutter/material.dart';
import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/services/http_client.dart';

/// Gatillo discreto/oculto para abrir la configuración de IP del backend:
/// Se activa manteniendo presionado (Long Press) o tocando 5 veces seguidas.
class HiddenBackendTrigger extends StatefulWidget {
  final Widget child;
  const HiddenBackendTrigger({super.key, required this.child});

  @override
  State<HiddenBackendTrigger> createState() => _HiddenBackendTriggerState();
}

class _HiddenBackendTriggerState extends State<HiddenBackendTrigger> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTap = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      BackendConfigSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onLongPress: () => BackendConfigSheet.show(context),
      child: widget.child,
    );
  }
}

class BackendConfigSheet extends StatefulWidget {
  const BackendConfigSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BackendConfigSheet(),
    );
  }

  @override
  State<BackendConfigSheet> createState() => _BackendConfigSheetState();
}

class _BackendConfigSheetState extends State<BackendConfigSheet> {
  late final TextEditingController _urlCtrl;
  bool _testing = false;
  String? _statusMessage;
  bool? _statusSuccess;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiConstants.baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testHealth() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
      _statusSuccess = null;
    });
    try {
      await ApiConstants.setCustomBaseUrl(_urlCtrl.text);
      _urlCtrl.text = ApiConstants.baseUrl;
      final res = await HttpClient.get(ApiConstants.health);
      if (!mounted) return;
      final status = (res is Map && res['status'] != null)
          ? res['status'].toString()
          : 'OK';
      final app = (res is Map && res['app'] != null)
          ? res['app'].toString()
          : 'Backend Laravel';
      setState(() {
        _statusSuccess = true;
        _statusMessage =
            'Conectado a ${ApiConstants.health}\nEstado: $status • $app';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusSuccess = false;
        _statusMessage = 'Fallo al conectar con ${ApiConstants.health}: $e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveAndClose() async {
    await ApiConstants.setCustomBaseUrl(_urlCtrl.text);
    if (!mounted) return;
    final applied = ApiConstants.baseUrl;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Text('Backend actualizado en caliente: $applied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewBase = ApiConstants.normalizeBaseUrl(_urlCtrl.text);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dns_outlined, color: Color(0xFFE8832A)),
                    SizedBox(width: 8),
                    Text(
                      'Configuración Oculta de Backend',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              'Cambia la IP o dominio del servidor Laravel en tiempo real sin volver a compilar la app.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'URL o IP del Servidor (o link /api/v1/health)',
                hintText: 'http://3.210.205.227',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _urlCtrl.clear();
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Health endpoint: $previewBase/api/v1/health',
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cloud_outlined, size: 16),
                  label: const Text('AWS: 3.210.205.227'),
                  onPressed: () {
                    setState(() => _urlCtrl.text = 'http://3.210.205.227');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.usb, size: 16),
                  label: const Text('USB: 127.0.0.1:8010'),
                  onPressed: () {
                    setState(() => _urlCtrl.text = 'http://127.0.0.1:8010');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android, size: 16),
                  label: const Text('Emulador: 10.0.2.2:8010'),
                  onPressed: () {
                    setState(() => _urlCtrl.text = 'http://10.0.2.2:8010');
                  },
                ),
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusSuccess == true
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _statusSuccess == true ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusSuccess == true
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color:
                          _statusSuccess == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _testHealth,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Probar /health'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAndClose,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar IP'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


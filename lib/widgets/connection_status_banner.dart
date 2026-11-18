import 'package:flutter/material.dart';
import 'package:restaurante_movil/services/offline_cache_service.dart';

/// Pequeño botón / letrerito interactivo para la barra superior (AppBar)
/// que indica en tiempo real si la PWA / App Móvil está Conectada (Online) o Desconectada (Offline).
class ConnectionStatusBadge extends StatelessWidget {
  final VoidCallback? onStatusChanged;
  const ConnectionStatusBadge({super.key, this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineCacheService.instance,
      builder: (context, _) {
        final service = OfflineCacheService.instance;
        final isOffline = service.isOffline;
        final isChecking = service.isChecking;

        final bgColor = isOffline
            ? Colors.deepOrange.shade700
            : Colors.green.shade700;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final nowOffline = await service.toggleManualOfflineMode();
                onStatusChanged?.call();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    backgroundColor: nowOffline
                        ? Colors.deepOrange.shade800
                        : Colors.green.shade800,
                    content: Text(
                      nowOffline
                          ? '📡 Modo Offline activado: usando catálogo y datos en caché local.'
                          : '🟢 Conectado en línea con el servidor Las Brazas.',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isChecking)
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        isOffline ? Icons.cloud_off : Icons.wifi,
                        size: 13,
                        color: Colors.white,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      isOffline ? 'Offline' : 'Online',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Letrerito / cinta informativa superior que aparece automáticamente
/// cuando el dispositivo está desconectado o en Modo Offline PWA.
class OfflineTopNoticeBanner extends StatelessWidget {
  final VoidCallback? onReconnected;
  const OfflineTopNoticeBanner({super.key, this.onReconnected});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineCacheService.instance,
      builder: (context, _) {
        final service = OfflineCacheService.instance;
        if (!service.isOffline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.deepOrange.shade800,
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service.isManualOffline
                      ? 'Modo Offline Activo (PWA) • Mostrando menú y datos locales'
                      : 'Sin conexión al servidor • Modo Offline con caché local activo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  final ok = await service.reconnect();
                  onReconnected?.call();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor:
                          ok ? Colors.green.shade700 : Colors.red.shade700,
                      content: Text(
                        ok
                            ? '🟢 Reconectado en línea con el servidor.'
                            : '🔴 El servidor aún no responde. Continúas en Modo Offline.',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Conectar',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

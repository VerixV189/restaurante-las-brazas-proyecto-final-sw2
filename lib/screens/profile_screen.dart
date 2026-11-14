import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/addresses_screen.dart';
import 'package:restaurante_movil/screens/delivery_driver_screen.dart';
import 'package:restaurante_movil/screens/login_screen.dart';
import 'package:restaurante_movil/widgets/backend_config_sheet.dart';
import 'package:restaurante_movil/widgets/brand_logo.dart';

class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  static const List<String> _dietOptions = [
    'Amante de Cortes a la Brasa',
    'Bajo en Carbohidratos / Keto',
    'Sin Picante',
    'Sin Lactosa',
    'Sin Cebolla',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tarjeta de Perfil con Logo Oficial
        Card(
          child: ListTile(
            leading: const BrandLogo(size: 54, circular: true),
            title: Text(
              user?.name ?? 'Cliente Las Brazas',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            subtitle:
                Text('${user?.email ?? ''}\nRol: ${user?.role ?? 'Cliente'}'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 14),

        // Selector de Tema (Modo Claro y Modo Oscuro con sus respectivos logos)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_outlined, color: Color(0xFFE8832A)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Apariencia y Tema de la App',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const BrandLogo(
                          size: 72,
                          forceDark: false,
                          borderRadius: 12,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Logo Claro',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                !isDark ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const BrandLogo(
                          size: 72,
                          forceDark: true,
                          borderRadius: 12,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Logo Oscuro',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isDark ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Claro'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Oscuro'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('Auto'),
                    ),
                  ],
                  selected: {auth.themeMode},
                  onSelectionChanged: (s) => auth.setThemeMode(s.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // RF-23: Programa de Puntos / Cashback
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: const Color(0xFFE8832A).withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.stars, color: Colors.deepOrange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Puntos Las Brazas & Cashback',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${auth.loyaltyPoints} pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: Colors.deepOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Saldo equivalente para canje: \$${auth.cashbackBalance.toStringAsFixed(2)} USD (1 pt por cada \$1 consumido).',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: auth.loyaltyPoints >= 100
                        ? () async {
                            final ok = await auth.redeemPoints(100);
                            if (!context.mounted) return;
                            if (ok) {
                              await context
                                  .read<CartProvider>()
                                  .applyCoupon('BRAZAS10');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text(
                                    '¡Canjeaste 100 puntos por un cupón BRAZAS10 en tu carrito!',
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.redeem, size: 18),
                    label: const Text('Canjear 100 pts → Cupón BRAZAS10'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // RF-25: Preferencias Dietéticas y Alergias para Recomendador IA
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferencias Gastronómicas y Alergias',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Usamos tus preferencias para personalizar las recomendaciones del menú.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _dietOptions.map((pref) {
                    final selected = auth.dietaryPreferences.contains(pref);
                    return FilterChip(
                      label: Text(pref),
                      selected: selected,
                      onSelected: (_) => auth.toggleDietaryPreference(pref),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Accesos rápidos a Libreta de Direcciones y Panel Repartidor
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Libreta de Direcciones Guardadas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delivery_dining),
                title: const Text('Panel de Repartidor'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeliveryDriverScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Bandeja de Notificaciones Push de Estado, Reservas y Promociones
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notificaciones Push en Vivo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: auth.markAllNotificationsRead,
                      child: const Text('Marcar leídas'),
                    ),
                  ],
                ),
                const Text(
                  'Se sincroniza automáticamente con el servidor para avisos de cocina, repartidor, reservas y promociones. También puedes probar una alerta Push nativa aquí:',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(
                        Icons.local_fire_department,
                        size: 15,
                        color: Colors.deepOrange,
                      ),
                      label: const Text(
                        'Push Promo',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () {
                        auth.pushNotification(
                          title: '🔥 ¡2x1 en Cortes y 10% OFF en Las Brazas!',
                          body:
                              'Hoy en Parrilla: Usa el código BRAZAS10 o ENVIOGRATIS en tu próximo pedido desde la app.',
                          category: 'promo',
                        );
                      },
                    ),
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(
                        Icons.delivery_dining,
                        size: 15,
                        color: Colors.green,
                      ),
                      label: const Text(
                        'Push Pedido',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () {
                        auth.pushNotification(
                          title: '🛵 ¡El repartidor está a 500m de tu ubicación!',
                          body:
                              'Tu orden de Las Brazas está por llegar. Ten listo tu PIN de seguridad de 4 dígitos.',
                          category: 'order',
                        );
                      },
                    ),
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(
                        Icons.event_seat,
                        size: 15,
                        color: Colors.deepPurple,
                      ),
                      label: const Text(
                        'Push Reserva',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () {
                        auth.pushNotification(
                          title: '🪑 Recordatorio de tu Reserva en Las Brazas',
                          body:
                              'Tu mesa en Terraza / Salón Principal te espera. Recuerda que tienes 15 minutos de tolerancia.',
                          category: 'reservation',
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 18),
                ...auth.notifications.map(
                  (n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      n.category == 'promo'
                          ? Icons.local_offer
                          : n.category == 'reservation'
                              ? Icons.event_seat
                              : (n.read
                                    ? Icons.notifications_none
                                    : Icons.notifications_active),
                      color: n.read
                          ? Colors.grey
                          : (n.category == 'promo'
                                ? Colors.deepOrange
                                : n.category == 'reservation'
                                    ? Colors.deepPurple
                                    : Colors.green.shade700),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight:
                            n.read ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(n.body),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await auth.logout();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text(
            'Cerrar Sesión',
            style: TextStyle(color: Colors.red),
          ),
        ),
        const SizedBox(height: 12),
        HiddenBackendTrigger(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Las Brazas Steakhouse v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil y Fidelización')),
      body: body,
    );
  }
}

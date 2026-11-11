import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/addresses_screen.dart';
import 'package:restaurante_movil/screens/delivery_driver_screen.dart';
import 'package:restaurante_movil/screens/login_screen.dart';

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

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tarjeta de Perfil
        Card(
          child: ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.deepOrange.shade100,
              child: const Icon(
                Icons.person,
                size: 30,
                color: Colors.deepOrange,
              ),
            ),
            title: Text(
              user?.name ?? 'Cliente Las Brazas',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            subtitle: Text('${user?.email ?? ''}\nRol: ${user?.role ?? 'Cliente'}'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 14),

        // RF-23: Programa de Puntos / Cashback
        Card(
          color: Colors.deepOrange.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.deepOrange.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars, color: Colors.deepOrange),
                        SizedBox(width: 8),
                        Text(
                          'Puntos Las Brazas & Cashback (RF-23)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
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
                  'Preferencias Gastronómicas y Alergias (RF-25)',
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
                title: const Text('Libreta de Direcciones Guardadas (RF-13)'),
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
                title: const Text('Vista / Panel de Repartidor (RF-17 a RF-19)'),
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

        // RF-15: Bandeja de Notificaciones Push de Estado
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notificaciones de Estado (RF-15)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: auth.markAllNotificationsRead,
                      child: const Text('Marcar leídas'),
                    ),
                  ],
                ),
                ...auth.notifications.map(
                  (n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      n.read
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: n.read ? Colors.grey : Colors.deepOrange,
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
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil y Fidelización')),
      body: body,
    );
  }
}


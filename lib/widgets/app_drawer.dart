import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/screens/addresses_screen.dart';
import 'package:restaurante_movil/screens/ai_assistant_screen.dart';
import 'package:restaurante_movil/screens/cart_screen.dart';
import 'package:restaurante_movil/screens/delivery_driver_screen.dart';
import 'package:restaurante_movil/screens/login_screen.dart';
import 'package:restaurante_movil/screens/orders_screen.dart';
import 'package:restaurante_movil/screens/profile_screen.dart';
import 'package:restaurante_movil/screens/reservations_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static void showSupportSheet(BuildContext context) {
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
              const Row(
                children: [
                  Icon(Icons.support_agent, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Soporte Directo / WhatsApp (RF-16)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Comunícate en un toque con la sucursal Las Brazas o con el repartidor asignado a tu pedido.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Abriendo chat de WhatsApp con Sucursal Las Brazas (+591 700-BRAZAS)...',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp Sucursal Las Brazas'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Contactando al repartidor asignado vía llamada directa...',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.phone_in_talk),
                label: const Text('Llamar a Sucursal / Repartidor'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFBF360C), Color(0xFF512DA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.local_fire_department,
                color: Colors.deepOrange,
                size: 36,
              ),
            ),
            accountName: Text(
              user?.name ?? 'Restaurante Las Brazas',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              '${user?.email ?? 'Invitado'} • ⭐ ${auth.loyaltyPoints} pts',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Menú Digital'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Mi Carrito'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Mis Pedidos y Seguimiento'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Mis Direcciones (GPS)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_seat),
            title: const Text('Reservas de Mesas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReservationsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.deepOrange,
            ),
            title: const Text('Asistente Gastronómico IA'),
            subtitle: const Text('Pedidos por voz y consultas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delivery_dining, color: Colors.teal),
            title: const Text('Módulo Repartidor (Delivery)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeliveryDriverScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.stars_outlined, color: Colors.amber),
            title: const Text('Mi Perfil y Puntos Cashback'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.green),
            title: const Text('Soporte / WhatsApp (RF-16)'),
            onTap: () {
              Navigator.pop(context);
              showSupportSheet(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

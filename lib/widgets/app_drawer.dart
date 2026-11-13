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
import 'package:restaurante_movil/widgets/backend_config_sheet.dart';
import 'package:restaurante_movil/widgets/brand_logo.dart';

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
                  BrandLogo(size: 38, circular: true),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Soporte Directo / WhatsApp (RF-16)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2025) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFE8832A).withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              children: [
                const BrandLogo(size: 84, borderRadius: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Las Brazas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'Steakhouse',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8832A).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '⭐ ${auth.loyaltyPoints} pts • ${user?.role ?? 'Cliente'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE8832A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: const Color(0xFFE8832A),
            ),
            title: Text(isDark ? 'Modo Oscuro Activo' : 'Modo Claro Activo'),
            subtitle: const Text('Cambia tema y logo automáticamente'),
            value: isDark,
            onChanged: (_) => auth.toggleDarkMode(isDark),
          ),
          const Divider(height: 1),
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
          HiddenBackendTrigger(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'v1.0.0 • Las Brazas',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

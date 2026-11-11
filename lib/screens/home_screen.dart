import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/category_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/ai_assistant_screen.dart';
import 'package:restaurante_movil/screens/cart_screen.dart';
import 'package:restaurante_movil/screens/dish_detail_screen.dart';
import 'package:restaurante_movil/screens/orders_screen.dart';
import 'package:restaurante_movil/screens/profile_screen.dart';
import 'package:restaurante_movil/screens/reservations_screen.dart';
import 'package:restaurante_movil/services/menu_service.dart';
import 'package:restaurante_movil/widgets/app_drawer.dart';
import 'package:restaurante_movil/widgets/brand_logo.dart';
import 'package:restaurante_movil/widgets/dish_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  List<CategoryModel> _categories = [];
  List<DishModel> _dishes = [];
  int? _selectedCategoryId; // null = "Todos"
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        MenuService.getCategories(),
        MenuService.getDishes(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<CategoryModel>;
        _dishes = results[1] as List<DishModel>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DishModel> get _filteredDishes {
    return _dishes.where((d) {
      final matchesCategory =
          _selectedCategoryId == null || d.categoryId == _selectedCategoryId;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          (d.description?.toLowerCase().contains(q) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// RF-25: Recomendación personalizada según hora del día y preferencias del cliente
  DishModel? _getRecommendedDish(AuthProvider auth) {
    final available = _dishes.where((d) => d.isAvailable).toList();
    if (available.isEmpty) return null;
    final prefersMeat =
        auth.dietaryPreferences.any((p) => p.toLowerCase().contains('corte'));
    if (prefersMeat) {
      final meats = available.where((d) => d.isMeat).toList();
      if (meats.isNotEmpty) return meats.first;
    }
    return available.first;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titles = [
      'Las Brazas • Menú',
      'Mis Pedidos',
      'Reservas de Mesas',
      'Asistente IA',
      'Mi Perfil',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandLogo(size: 32, circular: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titles[_currentTabIndex],
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Botón para alternar Modo Claro / Modo Oscuro con su logo correspondiente
          IconButton(
            tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: const Color(0xFFE8832A),
            ),
            onPressed: () => auth.toggleDarkMode(isDark),
          ),
          // Botón de Soporte directo / WhatsApp (RF-16)
          IconButton(
            tooltip: 'Soporte / WhatsApp (RF-16)',
            icon: const Icon(Icons.support_agent, color: Colors.green),
            onPressed: () => AppDrawer.showSupportSheet(context),
          ),
          // Icono de carrito con contador en vivo
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Ver carrito',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              icon: Badge(
                isLabelVisible: cart.totalItemsCount > 0,
                label: Text('${cart.totalItemsCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildMenuDashboard(auth, cart),
          const OrdersScreen(embedded: true),
          const ReservationsScreen(embedded: true),
          const AiAssistantScreen(embedded: true),
          const ProfileScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menú',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_seat_outlined),
            selectedIcon: Icon(Icons.event_seat),
            label: 'Reservas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'IA Chat',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: auth.unreadNotificationsCount > 0,
              label: Text('${auth.unreadNotificationsCount}'),
              child: const Icon(Icons.person_outline),
            ),
            selectedIcon: const Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuDashboard(AuthProvider auth, CartProvider cart) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 96),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final recommended = _getRecommendedDish(auth);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Barra superior con selector rápido de Tipo de Entrega (RF-04) y Puntos (RF-23)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            color: isDark
                ? const Color(0xFF22252C)
                : const Color(0xFFF5ECE6),
            child: Row(
              children: [
                Icon(
                  Icons.delivery_dining,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _deliveryPill(cart, 'delivery', 'Delivery'),
                        const SizedBox(width: 6),
                        _deliveryPill(cart, 'takeaway', 'Para Recoger'),
                        const SizedBox(width: 6),
                        _deliveryPill(cart, 'dine_in', 'En Mesa QR'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(
                    Icons.stars,
                    size: 16,
                    color: Colors.deepOrange,
                  ),
                  label: Text(
                    '${auth.loyaltyPoints} pts',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Buscador de platillos en vivo (RF-01)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar cortes, entradas, bebidas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // RF-25: Banner de Recomendación Personalizada
          if (recommended != null && _searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DishDetailScreen(dish: recommended),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepOrange.shade700,
                        Colors.orange.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recomendado para hoy (RF-25): ${recommended.name} • \$${recommended.price.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          _buildCategoryBar(),
          Expanded(child: _buildDishGrid(cart)),
        ],
      ),
    );
  }

  Widget _deliveryPill(CartProvider cart, String type, String label) {
    final selected = cart.orderType == type;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => cart.setOrderType(type),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: _selectedCategoryId == null,
              onSelected: (_) => setState(() => _selectedCategoryId = null),
            ),
          ),
          ..._categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: _selectedCategoryId == c.id,
                onSelected: (_) => setState(() => _selectedCategoryId = c.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishGrid(CartProvider cart) {
    final dishes = _filteredDishes;
    if (dishes.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No hay platillos en esta categoría')),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: dishes.length,
      itemBuilder: (context, i) {
        final dish = dishes[i];
        return DishCard(
          dish: dish,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
          ),
          onQuickAdd: () {
            cart.addItem(
              CartItemModel(
                dish: dish,
                quantity: 1,
                cookingTerm:
                    dish.isMeat ? 'Término Medio (A punto)' : null,
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                content: Text('${dish.name} agregado al carrito'),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/models/order_model.dart';
import 'package:restaurante_movil/models/reservation_model.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/cart_screen.dart';
import 'package:restaurante_movil/services/ai_assistant_service.dart';
import 'package:restaurante_movil/services/menu_service.dart';
import 'package:restaurante_movil/services/order_service.dart';
import 'package:restaurante_movil/services/reservation_service.dart';

class _ChatMessage {
  final String sender; // 'user' | 'ai'
  final String text;
  final List<CartItemModel> suggestedItems;

  _ChatMessage({
    required this.sender,
    required this.text,
    this.suggestedItems = const [],
  });
}

class AiAssistantScreen extends StatefulWidget {
  final bool embedded;
  const AiAssistantScreen({super.key, this.embedded = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  List<DishModel> _catalog = [];
  List<OrderModel> _orders = [];
  List<ReservationModel> _reservations = [];
  bool _sending = false;
  bool _listeningVoice = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        sender: 'ai',
        text:
            '🔥 ¡Hola! Soy el **Asistente Gastronómico IA de Las Brazas** (RF-26 / RF-27).\n\n'
            'Puedes preguntarme por cortes de carne, términos de cocción, tiempos de preparación, el estado de tus pedidos/reservas, o dictarme tu pedido en lenguaje natural (ej. *"Pídeme una arrachera término medio con papas y un queso fundido"*).',
      ),
    );
    _loadContextData();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContextData() async {
    try {
      final dishes = await MenuService.getDishes();
      if (mounted) setState(() => _catalog = dishes);
    } catch (_) {}
    try {
      final orders = await OrderService.getHistory();
      if (mounted) setState(() => _orders = orders);
    } catch (_) {}
    try {
      final res = await ReservationService.getReservations();
      if (mounted) setState(() => _reservations = res['active'] ?? []);
    } catch (_) {}
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _msgCtrl.text).trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    setState(() {
      _messages.add(_ChatMessage(sender: 'user', text: text));
      _sending = true;
    });

    final result = await AiAssistantService.sendMessage(
      message: text,
      catalog: _catalog,
      activeOrders: _orders,
      activeReservations: _reservations,
      history: _messages
          .map((m) => {'role': m.sender, 'content': m.text})
          .toList(),
    );

    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          sender: 'ai',
          text: result.reply,
          suggestedItems: result.suggestedItems,
        ),
      );
      _sending = false;
    });
  }

  /// RF-26: Simulación de dictado por voz para armar orden en lenguaje natural
  Future<void> _simulateVoiceDictation() async {
    setState(() => _listeningVoice = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _listeningVoice = false);
    const sampleVoiceCommand =
        'Pídeme una Arrachera término medio con papas y un Queso Fundido sin cebolla';
    _msgCtrl.text = sampleVoiceCommand;
    _sendMessage(sampleVoiceCommand);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // Chips de consulta rápida
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _quickChip('🥩 ¿Qué cortes me recomiendas?'),
              _quickChip('🎙️ Pídeme una arrachera término medio con papas'),
              _quickChip('📦 ¿Cuál es el estado de mi pedido?'),
              _quickChip('🪑 Políticas de reserva y tolerancia'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final isUser = m.sender == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      if (m.suggestedItems.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final cart = context.read<CartProvider>();
                              for (final item in m.suggestedItems) {
                                cart.addItem(item);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text(
                                    '¡Orden por voz/IA agregada al carrito!',
                                  ),
                                ),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text(
                              'Agregar orden sugerida al carrito',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_sending || _listeningVoice)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  _listeningVoice
                      ? '🎙️ Escuchando tu orden por voz...'
                      : 'Consultando con el Maestro Parrillero IA...',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Dictar pedido por voz (RF-26)',
                  onPressed: _listeningVoice ? null : _simulateVoiceDictation,
                  icon: Icon(
                    _listeningVoice ? Icons.mic : Icons.mic_none,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText:
                          'Pregunta o dicta tu orden ("Pídeme una arrachera...")',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : () => _sendMessage(),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente Gastronómico IA (RF-26 / RF-27)'),
      ),
      body: content,
    );
  }

  Widget _quickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () => _sendMessage(label),
      ),
    );
  }
}


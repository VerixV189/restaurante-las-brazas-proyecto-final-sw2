import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/cart_item_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/models/order_model.dart';
import 'package:restaurante_movil/models/reservation_model.dart';
import 'package:restaurante_movil/services/http_client.dart';

class AiParsedOrderResult {
  final String reply;
  final List<CartItemModel> suggestedItems;

  AiParsedOrderResult({
    required this.reply,
    this.suggestedItems = const [],
  });
}

class AiAssistantService {
  /// Consulta al Asistente Virtual Gastronómico y detecta órdenes en lenguaje natural (RF-26, RF-27)
  static Future<AiParsedOrderResult> sendMessage({
    required String message,
    required List<DishModel> catalog,
    List<OrderModel> activeOrders = const [],
    List<ReservationModel> activeReservations = const [],
    List<Map<String, String>> history = const [],
  }) async {
    // 1. Detectar si el usuario está dictando un pedido en lenguaje natural (RF-26)
    final parsedItems = _parseNaturalLanguageOrder(message, catalog);

    // 2. Intentar consultar al endpoint de IA de Laravel (/ai/chat) si está disponible
    try {
      final response = await HttpClient.post(
        ApiConstants.aiChat,
        auth: true,
        body: {
          'message': message,
          'history': history,
        },
      );
      if (response is Map && response['reply'] != null) {
        return AiParsedOrderResult(
          reply: response['reply'].toString(),
          suggestedItems: parsedItems,
        );
      }
    } catch (_) {
      // Fallback gastronómico local inteligente conectado a los datos en vivo del restaurante
    }

    final localReply = _buildSmartGastronomicReply(
      message: message,
      catalog: catalog,
      parsedItems: parsedItems,
      activeOrders: activeOrders,
      activeReservations: activeReservations,
    );

    return AiParsedOrderResult(
      reply: localReply,
      suggestedItems: parsedItems,
    );
  }

  static List<CartItemModel> _parseNaturalLanguageOrder(
    String message,
    List<DishModel> catalog,
  ) {
    final lower = message.toLowerCase();
    final isOrderIntent = lower.contains('pídeme') ||
        lower.contains('pideme') ||
        lower.contains('quiero pedir') ||
        lower.contains('agrega') ||
        lower.contains('ordenar') ||
        lower.contains('dame ') ||
        lower.contains('quiero una') ||
        lower.contains('quiero un');

    if (!isOrderIntent && catalog.isEmpty) return [];

    String? detectedTerm;
    if (lower.contains('término medio') || lower.contains('termino medio')) {
      detectedTerm = 'Término Medio (A punto)';
    } else if (lower.contains('tres cuartos') || lower.contains('3/4')) {
      detectedTerm = 'Tres Cuartos (Jugoso)';
    } else if (lower.contains('bien cocido')) {
      detectedTerm = 'Bien Cocido';
    } else if (lower.contains('sellado') || lower.contains('vuelta y vuelta')) {
      detectedTerm = 'Vuelta y vuelta (Sellado)';
    }

    String? detectedSide;
    if (lower.contains('papas')) {
      detectedSide = 'Papas a la francesa';
    } else if (lower.contains('ensalada')) {
      detectedSide = 'Ensalada fresca de la casa';
    } else if (lower.contains('puré') || lower.contains('pure')) {
      detectedSide = 'Puré rústico';
    }

    final List<CartItemModel> matched = [];
    for (final dish in catalog) {
      if (!dish.isAvailable) continue;
      final dishWords = dish.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\sáéíóúñ]'), '')
          .split(' ')
          .where((w) => w.length >= 4)
          .toList();

      final hits = dishWords.where((w) => lower.contains(w)).length;
      if (hits > 0 && (isOrderIntent || hits >= 1)) {
        int qty = 1;
        if (lower.contains('dos ${dishWords.first}') ||
            lower.contains('2 ${dishWords.first}')) {
          qty = 2;
        } else if (lower.contains('tres ${dishWords.first}') ||
            lower.contains('3 ${dishWords.first}')) {
          qty = 3;
        }
        matched.add(
          CartItemModel(
            dish: dish,
            quantity: qty,
            cookingTerm: dish.isMeat
                ? (detectedTerm ?? 'Término Medio (A punto)')
                : null,
            sideDish: detectedSide,
            customNotes: lower.contains('sin cebolla') ? 'Sin cebolla' : null,
          ),
        );
      }
    }
    return matched;
  }

  static String _buildSmartGastronomicReply({
    required String message,
    required List<DishModel> catalog,
    required List<CartItemModel> parsedItems,
    required List<OrderModel> activeOrders,
    required List<ReservationModel> activeReservations,
  }) {
    final lower = message.toLowerCase();

    if (parsedItems.isNotEmpty) {
      final summary = parsedItems
          .map((i) =>
              '• ${i.quantity}x ${i.dish.name}${i.cookingTerm != null ? ' (${i.cookingTerm})' : ''}${i.sideDish != null ? ' + ${i.sideDish}' : ''} — \$${i.subtotal.toStringAsFixed(2)}')
          .join('\n');
      return '¡Excelente elección para las brasas! He preparado tu orden a partir de tu mensaje:\n\n$summary\n\nPresiona el botón **"Agregar orden sugerida al carrito"** aquí abajo para confirmarla.';
    }

    if (lower.contains('pedido') ||
        lower.contains('orden') ||
        lower.contains('estado') ||
        lower.contains('dónde está')) {
      if (activeOrders.isEmpty) {
        return 'Actualmente no tienes pedidos activos en curso. ¿Te gustaría que te recomiende un corte a las brasas para ordenar hoy?';
      }
      final latest = activeOrders.first;
      final step = OrderTrackingModel.stepLabel(latest.tracking.current);
      return 'Tu pedido más reciente es el **#${latest.id}** (${latest.orderTypeLabel}) por **\$${latest.total.toStringAsFixed(2)}**.\n'
          '• Estado actual en tiempo real: **$step**.\n'
          '${latest.deliveryPin != null ? '• Tu PIN de seguridad para entrega es: **${latest.deliveryPin}**.' : ''}';
    }

    if (lower.contains('reserva') ||
        lower.contains('mesa') ||
        lower.contains('tolerancia') ||
        lower.contains('política')) {
      final resInfo = activeReservations.isNotEmpty
          ? '\n\nTienes **${activeReservations.length}** reserva(s) activa(s). La próxima es el **${activeReservations.first.reservationDate}** para **${activeReservations.first.guestCount} personas** (${activeReservations.first.statusLabel}).'
          : '';
      return 'En **Restaurante Las Brazas** puedes reservar en Salón Principal, Terraza o Área VIP.\n'
          '• **Política de tolerancia**: Tu mesa se guarda por **15 minutos estrictos** a partir de la hora reservada.\n'
          '• **Cancelaciones**: Con al menos **2 horas** de anticipación desde el módulo de Reservas.$resInfo';
    }

    if (lower.contains('término') ||
        lower.contains('termino') ||
        lower.contains('carne') ||
        lower.contains('corte') ||
        lower.contains('recomienda')) {
      final menuLines = catalog
          .take(5)
          .map((d) =>
              '• **${d.name}** (\$${d.price.toStringAsFixed(2)}) — ⏱ ${d.prepTimeMinutes} min${d.description != null ? ': ${d.description}' : ''}')
          .join('\n');
      return '🔥 **Recomendaciones del Maestro Parrillero en Las Brazas:**\n\n'
          '$menuLines\n\n'
          'Nuestros cortes se sirven en 4 términos: *Vuelta y vuelta (Sellado)*, *Término Medio (A punto)*, *Tres Cuartos (Jugoso)* o *Bien Cocido*.\n\n'
          '💡 Puedes dictarme tu pedido, por ejemplo: *"Pídeme una Arrachera término medio con papas y un Queso Fundido"*.';
    }

    if (lower.contains('envío') ||
        lower.contains('delivery') ||
        lower.contains('cupón') ||
        lower.contains('cupon') ||
        lower.contains('descuento')) {
      return '🚚 **Información de Delivery y Promociones:**\n'
          '• El costo de envío estándar es de **\$3.00** y es **GRATIS en compras mayores a \$50.00**.\n'
          '• Tiempo estimado de entrega: **prep + 30 min** (aprox. 35–50 min).\n'
          '• Puedes aplicar cupones como `BRAZAS10` o `ENVIOGRATIS` directamente en tu carrito.';
    }

    final dishList = catalog
        .map((d) => '• ${d.name} (\$${d.price.toStringAsFixed(2)}, ${d.prepTimeMinutes} min)')
        .join('\n');
    return '¡Hola! Soy el **Asistente Gastronómico IA de Las Brazas** 🔥.\n\n'
        'Puedo ayudarte con:\n'
        '1. **Tomar tu pedido por voz o texto** (ej. *"Pídeme una arrachera término medio y un queso fundido"*).\n'
        '2. **Consultar nuestro menú actual**:\n$dishList\n'
        '3. **Revisar el estado en vivo** de tus pedidos, reservas y políticas de tolerancia.';
  }
}


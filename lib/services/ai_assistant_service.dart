import 'dart:convert';
import 'package:http/http.dart' as http;
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
  /// Consulta al Asistente Virtual Gastronómico y detecta órdenes en lenguaje natural
  static Future<AiParsedOrderResult> sendMessage({
    required String message,
    required List<DishModel> catalog,
    List<OrderModel> activeOrders = const [],
    List<ReservationModel> activeReservations = const [],
    List<Map<String, String>> history = const [],
  }) async {
    // 1. Detectar si el usuario está dictando un pedido en lenguaje natural
    final parsedItems = _parseNaturalLanguageOrder(message, catalog);

    // Instruction suffix para que el modelo del backend no envíe asteriscos crudos
    final promptForBackend =
        '$message\n[Instrucción de formato: responde en texto plano limpio con viñetas (•) y emojis, sin usar asteriscos * ni **]';

    // 2. Intentar consultar al endpoint API v1 (/api/v1/ai/chat) o web (/ai/chat) de Laravel
    for (final endpoint in [ApiConstants.aiChatV1, ApiConstants.aiChat]) {
      try {
        final response = await HttpClient.post(
          endpoint,
          auth: true,
          body: {
            'message': promptForBackend,
            'history': history,
          },
        );
        if (response is Map && response['reply'] != null) {
          final rawReply = response['reply'].toString();
          // Si el backend no cayó en su mensaje de error por falta de API key
          if (!rawReply.contains('Configura GEMINI_API_KEY') &&
              !rawReply.contains('temporalmente fuera de línea')) {
            return AiParsedOrderResult(
              reply: cleanAsterisks(rawReply),
              suggestedItems: parsedItems,
            );
          }
        }
      } catch (_) {
        // Continúa al siguiente método
      }
    }

    // 3. Si hay una GEMINI_API_KEY configurada en .env o en el panel del móvil, consultar directamente a Gemini 2.5 Flash
    final directKey = ApiConstants.geminiApiKey;
    if (directKey.isNotEmpty) {
      final directReply = await _callGeminiDirectly(
        apiKey: directKey,
        message: message,
        catalog: catalog,
        activeOrders: activeOrders,
        activeReservations: activeReservations,
        history: history,
      );
      if (directReply != null && directReply.trim().isNotEmpty) {
        return AiParsedOrderResult(
          reply: cleanAsterisks(directReply),
          suggestedItems: parsedItems,
        );
      }
    }

    // 4. Motor conversacional gastronómico inteligente conectado a los datos en vivo del restaurante
    final localReply = _buildSmartGastronomicReply(
      message: message,
      catalog: catalog,
      parsedItems: parsedItems,
      activeOrders: activeOrders,
      activeReservations: activeReservations,
    );

    return AiParsedOrderResult(
      reply: cleanAsterisks(localReply),
      suggestedItems: parsedItems,
    );
  }

  /// Limpia asteriscos sueltos o de Markdown para que nunca se vean "*" crudos en pantalla
  static String cleanAsterisks(String input) {
    return input
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1) ?? '')
        .replaceAll('*', '');
  }

  static Future<String?> _callGeminiDirectly({
    required String apiKey,
    required String message,
    required List<DishModel> catalog,
    required List<OrderModel> activeOrders,
    required List<ReservationModel> activeReservations,
    required List<Map<String, String>> history,
  }) async {
    try {
      final menuText = catalog.isEmpty
          ? 'Catálogo cargando.'
          : catalog
              .map((d) =>
                  '• ${d.name} (\$${d.price.toStringAsFixed(2)}, prep: ${d.prepTimeMinutes} min)${d.description != null ? ': ${d.description}' : ''}')
              .join('\n');

      final ordersText = activeOrders.isEmpty
          ? 'Sin pedidos activos en este momento.'
          : activeOrders
              .take(3)
              .map((o) =>
                  '• Pedido #${o.id} (${o.orderTypeLabel}) - Estado: ${OrderTrackingModel.stepLabel(o.tracking.current)} - Total: \$${o.total.toStringAsFixed(2)}')
              .join('\n');

      final resText = activeReservations.isEmpty
          ? 'Sin reservas activas en este momento.'
          : activeReservations
              .take(3)
              .map((r) =>
                  '• Reserva #${r.id} el ${r.reservationDate} para ${r.guestCount} personas (${r.statusLabel})')
              .join('\n');

      final systemPrompt = '''
Eres el Asistente Gastronómico IA oficial de "Restaurante Las Brazas Steakhouse", impulsado por el modelo Google Gemini 2.5 Flash (gemini-2.5-flash).
REGLAS DE FORMATO OBLIGATORIAS:
- PROHIBIDO usar asteriscos (* o **) en tus respuestas.
- Usa únicamente texto limpio, emojis y viñetas con el símbolo "•" para las listas.
- Sé cálido, conciso, profesional y experto en parrilla y cortes de carne.

DATOS EN TIEMPO REAL DEL RESTAURANTE LAS BRAZAS:
Menú disponible hoy:
$menuText

Términos de cocción disponibles: Vuelta y vuelta (Sellado), Término Medio (A punto), Tres Cuartos (Jugoso), Bien Cocido.
Políticas de reserva: Mesas en Salón Principal, Terraza y Área VIP. Tolerancia estricta de 15 minutos; cancelaciones con mínimo 2 horas de anticipación.
Delivery: Envío estándar \$3.00 (gratis en pedidos mayores a \$50.00). Cupones activos: BRAZAS10 y ENVIOGRATIS.

Pedidos del cliente:
$ordersText

Reservas del cliente:
$resText
''';

      final contents = <Map<String, dynamic>>[];
      for (final msg in history.take(8)) {
        final text = (msg['content'] ?? '').trim();
        if (text.isEmpty) continue;
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': text}
          ],
        });
      }
      contents.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ],
      });

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );

      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt}
                ]
              },
              'contents': contents,
              'generationConfig': {
                'temperature': 0.65,
                'maxOutputTokens': 700,
              },
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    } catch (_) {}
    return null;
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
      return '🔥 ¡Excelente elección para las brasas! He preparado tu orden a partir de tu mensaje:\n\n$summary\n\nPresiona el botón "Agregar orden sugerida al carrito" aquí abajo para confirmarla.';
    }

    // Consultas sobre identidad del agente, modelo o Gemini
    if (lower.contains('gemini') ||
        lower.contains('modelo') ||
        lower.contains('agente') ||
        lower.contains('quién eres') ||
        lower.contains('quien eres') ||
        lower.contains('qué eres') ||
        lower.contains('que eres')) {
      return '🤖 ¡Sí! Soy el Asistente Gastronómico Inteligente de Restaurante Las Brazas, impulsado por la arquitectura Google Gemini (modelo gemini-2.5-flash) con contexto en vivo (RAG) de nuestra parrilla.\n\n'
          'Estoy conectado en tiempo real con:\n'
          '• Nuestro catálogo de cortes, entradas, bebidas y tiempos de cocción.\n'
          '• Tus pedidos activos y seguimiento de entrega.\n'
          '• Tus reservas de mesas y políticas del restaurante.\n\n'
          '¿Qué corte o platillo te gustaría ordenar o consultar hoy?';
    }

    if (lower.contains('pedido') ||
        lower.contains('orden') ||
        lower.contains('estado') ||
        lower.contains('dónde está') ||
        lower.contains('donde esta')) {
      if (activeOrders.isEmpty) {
        return '📦 Actualmente no tienes pedidos activos en curso. ¿Te gustaría que te recomiende un corte a las brasas para ordenar hoy?';
      }
      final latest = activeOrders.first;
      final step = OrderTrackingModel.stepLabel(latest.tracking.current);
      return '📦 Tu pedido más reciente es el #${latest.id} (${latest.orderTypeLabel}) por \$${latest.total.toStringAsFixed(2)}.\n'
          '• Estado actual en tiempo real: $step.\n'
          '${latest.deliveryPin != null ? '• Tu PIN de seguridad para entrega es: ${latest.deliveryPin}.' : ''}';
    }

    if (lower.contains('reserva') ||
        lower.contains('mesa') ||
        lower.contains('tolerancia') ||
        lower.contains('política') ||
        lower.contains('politica')) {
      final resInfo = activeReservations.isNotEmpty
          ? '\n\n📅 Tienes ${activeReservations.length} reserva(s) activa(s). La próxima es el ${activeReservations.first.reservationDate} para ${activeReservations.first.guestCount} personas (${activeReservations.first.statusLabel}).'
          : '';
      return '🪑 En Restaurante Las Brazas puedes reservar en Salón Principal, Terraza o Área VIP:\n'
          '• Política de tolerancia: Tu mesa se guarda por 15 minutos estrictos a partir de la hora reservada.\n'
          '• Cancelaciones: Con al menos 2 horas de anticipación desde la pestaña Reservas.$resInfo';
    }

    if (lower.contains('término') ||
        lower.contains('termino') ||
        lower.contains('carne') ||
        lower.contains('corte') ||
        lower.contains('recomienda') ||
        lower.contains('parrilla') ||
        lower.contains('menú') ||
        lower.contains('menu')) {
      final menuLines = catalog
          .take(6)
          .map((d) =>
              '• ${d.name} (\$${d.price.toStringAsFixed(2)}) — ⏱ ${d.prepTimeMinutes} min${d.description != null ? ': ${d.description}' : ''}')
          .join('\n');
      return '🔥 Recomendaciones del Maestro Parrillero en Las Brazas:\n\n'
          '$menuLines\n\n'
          'Nuestros cortes se sirven en 4 términos: Vuelta y vuelta (Sellado), Término Medio (A punto), Tres Cuartos (Jugoso) o Bien Cocido.\n\n'
          '💡 Puedes dictarme tu pedido diciendo: "Pídeme una Arrachera término medio con papas y un Queso Fundido".';
    }

    if (lower.contains('envío') ||
        lower.contains('envio') ||
        lower.contains('delivery') ||
        lower.contains('cupón') ||
        lower.contains('cupon') ||
        lower.contains('descuento') ||
        lower.contains('pago')) {
      return '🚚 Información de Delivery, Pagos y Promociones:\n'
          '• El costo de envío estándar es de \$3.00 y es GRATIS en compras mayores a \$50.00.\n'
          '• Tiempo estimado de entrega: preparación + 30 min (aprox. 35–50 min).\n'
          '• Métodos de pago: Efectivo, Pago QR inmediato y Tarjeta.\n'
          '• Cupones disponibles en tu carrito: BRAZAS10 y ENVIOGRATIS.';
    }

    if (lower.contains('horario') ||
        lower.contains('abierto') ||
        lower.contains('ubicación') ||
        lower.contains('ubicacion') ||
        lower.contains('dirección')) {
      return '📍 Horarios y Atención de Las Brazas Steakhouse:\n'
          '• Lunes a Domingo de 12:00 a 23:00 hrs.\n'
          '• Contamos con Salón Principal, Terraza al aire libre y Salón VIP.\n'
          '• Servicio en mesa con código QR, Para Recoger (Takeaway) y Delivery con rastreo en vivo.';
    }

    final dishList = catalog
        .take(6)
        .map((d) =>
            '• ${d.name} (\$${d.price.toStringAsFixed(2)}, ${d.prepTimeMinutes} min)')
        .join('\n');
    return '¡Hola! Soy el Asistente Gastronómico IA de Las Brazas 🔥.\n\n'
        'Puedo ayudarte con:\n'
        '1. Tomar tu pedido por voz o texto (ej. "Pídeme una arrachera término medio y un queso fundido").\n'
        '2. Consultar nuestro menú actual:\n$dishList\n'
        '3. Revisar el estado en vivo de tus pedidos, reservas y políticas de tolerancia.';
  }
}

import 'package:flutter/material.dart';
import 'package:restaurante_movil/widgets/brand_logo.dart';

enum LegalDocType { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocType type;
  final bool showAcceptButton;

  const LegalDocumentScreen({
    super.key,
    required this.type,
    this.showAcceptButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isTerms = type == LegalDocType.terms;
    final accentColor = isTerms ? const Color(0xFFD85A1A) : Colors.teal.shade700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTerms ? 'Términos y Condiciones' : 'Política de Privacidad',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado del documento legal
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                const BrandLogo(size: 64, circular: true),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isTerms
                        ? 'DOCUMENTO LEGAL Y NORMATIVO'
                        : 'PROTECCIÓN DE DATOS PERSONALES',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isTerms
                      ? 'Términos del Servicio y Condiciones del Sitio'
                      : 'Política de Privacidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isTerms
                      ? 'En Restaurante Las Brazas valoramos la transparencia y la confianza de nuestros comensales. Vigente desde Septiembre de 2026 • Versión 2.0'
                      : 'Nos comprometemos a proteger la privacidad, confidencialidad y seguridad de tu información personal. Actualización: Noviembre de 2026 • Versión 2.1',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (isTerms) ..._buildTermsSections(accentColor) else ..._buildPrivacySections(accentColor),

          const SizedBox(height: 18),
          if (showAcceptButton)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  isTerms
                      ? 'Aceptar Términos y Volver al Registro'
                      : 'Aceptar Privacidad y Volver al Registro',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            '© 2026 Restaurante Las Brazas • Steakhouse & Grill. Todos los derechos reservados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildTermsSections(Color accent) {
    return [
      _sectionCard(
        icon: Icons.verified_user_outlined,
        color: accent,
        title: '1. Términos del Servicio y Registro de Cuenta',
        subtitle: 'Condiciones de acceso como comensal registrado',
        bullets: const [
          'El acceso a reservas automáticas, pedidos en línea, historial de visitas y preferencias requiere crear una cuenta de usuario.',
          'Al registrarte garantizas que tus datos (nombre completo, correo electrónico y teléfono) son veraces y te comprometes a salvaguardar tu contraseña.',
          'Recibirás copia detallada de estos Términos, las Condiciones del Sitio y la Política de Privacidad en tu correo electrónico.',
        ],
      ),
      _sectionCard(
        icon: Icons.timer_outlined,
        color: Colors.amber.shade800,
        title: '2. Políticas de Reserva, Tolerancia y Asistencia',
        subtitle: 'Normas para garantizar mesas a todos los visitantes',
        bullets: const [
          'Tolerancia estricta de 15 minutos: Toda reserva confirmada se mantiene bloqueada por un máximo de 15 minutos desde la hora solicitada antes de liberar la mesa.',
          'Para grupos mayores a 8 comensales, se solicita confirmar asistencia con al menos 2 horas de anticipación.',
          'Puedes cancelar tu reserva desde la plataforma con anticipación antes de la hora reservada.',
        ],
      ),
      _sectionCard(
        icon: Icons.restaurant_outlined,
        color: accent,
        title: '3. Menú, Cortes a la Brasa y Alérgenos',
        subtitle: 'Calidad culinaria y seguridad alimentaria',
        bullets: const [
          'Todos nuestros cortes (Arrachera, Bife de Chorizo, Picaña, Tomahawk y Costillares) se preparan con carne fresca a las brasas de carbón y leña.',
          'Si presentas alergias alimentarias (gluten, lactosa, frutos secos) o prefieres un término de cocción específico, indícalo en las notas de tu pedido o preferencias de perfil.',
        ],
      ),
      _sectionCard(
        icon: Icons.credit_card_outlined,
        color: Colors.green.shade700,
        title: '4. Facturación, Métodos de Pago y Cancelaciones',
        subtitle: 'Transparencia económica en pedidos y entregas',
        bullets: const [
          'Los precios exhibidos incluyen los impuestos de ley. Emitimos comprobante digital o factura fiscal por cada consumo.',
          'Aceptamos Efectivo contra entrega, Tarjetas de Débito/Crédito, Transferencias Bancarias y Pago QR inmediato.',
          'Las cancelaciones de pedidos activos aplican penalización progresiva según etapa (10% Recibido, 30% En Cocina, 50% Listo, 70% En Camino).',
        ],
      ),
      _sectionCard(
        icon: Icons.shield_outlined,
        color: Colors.blue.shade700,
        title: '5. Privacidad y Protección de Datos Personales',
        subtitle: 'Seguridad de la información del cliente',
        bullets: const [
          'No comercializamos ni compartimos tus datos con terceros con fines ajenos al servicio de Restaurante Las Brazas.',
          'Tus datos se usan para gestionar reservas, entregar pedidos con PIN de seguridad, emitir facturas y enviar avisos sobre tu cuenta.',
        ],
      ),
      _sectionCard(
        icon: Icons.gavel_outlined,
        color: Colors.red.shade700,
        title: '6. Código de Convivencia y Admisión',
        subtitle: 'Ambiente armónico y familiar',
        bullets: const [
          'Restaurante Las Brazas promueve una atmósfera cálida y familiar, reservándose el derecho de admisión ante comportamientos inapropiados.',
        ],
      ),
    ];
  }

  List<Widget> _buildPrivacySections(Color accent) {
    return [
      _sectionCard(
        icon: Icons.storage_outlined,
        color: accent,
        title: '1. Información que Recopilamos',
        subtitle: 'Datos mínimos necesarios para brindarte el servicio',
        bullets: const [
          'Datos de identificación y contacto: Nombre completo, correo electrónico y teléfono/WhatsApp.',
          'Datos de entrega y reservas: Direcciones GPS guardadas para delivery, preferencias de mesa, comensales y alergias.',
          'Historial de pedidos, cupones canjeados y comprobantes fiscales.',
        ],
      ),
      _sectionCard(
        icon: Icons.login_outlined,
        color: Colors.blue.shade700,
        title: '2. Inicio de Sesión con Google (OAuth 2.0)',
        subtitle: 'Autenticación segura en 1 clic sin contraseñas externas',
        bullets: const [
          'Al usar "Continuar con Google" solicitamos únicamente tu identidad básica (nombre y correo electrónico verificado).',
          'Jamás solicitamos ni tenemos acceso a tu contraseña de Google, bandeja de Gmail, Google Drive o contactos.',
          'Tu correo se usa para crear o vincular tu cuenta de comensal y enviarte los 3 correos legales (Términos, Condiciones y Privacidad).',
        ],
      ),
      _sectionCard(
        icon: Icons.visibility_outlined,
        color: const Color(0xFFD85A1A),
        title: '3. Finalidad del Uso de tus Datos',
        subtitle: 'Para qué utilizamos tu información',
        bullets: const [
          'Gestionar, confirmar y notificar en tiempo real tus reservas y pedidos a domicilio o salón.',
          'Generar códigos PIN de 4 dígitos para confirmar entregas seguras en tus manos.',
          'Emitir comprobantes PDF y atender consultas de soporte.',
        ],
      ),
      _sectionCard(
        icon: Icons.lock_outline,
        color: Colors.purple.shade700,
        title: '4. Seguridad, Cifrado y Caché Offline (PWA)',
        subtitle: 'Resguardo técnico en dispositivos compartidos',
        bullets: const [
          'Todas las comunicaciones viajan cifradas bajo HTTPS (TLS/SSL) y las contraseñas se almacenan con hash irreversible.',
          'Aislamiento de Modo Offline (PWA): Los datos de sesión autenticada se almacenan por usuario y se eliminan automáticamente al cerrar sesión o cambiar de cuenta.',
        ],
      ),
      _sectionCard(
        icon: Icons.manage_accounts_outlined,
        color: Colors.amber.shade800,
        title: '5. Conservación y Derechos del Titular (ARCO)',
        subtitle: 'Control total sobre tu cuenta y datos',
        bullets: const [
          'Acceso y Rectificación: Puedes actualizar tus direcciones y preferencias desde tu perfil en cualquier momento.',
          'Cancelación y Revocación: Puedes solicitar la eliminación de tu cuenta o desvincular Google cuando lo desees.',
        ],
      ),
      _sectionCard(
        icon: Icons.mail_outline,
        color: Colors.cyan.shade700,
        title: '6. Contacto sobre Privacidad',
        subtitle: 'Canal directo con administración',
        bullets: const [
          'Restaurante Las Brazas Steakhouse — Av. Las Brazas #120, Zona Equipetrol Norte, Santa Cruz de la Sierra, Bolivia • Tel: +591 (3) 345-6789.',
        ],
      ),
    ];
  }

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<String> bullets,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: const TextStyle(fontSize: 13, height: 1.38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

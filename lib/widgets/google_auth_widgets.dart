import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:restaurante_movil/services/auth_service.dart';

/// Logo oficial de Google de 4 colores dibujado en vector (igual al SVG del portal web)
class GoogleLogoIcon extends StatelessWidget {
  final double size;
  const GoogleLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.21;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Rojo (superior)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.85, math.pi * 0.62, false, paint);

    // Amarillo (izquierda)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.72, math.pi * 0.45, false, paint);

    // Verde (inferior)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.14, math.pi * 0.60, false, paint);

    // Azul (derecha + barra horizontal de la G)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.04, math.pi * 0.22, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth * 0.92
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.50),
      Offset(size.width * 0.96, size.height * 0.50),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Botón "Continuar con Google" idéntico al de Register.vue y Login.vue
class GoogleContinueButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool enabledStyle;
  final bool loading;

  const GoogleContinueButton({
    super.key,
    required this.onPressed,
    this.enabledStyle = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = enabledStyle
        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
        : (isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.45)
            : Colors.grey.shade100);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: enabledStyle ? 0.16 : 0.08)
        : Colors.grey.shade300;
    final textColor = enabledStyle
        ? (isDark ? Colors.white : const Color(0xFF1E293B))
        : Colors.grey;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabledStyle ? 1.0 : 0.75,
      child: Material(
        color: bgColor,
        elevation: enabledStyle ? 1.5 : 0,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onPressed,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const GoogleLogoIcon(size: 21),
                const SizedBox(width: 12),
                Text(
                  loading
                      ? 'Conectando con Google...'
                      : 'Continuar con Google',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal selector de cuenta Google OAuth 2.0 (1 clic para cuentas recientes o ingresar correo Google)
Future<GoogleAccountOption?> showGoogleAccountPicker(
  BuildContext context, {
  String? prefillEmail,
  String? prefillName,
}) async {
  final recentAccounts = await AuthService.getRecentGoogleAccounts();
  if (!context.mounted) return null;

  final emailCtrl = TextEditingController(text: prefillEmail ?? '');
  final nameCtrl = TextEditingController(text: prefillName ?? '');
  bool addingOther = recentAccounts.isEmpty;
  String? errorMsg;

  return showModalBottomSheet<GoogleAccountOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const GoogleLogoIcon(size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Iniciar sesión con Google',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Elige una cuenta de Google para continuar en Las Brazas Steakhouse',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),

                  if (recentAccounts.isNotEmpty && !addingOther) ...[
                    ...recentAccounts.map(
                      (acc) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4285F4),
                            child: Text(
                              acc.name.isNotEmpty
                                  ? acc.name[0].toUpperCase()
                                  : 'G',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            acc.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(acc.email),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(ctx, acc),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setModalState(() => addingOther = true),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Usar otra cuenta de Google'),
                    ),
                  ] else ...[
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre en tu cuenta Google *',
                        hintText: 'Ej: Marcelo Quiroga',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo de Google *',
                        hintText: 'tucorreo@gmail.com',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final email = emailCtrl.text.trim();
                          final name = nameCtrl.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setModalState(
                              () => errorMsg =
                                  'Ingresa un correo de Google válido (ej. usuario@gmail.com).',
                            );
                            return;
                          }
                          Navigator.pop(
                            ctx,
                            GoogleAccountOption(
                              name: name.isNotEmpty
                                  ? name
                                  : email.split('@').first,
                              email: email,
                            ),
                          );
                        },
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text(
                          'Continuar con esta cuenta de Google',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (recentAccounts.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            setModalState(() => addingOther = false),
                        child: const Text('Volver a cuentas guardadas'),
                      ),
                  ],

                  const SizedBox(height: 12),
                  const Text(
                    'Al continuar, Google compartirá únicamente tu nombre y correo electrónico verificado con Las Brazas Steakhouse (alcances openid, email, profile).',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


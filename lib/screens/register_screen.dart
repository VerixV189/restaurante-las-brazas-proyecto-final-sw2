import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/home_screen.dart';
import 'package:restaurante_movil/screens/legal_document_screen.dart';
import 'package:restaurante_movil/services/auth_service.dart';
import 'package:restaurante_movil/widgets/brand_logo.dart';
import 'package:restaurante_movil/widgets/google_auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalConsentsKey = GlobalKey();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _googleConsentWarning = false;

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _bothPoliciesAccepted => _termsAccepted && _privacyAccepted;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openLegalDocument(LegalDocType type) async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(type: type),
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() {
      if (type == LegalDocType.terms) {
        _termsAccepted = true;
      } else {
        _privacyAccepted = true;
      }
      if (_bothPoliciesAccepted) {
        _googleConsentWarning = false;
      }
    });
  }

  Future<void> _handleGoogleRegisterClick() async {
    // Misma regla exacta que Register.vue: exige marcar ambos checks antes de continuar con Google
    if (!_bothPoliciesAccepted) {
      setState(() => _googleConsentWarning = true);
      final ctx = _legalConsentsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut,
          alignment: 0.4,
        );
      }
      return;
    }

    setState(() => _googleConsentWarning = false);

    final selected = await showGoogleAccountPicker(
      context,
      prefillEmail: _emailController.text.trim(),
      prefillName: _nameController.text.trim(),
    );
    if (selected == null || !mounted) return;

    setState(() => _isGoogleLoading = true);
    try {
      final result = await AuthService.continueWithGoogle(
        email: selected.email,
        name: selected.name,
        termsAccepted: _termsAccepted,
        privacyAccepted: _privacyAccepted,
      );
      if (!mounted) return;
      context.read<CartProvider>().resetSession();
      final auth = context.read<AuthProvider>();
      await auth.setUser(result.user);
      if (!mounted) return;

      auth.pushNotification(
        title: '🔥 ¡Bienvenido a Las Brazas, ${result.user.name}!',
        body: result.isNewUser
            ? 'Tu cuenta con Google fue activada al instante. Revisa tu correo con los Términos del Servicio, Condiciones de Reserva y Política de Privacidad.'
            : 'Iniciaste sesión correctamente con tu cuenta de Google.',
        category: 'promo',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            result.isNewUser
                ? '¡Cuenta creada con Google al instante, ${result.user.name}!'
                : '¡Bienvenido de nuevo con Google, ${result.user.name}!',
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_bothPoliciesAccepted) {
      setState(() => _googleConsentWarning = true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
        phone: _phoneController.text,
        terms: _termsAccepted,
        privacy: _privacyAccepted,
      );
      if (!mounted) return;
      context.read<CartProvider>().resetSession();
      final auth = context.read<AuthProvider>();
      await auth.setUser(user);
      if (!mounted) return;

      auth.pushNotification(
        title: '🔥 ¡Registro completado en Las Brazas!',
        body:
            'Bienvenido ${user.name}. Se registraron tus aceptaciones de Términos del Servicio y Política de Privacidad.',
        category: 'promo',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('¡Bienvenido a Las Brazas, ${user.name}!'),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const orangeAccent = Color(0xFFD85A1A);
    final emeraldAccent = Colors.teal.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        actions: [
          TextButton.icon(
            onPressed: () => _openLegalDocument(LegalDocType.terms),
            icon: const Icon(Icons.info_outline, size: 17),
            label: const Text(
              'Términos',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: const Color(0xFFE8832A),
            ),
            onPressed: () {
              context.read<AuthProvider>().toggleDarkMode(isDark);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Título (igual a Register.vue)
                const Center(child: BrandLogo(size: 108, borderRadius: 20)),
                const SizedBox(height: 12),
                const Text(
                  'Crear Cuenta en Las Brazas',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Regístrate para reservar mesas, gestionar tus pedidos y acceder a promociones',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Tarjeta "Activación Inteligente" (igual a Register.vue)
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.deepOrange.withValues(alpha: 0.14)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.deepOrange.withValues(alpha: 0.35)
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: orangeAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Activación Inteligente:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: orangeAccent,
                              ),
                            ),
                            const SizedBox(height: 3),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                                children: const [
                                  TextSpan(text: 'Si te registras con '),
                                  TextSpan(
                                    text: 'Google',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text:
                                        ', tu cuenta queda activada al instante y recibirás los ',
                                  ),
                                  TextSpan(
                                    text: '3 correos',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text:
                                        ' de Términos, Condiciones de Reserva y Política de Privacidad. Con correo manual recibirás además el enlace de verificación.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Advertencia si presionó Google sin marcar las 2 casillas
                if (_googleConsentWarning && !_bothPoliciesAccepted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Para registrarte con Google debes marcar primero las dos casillas de abajo: Términos y Condiciones y Política de Privacidad.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Botón Continuar con Google (arriba del formulario, igual al Web)
                GoogleContinueButton(
                  enabledStyle: _bothPoliciesAccepted,
                  loading: _isGoogleLoading,
                  onPressed: _handleGoogleRegisterClick,
                ),

                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'O REGÍSTRATE CON TU CORREO',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Nombre Completo *
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo *',
                    hintText: 'Ej: Marcelo Quiroga',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre completo es obligatorio.'
                      : null,
                ),
                const SizedBox(height: 14),

                // 2. Correo Electrónico *
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico *',
                    hintText: 'comensal@ejemplo.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El correo electrónico es obligatorio.';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Debe ingresar un correo electrónico válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. Teléfono Móvil (Opcional)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono Móvil',
                    hintText: '700-12345',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Contraseña * (Mínimo 8 caracteres, igual al Web)
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña *',
                    hintText: 'Mínimo 8 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'La contraseña es obligatoria.';
                    }
                    if (v.length < 8) {
                      return 'La contraseña debe contener al menos 8 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 5. Confirmar Contraseña * (igual al Web)
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Contraseña *',
                    hintText: 'Repite tu contraseña',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Debes confirmar tu contraseña.';
                    }
                    if (v != _passwordController.text) {
                      return 'Las contraseñas no coinciden.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Los 2 Checkboxes Obligatorios Separados (idénticos a Register.vue)
                Column(
                  key: _legalConsentsKey,
                  children: [
                    // Check 1: Términos y Condiciones
                    _legalCheckboxCard(
                      isDark: isDark,
                      checked: _termsAccepted,
                      highlightWarning:
                          _googleConsentWarning && !_termsAccepted,
                      activeColor: orangeAccent,
                      onChanged: (val) {
                        setState(() {
                          _termsAccepted = val;
                          if (_bothPoliciesAccepted) {
                            _googleConsentWarning = false;
                          }
                        });
                      },
                      prefixText: 'He leído y acepto los ',
                      linkText: 'Términos y Condiciones',
                      suffixText: ' del sistema de Restaurante Las Brazas. *',
                      onLinkTap: () => _openLegalDocument(LegalDocType.terms),
                    ),
                    const SizedBox(height: 10),

                    // Check 2: Política de Privacidad
                    _legalCheckboxCard(
                      isDark: isDark,
                      checked: _privacyAccepted,
                      highlightWarning:
                          _googleConsentWarning && !_privacyAccepted,
                      activeColor: emeraldAccent,
                      onChanged: (val) {
                        setState(() {
                          _privacyAccepted = val;
                          if (_bothPoliciesAccepted) {
                            _googleConsentWarning = false;
                          }
                        });
                      },
                      prefixText: 'He leído y acepto la ',
                      linkText: 'Política de Privacidad',
                      suffixText: ' y el tratamiento de mis datos personales. *',
                      onLinkTap: () => _openLegalDocument(LegalDocType.privacy),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Botón Submit — Deshabilitado hasta marcar AMBOS checks
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _bothPoliciesAccepted
                          ? orangeAccent
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        (!_bothPoliciesAccepted || _isLoading || _isGoogleLoading)
                            ? null
                            : _register,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(
                      _isLoading
                          ? 'Creando cuenta...'
                          : 'Registrarse y Crear Cuenta',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                if (!_bothPoliciesAccepted) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Debes aceptar los Términos y Condiciones y la Política de Privacidad para registrarte.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes una cuenta registrada?',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Inicia sesión aquí',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legalCheckboxCard({
    required bool isDark,
    required bool checked,
    required bool highlightWarning,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
    required String prefixText,
    required String linkText,
    required String suffixText,
    required VoidCallback onLinkTap,
  }) {
    final borderColor = highlightWarning
        ? Colors.amber.shade600
        : (checked
            ? activeColor.withValues(alpha: 0.7)
            : (isDark ? Colors.white12 : Colors.grey.shade300));
    final bgColor = checked
        ? activeColor.withValues(alpha: isDark ? 0.14 : 0.06)
        : (isDark ? const Color(0xFF1F2229) : Colors.grey.shade50);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: highlightWarning ? 2 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: checked,
                activeColor: activeColor,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.grey.shade200 : Colors.black87,
                    ),
                    children: [
                      TextSpan(text: prefixText),
                      TextSpan(
                        text: linkText,
                        style: TextStyle(
                          color: activeColor,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onLinkTap,
                      ),
                      TextSpan(text: suffixText),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

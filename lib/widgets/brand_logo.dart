import 'package:flutter/material.dart';

/// Widget oficial del logo "Las Brazas Steakhouse".
/// Cambia automáticamente entre el logo de modo claro (`logo_light.jpg`)
/// y el logo de modo oscuro (`logo_dark.jpg`) según el brillo activo del tema.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool circular;
  final bool? forceDark;
  final double borderRadius;

  const BrandLogo({
    super.key,
    this.size = 120,
    this.circular = false,
    this.forceDark,
    this.borderRadius = 20,
  });

  static String assetFor(BuildContext context, {bool? forceDark}) {
    final isDark =
        forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    return isDark
        ? 'assets/images/logo_dark.jpg'
        : 'assets/images/logo_light.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final assetPath = isDark
        ? 'assets/images/logo_dark.jpg'
        : 'assets/images/logo_light.jpg';

    if (circular) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE8832A).withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2025) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFFE8832A).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}


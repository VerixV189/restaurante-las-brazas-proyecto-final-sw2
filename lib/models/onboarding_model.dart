import 'package:flutter/material.dart';

class OnboardingModel {
  final String title;
  final String description;
  final IconData icon;

  OnboardingModel({
    required this.title,
    required this.description,
    required this.icon,
  });
}

final List<OnboardingModel> onboardingPages = [
  OnboardingModel(
    title: 'Bienvenido al Restaurante',
    description: 'Gestiona tu restaurante de manera fácil y rápida',
    icon: Icons.restaurant,
  ),
  OnboardingModel(
    title: 'Gestión de Pedidos',
    description: 'Recibe y administra los pedidos de tus mesas en tiempo real.',
    icon: Icons.receipt_long,
  ),
  OnboardingModel(
    title: 'Control de Inventario',
    description: 'Mantén control de tus productos y stock disponible.',
    icon: Icons.inventory,
  ),
];

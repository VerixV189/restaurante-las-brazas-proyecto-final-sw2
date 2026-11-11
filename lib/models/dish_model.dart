import 'package:restaurante_movil/constants/api_constants.dart';

class DishModel {
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final int prepTimeMinutes;
  final bool isAvailable;
  final bool isMeat;
  final List<String> meatCookingTerms;

  DishModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.prepTimeMinutes,
    required this.isAvailable,
    required this.isMeat,
    required this.meatCookingTerms,
  });

  factory DishModel.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image_url']?.toString();
    final fixedImage = rawImage?.replaceFirst(
      RegExp(r'^http://(localhost|127\.0\.0\.1):\d+'),
      ApiConstants.baseUrl,
    );

    final categoryObj = json['category'];
    final int resolvedCategoryId = (json['category_id'] as num?)?.toInt() ??
        (categoryObj is Map ? (categoryObj['id'] as num?)?.toInt() ?? 0 : 0);
    final String resolvedCategoryName = json['category_name']?.toString() ??
        (categoryObj is Map ? categoryObj['name']?.toString() ?? '' : '');

    final termsRaw = json['meat_cooking_terms'];
    final List<String> terms = termsRaw is List
        ? termsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return DishModel(
      id: (json['id'] as num).toInt(),
      categoryId: resolvedCategoryId,
      categoryName: resolvedCategoryName,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      imageUrl: fixedImage,
      prepTimeMinutes: (json['prep_time_minutes'] as num?)?.toInt() ?? 15,
      isAvailable: json['is_available'] ?? true,
      isMeat: json['is_meat'] ?? terms.isNotEmpty,
      meatCookingTerms: terms,
    );
  }
}

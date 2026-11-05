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
    return DishModel(
      id: json['id'],
      categoryId: json['category_id`'],
      categoryName: json['category_name'],
      name: json['name'],
      price: json['price'],
      prepTimeMinutes: json['prep_time_minutes'] ?? 0,
      isAvailable: json['is_available'] ?? true,
      isMeat: json['is_meat'] ?? false,
      meatCookingTerms: json['meat_cooking_terms'] ?? [],
    );
  }
}

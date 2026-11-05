class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final bool isActive;
  final int dishescount;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    required this.isActive,
    required this.dishescount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      description: json['description'],
      icon: json['icon'],
      isActive: json['is_active'] ?? true,
      dishescount: json['dishes_count'] ?? 0,
    );
  }
}

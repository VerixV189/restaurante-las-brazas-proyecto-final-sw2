import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/category_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/services/http_client.dart';

class MenuService {
  static Future<List<CategoryModel>> getCategories() async {
    final json = await HttpClient.get(ApiConstants.categories);
    return (json['data'] as List)
        .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  static Future<List<DishModel>> getDishes({
    int? categoryId,
    String? search,
  }) async {
    final query = <String, String>{};
    if (categoryId != null) {
      query['category_id'] = categoryId.toString();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final json = await HttpClient.get(
      ApiConstants.dishes,
      queryParameters: query.isEmpty ? null : query,
    );
    final dishes = (json['data'] as List)
        .map((d) => DishModel.fromJson(d as Map<String, dynamic>))
        .toList();
    if (categoryId == null) return dishes;
    return dishes.where((d) => d.categoryId == categoryId).toList();
  }

  static Future<DishModel> getDishDetail(int id) async {
    final json = await HttpClient.get(ApiConstants.dishById(id));
    return DishModel.fromJson(json['data'] as Map<String, dynamic>);
  }
}

import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/category_model.dart';
import 'package:restaurante_movil/models/dish_model.dart';
import 'package:restaurante_movil/services/http_client.dart';
import 'package:restaurante_movil/services/offline_cache_service.dart';

class MenuService {
  static Future<List<CategoryModel>> getCategories() async {
    try {
      final json = await HttpClient.get(ApiConstants.categories);
      final rawList = json['data'] as List? ?? [];
      await OfflineCacheService.instance.cacheCategories(rawList);
      return rawList
          .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await OfflineCacheService.instance.getCachedCategories();
      return cached.map(CategoryModel.fromJson).toList();
    }
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

    List<DishModel> dishes;
    try {
      final json = await HttpClient.get(
        ApiConstants.dishes,
        queryParameters: query.isEmpty ? null : query,
      );
      final rawList = json['data'] as List? ?? [];
      if (query.isEmpty) {
        await OfflineCacheService.instance.cacheDishes(rawList);
      }
      dishes = rawList
          .map((d) => DishModel.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await OfflineCacheService.instance.getCachedDishes();
      dishes = cached.map(DishModel.fromJson).toList();
    }

    if (categoryId != null) {
      dishes = dishes.where((d) => d.categoryId == categoryId).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      dishes = dishes
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              (d.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return dishes;
  }

  static Future<DishModel> getDishDetail(int id) async {
    try {
      final json = await HttpClient.get(ApiConstants.dishById(id));
      return DishModel.fromJson(json['data'] as Map<String, dynamic>);
    } catch (_) {
      final cached = await OfflineCacheService.instance.getCachedDishes();
      final match = cached.where((d) => d['id'] == id).toList();
      if (match.isNotEmpty) {
        return DishModel.fromJson(match.first);
      }
      return DishModel.fromJson(cached.first);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_cache_service.dart';
import '../domain/category_model.dart';
import 'categories_api.dart';

class CategoriesRepository {
  const CategoriesRepository({
    required CategoriesApi api,
    required LocalCacheService cache,
  }) : _api = api,
       _cache = cache;

  final CategoriesApi _api;
  final LocalCacheService _cache;

  Future<List<CategoryModel>> getCachedCategories() async {
    final List<Map<String, dynamic>>? raw = await _cache.readJsonList(
      LocalCacheService.keyCategories,
    );
    if (raw == null) {
      return const <CategoryModel>[];
    }
    return raw.map(CategoryModel.fromJson).toList();
  }

  Future<List<CategoryModel>> getCategories({
    CategoryType? type,
    bool includeArchived = false,
  }) async {
    final List<CategoryModel> list = await _api.getCategories(
      type: type,
      includeArchived: includeArchived,
    );
    if (type == null && !includeArchived) {
      await _cache.writeJsonList(
        LocalCacheService.keyCategories,
        list.map((CategoryModel c) => c.toJson()).toList(),
      );
    }
    return list;
  }

  Future<CategoryModel> createCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) {
    return _api.createCategory(
      name: name,
      type: type,
      icon: icon,
      color: color,
    );
  }

  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? icon,
    String? color,
    bool? isArchived,
    int? sortOrder,
  }) {
    return _api.updateCategory(
      id,
      name: name,
      icon: icon,
      color: color,
      isArchived: isArchived,
      sortOrder: sortOrder,
    );
  }

  Future<void> deleteCategory(String id) => _api.deleteCategory(id);
}

final Provider<CategoriesRepository> categoriesRepositoryProvider =
    Provider<CategoriesRepository>((Ref ref) {
      return CategoriesRepository(
        api: ref.watch(categoriesApiProvider),
        cache: ref.watch(localCacheServiceProvider),
      );
    });


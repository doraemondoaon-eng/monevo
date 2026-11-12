import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/categories_repository.dart';
import '../domain/category_model.dart';

class CategoriesState {
  const CategoriesState({
    this.items = const <CategoryModel>[],
    this.isLoading = false,
    this.includeArchived = false,
    this.error,
  });

  final List<CategoryModel> items;
  final bool isLoading;
  final bool includeArchived;
  final ApiException? error;

  List<CategoryModel> byType(
    CategoryType type, {
    bool activeOnly = false,
  }) {
    return items.where((CategoryModel c) {
      if (c.type != type) {
        return false;
      }
      if (activeOnly && c.isArchived) {
        return false;
      }
      return true;
    }).toList();
  }

  CategoryModel? findById(String? id) {
    if (id == null) {
      return null;
    }
    for (final CategoryModel item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  CategoriesState copyWith({
    List<CategoryModel>? items,
    bool? isLoading,
    bool? includeArchived,
    ApiException? error,
    bool clearError = false,
  }) {
    return CategoriesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      includeArchived: includeArchived ?? this.includeArchived,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CategoriesController extends StateNotifier<CategoriesState> {
  CategoriesController(this._repo, {required bool isAuthenticated})
    : super(const CategoriesState()) {
    if (isAuthenticated) {
      _hydrateAndLoad();
    }
  }

  final CategoriesRepository _repo;

  Future<void> _hydrateAndLoad() async {
    final List<CategoryModel> cached = await _repo.getCachedCategories();
    if (mounted && cached.isNotEmpty && state.items.isEmpty) {
      state = state.copyWith(items: cached);
    }
    await loadCategories();
  }

  Future<void> loadCategories({bool? includeArchived}) async {
    final bool targetIncludeArchived =
        includeArchived ?? state.includeArchived;
    state = state.copyWith(
      isLoading: true,
      includeArchived: targetIncludeArchived,
      clearError: true,
    );
    try {
      final List<CategoryModel> list = await _repo.getCategories(
        includeArchived: targetIncludeArchived,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        items: list,
        isLoading: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    required CategoryType type,
    required String icon,
    required String color,
  }) async {
    final CategoryModel created = await _repo.createCategory(
      name: name,
      type: type,
      icon: icon,
      color: color,
    );
    state = state.copyWith(
      items: <CategoryModel>[...state.items, created],
    );
    return created;
  }

  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? icon,
    String? color,
    bool? isArchived,
    int? sortOrder,
  }) async {
    final CategoryModel updated = await _repo.updateCategory(
      id,
      name: name,
      icon: icon,
      color: color,
      isArchived: isArchived,
      sortOrder: sortOrder,
    );
    final List<CategoryModel> next = state.items
        .map((CategoryModel c) => c.id == id ? updated : c)
        .where((CategoryModel c) => state.includeArchived || !c.isArchived)
        .toList();
    state = state.copyWith(items: next);
    return updated;
  }

  Future<void> deleteCategory(String id) async {
    await _repo.deleteCategory(id);
    state = state.copyWith(
      items: state.items.where((CategoryModel c) => c.id != id).toList(),
    );
  }
}

final StateNotifierProvider<CategoriesController, CategoriesState>
categoriesControllerProvider =
    StateNotifierProvider<CategoriesController, CategoriesState>((Ref ref) {
      final bool isAuthenticated = ref.watch(
        authControllerProvider.select((AuthState s) => s.isAuthenticated),
      );
      return CategoriesController(
        ref.watch(categoriesRepositoryProvider),
        isAuthenticated: isAuthenticated,
      );
    });

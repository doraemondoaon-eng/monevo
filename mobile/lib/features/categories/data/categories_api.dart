import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/category_model.dart';

class CategoriesApi {
  const CategoriesApi(this._dio);

  final Dio _dio;

  Future<List<CategoryModel>> getCategories({
    CategoryType? type,
    bool includeArchived = false,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'includeArchived': includeArchived.toString(),
      };
      if (type != null) {
        query['type'] = type.apiValue;
      }
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/categories',
            queryParameters: query,
          );
      final List<dynamic> list =
          (response.data?['data'] as List<dynamic>?) ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CategoryModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'name': name.trim(),
        'type': type.apiValue,
      };
      if (icon != null && icon.isNotEmpty) {
        body['icon'] = icon;
      }
      if (color != null && color.isNotEmpty) {
        body['color'] = color;
      }
      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>('/categories', data: body);
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return CategoryModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? icon,
    String? color,
    bool? isArchived,
    int? sortOrder,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{};
      if (name != null) {
        body['name'] = name.trim();
      }
      if (icon != null) {
        body['icon'] = icon;
      }
      if (color != null) {
        body['color'] = color;
      }
      if (isArchived != null) {
        body['isArchived'] = isArchived;
      }
      if (sortOrder != null) {
        body['sortOrder'] = sortOrder;
      }
      final Response<Map<String, dynamic>> response =
          await _dio.patch<Map<String, dynamic>>(
            '/categories/$id',
            data: body,
          );
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return CategoryModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _dio.delete<void>(
        '/categories/$id',
        options: Options(
          validateStatus: (int? status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<CategoriesApi> categoriesApiProvider =
    Provider<CategoriesApi>((Ref ref) {
      return CategoriesApi(ref.watch(dioProvider));
    });

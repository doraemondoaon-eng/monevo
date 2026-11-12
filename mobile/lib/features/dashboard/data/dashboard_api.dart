import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/dashboard_models.dart';

class DashboardApi {
  const DashboardApi(this._dio);

  final Dio _dio;

  Future<DashboardSummary> getSummary({String? month}) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{};
      if (month != null && month.isNotEmpty) {
        query['month'] = month;
      }
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/dashboard/summary',
            queryParameters: query,
          );
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return DashboardSummary.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CashflowPoint>> getCashflow({int months = 6}) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/dashboard/cashflow',
            queryParameters: <String, dynamic>{'months': months},
          );
      final List<dynamic> list =
          (response.data?['data'] as List<dynamic>?) ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CashflowPoint.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DailyCashflowPoint>> getDailyCashflow({int days = 14}) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/dashboard/daily-cashflow',
            queryParameters: <String, dynamic>{'days': days},
          );
      final List<dynamic> list =
          (response.data?['data'] as List<dynamic>?) ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(DailyCashflowPoint.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<YearlyCashflowPoint>> getYearlyCashflow({int years = 5}) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/dashboard/yearly-cashflow',
            queryParameters: <String, dynamic>{'years': years},
          );
      final List<dynamic> list =
          (response.data?['data'] as List<dynamic>?) ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(YearlyCashflowPoint.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AccountBalancesOverview> getAccountBalancesOverview() async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>('/dashboard/account-balances');
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AccountBalancesOverview.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CategoryBreakdown> getCategoryBreakdown({
    String type = 'expense',
    String? month,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{'type': type};
      if (month != null && month.isNotEmpty) {
        query['month'] = month;
      }
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/dashboard/categories',
            queryParameters: query,
          );
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return CategoryBreakdown.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<NetWorthPoint>> getNetWorthTrend({int days = 30}) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/dashboard/net-worth-trend',
            queryParameters: <String, dynamic>{'days': days},
          );
      final List<dynamic> list =
          (response.data?['data'] as List<dynamic>?) ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(NetWorthPoint.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<DashboardApi> dashboardApiProvider =
    Provider<DashboardApi>((Ref ref) {
      return DashboardApi(ref.watch(dioProvider));
    });

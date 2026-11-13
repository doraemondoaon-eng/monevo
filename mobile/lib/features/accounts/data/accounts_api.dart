import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/account_model.dart';

class AccountsApi {
  const AccountsApi(this._dio);

  final Dio _dio;

  Future<List<AccountModel>> getAccounts({
    bool includeArchived = false,
  }) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/accounts',
            queryParameters: <String, dynamic>{
              'includeArchived': includeArchived.toString(),
            },
          );
      final List<dynamic> list =
          (response.data?['data'] as List<dynamic>?) ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AccountModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AccountModel> getAccount(String id) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>('/accounts/$id');
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AccountModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AccountModel> createAccount({
    required String name,
    required AccountType type,
    String? institution,
    String? accountNumberLast4,
    String currency = 'THB',
    int openingBalance = 0,
    String? color,
    String? icon,
    bool includeInNetWorth = true,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'name': name.trim(),
        'type': type.apiValue,
        'currency': currency,
        'openingBalance': openingBalance,
        'includeInNetWorth': includeInNetWorth,
      };
      if (institution != null && institution.trim().isNotEmpty) {
        body['institution'] = institution.trim();
      }
      if (accountNumberLast4 != null && accountNumberLast4.trim().isNotEmpty) {
        body['accountNumberLast4'] = accountNumberLast4.trim();
      }
      if (color != null && color.isNotEmpty) {
        body['color'] = color;
      }
      if (icon != null && icon.isNotEmpty) {
        body['icon'] = icon;
      }

      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>('/accounts', data: body);
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AccountModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AccountModel> updateAccount(
    String id, {
    String? name,
    AccountType? type,
    String? institution,
    bool clearInstitution = false,
    String? accountNumberLast4,
    bool clearLast4 = false,
    int? openingBalance,
    String? color,
    String? icon,
    bool? includeInNetWorth,
    bool? isArchived,
    int? sortOrder,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{};
      if (name != null) {
        body['name'] = name.trim();
      }
      if (type != null) {
        body['type'] = type.apiValue;
      }
      if (clearInstitution) {
        body['institution'] = null;
      } else if (institution != null) {
        body['institution'] =
            institution.trim().isEmpty ? null : institution.trim();
      }
      if (clearLast4) {
        body['accountNumberLast4'] = null;
      } else if (accountNumberLast4 != null) {
        body['accountNumberLast4'] = accountNumberLast4.trim().isEmpty
            ? null
            : accountNumberLast4.trim();
      }
      if (openingBalance != null) {
        body['openingBalance'] = openingBalance;
      }
      if (color != null) {
        body['color'] = color;
      }
      if (icon != null) {
        body['icon'] = icon;
      }
      if (includeInNetWorth != null) {
        body['includeInNetWorth'] = includeInNetWorth;
      }
      if (isArchived != null) {
        body['isArchived'] = isArchived;
      }
      if (sortOrder != null) {
        body['sortOrder'] = sortOrder;
      }

      final Response<Map<String, dynamic>> response =
          await _dio.patch<Map<String, dynamic>>('/accounts/$id', data: body);
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AccountModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteAccount(String id, {bool cascade = false}) async {
    try {
      await _dio.delete<void>(
        '/accounts/$id',
        queryParameters: cascade ? <String, dynamic>{'cascade': 'true'} : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AccountModel> reconcileAccount(String id) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>('/accounts/$id/reconcile');
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AccountModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<AccountsApi> accountsApiProvider =
    Provider<AccountsApi>((Ref ref) {
      return AccountsApi(ref.watch(dioProvider));
    });

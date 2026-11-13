import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/transaction_model.dart';

class TransactionsApi {
  const TransactionsApi(this._dio);

  final Dio _dio;

  Future<PaginatedTransactions> getTransactions({
    TransactionFilter? filter,
    int limit = AppConfig.defaultPageSize,
    String? cursor,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null && cursor.isNotEmpty) {
        query['cursor'] = cursor;
      }
      if (filter != null) {
        if (filter.type != null) {
          query['type'] = filter.type!.apiValue;
        }
        if (filter.accountId != null && filter.accountId!.isNotEmpty) {
          query['accountId'] = filter.accountId;
        }
        if (filter.categoryId != null && filter.categoryId!.isNotEmpty) {
          query['categoryId'] = filter.categoryId;
        }
        if (filter.from != null) {
          query['from'] = filter.from!.toUtc().toIso8601String();
        }
        if (filter.to != null) {
          query['to'] = filter.to!.toUtc().toIso8601String();
        }
        if (filter.query.trim().isNotEmpty) {
          query['q'] = filter.query.trim();
        }
      }

      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
            '/transactions',
            queryParameters: query,
          );
      return PaginatedTransactions.fromJson(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TransactionModel> getTransaction(String id) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>('/transactions/$id');
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return TransactionModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TransactionModel> createTransaction({
    required TransactionType type,
    required int amount,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required DateTime occurredAt,
    String? payee,
    String? note,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'type': type.apiValue,
        'amount': amount,
        'accountId': accountId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
      };
      if (type == TransactionType.transfer && toAccountId != null) {
        body['toAccountId'] = toAccountId;
      }
      if (type != TransactionType.transfer &&
          categoryId != null &&
          categoryId.isNotEmpty) {
        body['categoryId'] = categoryId;
      }
      if (payee != null && payee.trim().isNotEmpty) {
        body['payee'] = payee.trim();
      }
      if (note != null && note.trim().isNotEmpty) {
        body['note'] = note.trim();
      }

      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>('/transactions', data: body);
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return TransactionModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TransactionModel> updateTransaction(
    String id, {
    required TransactionType type,
    required int amount,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required DateTime occurredAt,
    String? payee,
    String? note,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'type': type.apiValue,
        'amount': amount,
        'accountId': accountId,
        'toAccountId': type == TransactionType.transfer ? toAccountId : null,
        'categoryId': type == TransactionType.transfer ? null : categoryId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'payee': (payee == null || payee.trim().isEmpty) ? null : payee.trim(),
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      };

      final Response<Map<String, dynamic>> response =
          await _dio.patch<Map<String, dynamic>>(
            '/transactions/$id',
            data: body,
          );
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return TransactionModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _dio.delete<void>(
        '/transactions/$id',
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

final Provider<TransactionsApi> transactionsApiProvider =
    Provider<TransactionsApi>((Ref ref) {
      return TransactionsApi(ref.watch(dioProvider));
    });

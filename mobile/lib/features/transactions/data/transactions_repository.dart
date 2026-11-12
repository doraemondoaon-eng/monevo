import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/local_cache_service.dart';
import '../domain/transaction_model.dart';
import 'transactions_api.dart';

class TransactionsRepository {
  const TransactionsRepository({
    required TransactionsApi api,
    required LocalCacheService cache,
  }) : _api = api,
       _cache = cache;

  final TransactionsApi _api;
  final LocalCacheService _cache;

  Future<List<TransactionModel>> getCachedRecentTransactions() async {
    final List<Map<String, dynamic>>? raw = await _cache.readJsonList(
      LocalCacheService.keyRecentTransactions,
    );
    if (raw == null) {
      return const <TransactionModel>[];
    }
    return raw.map(TransactionModel.fromJson).toList();
  }

  Future<PaginatedTransactions> getTransactions({
    TransactionFilter? filter,
    int limit = AppConfig.defaultPageSize,
    String? cursor,
  }) async {
    final PaginatedTransactions page = await _api.getTransactions(
      filter: filter,
      limit: limit,
      cursor: cursor,
    );
    final bool isDefaultFirstPage =
        (cursor == null || cursor.isEmpty) &&
        (filter == null || !filter.hasActiveFilters);
    if (isDefaultFirstPage) {
      await _cache.writeJsonList(
        LocalCacheService.keyRecentTransactions,
        page.items.map((TransactionModel t) => t.toJson()).toList(),
      );
    }
    return page;
  }

  Future<TransactionModel> getTransaction(String id) => _api.getTransaction(id);

  Future<TransactionModel> createTransaction({
    required TransactionType type,
    required int amount,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required DateTime occurredAt,
    String? payee,
    String? note,
  }) {
    return _api.createTransaction(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      occurredAt: occurredAt,
      payee: payee,
      note: note,
    );
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
  }) {
    return _api.updateTransaction(
      id,
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      occurredAt: occurredAt,
      payee: payee,
      note: note,
    );
  }

  Future<void> deleteTransaction(String id) => _api.deleteTransaction(id);
}

final Provider<TransactionsRepository> transactionsRepositoryProvider =
    Provider<TransactionsRepository>((Ref ref) {
      return TransactionsRepository(
        api: ref.watch(transactionsApiProvider),
        cache: ref.watch(localCacheServiceProvider),
      );
    });


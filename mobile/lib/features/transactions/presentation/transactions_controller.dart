import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/data_sync_controller.dart';
import '../../accounts/presentation/accounts_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction_model.dart';

class TransactionsState {
  const TransactionsState({
    this.items = const <TransactionModel>[],
    this.filter = const TransactionFilter(),
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<TransactionModel> items;
  final TransactionFilter filter;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final ApiException? error;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  TransactionsState copyWith({
    List<TransactionModel>? items,
    TransactionFilter? filter,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    ApiException? error,
    bool clearError = false,
  }) {
    return TransactionsState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TransactionsController extends StateNotifier<TransactionsState> {
  TransactionsController({
    required TransactionsRepository repo,
    required this.onTransactionEffect,
    required this.onSilentDashboardSync,
    required this.onEnqueueOfflineTransaction,
    required this.onSyncSuccess,
    required bool isAuthenticated,
  }) : _repo = repo,
       super(const TransactionsState()) {
    if (isAuthenticated) {
      _hydrateAndLoad();
    }
  }

  final TransactionsRepository _repo;
  final void Function(TransactionModel tx, int direction) onTransactionEffect;
  final void Function() onSilentDashboardSync;
  final Future<TransactionModel> Function({
    required TransactionType type,
    required int amount,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required DateTime occurredAt,
    String? payee,
    String? note,
  }) onEnqueueOfflineTransaction;
  final void Function() onSyncSuccess;

  Future<void> _hydrateAndLoad() async {
    final List<TransactionModel> cached =
        await _repo.getCachedRecentTransactions();
    if (mounted && cached.isNotEmpty && state.items.isEmpty) {
      state = state.copyWith(items: cached);
    }
    await loadInitial();
  }

  Future<void> loadInitial({TransactionFilter? newFilter}) async {
    final TransactionFilter activeFilter = newFilter ?? state.filter;
    state = state.copyWith(
      filter: activeFilter,
      isLoading: true,
      clearCursor: true,
      clearError: true,
    );

    try {
      final PaginatedTransactions page = await _repo.getTransactions(
        filter: activeFilter,
        limit: AppConfig.defaultPageSize,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
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

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final PaginatedTransactions page = await _repo.getTransactions(
        filter: state.filter,
        cursor: state.nextCursor,
        limit: AppConfig.defaultPageSize,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        items: <TransactionModel>[...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Future<void> updateFilter(TransactionFilter filter) async {
    await loadInitial(newFilter: filter);
  }

  Future<void> clearFilters() async {
    await loadInitial(newFilter: const TransactionFilter());
  }

  bool _matchesFilter(TransactionModel tx, TransactionFilter f) {
    if (f.type != null && tx.type != f.type) {
      return false;
    }
    if (f.accountId != null &&
        tx.accountId != f.accountId &&
        tx.toAccountId != f.accountId) {
      return false;
    }
    if (f.categoryId != null && tx.categoryId != f.categoryId) {
      return false;
    }
    if (f.from != null && tx.occurredAt.isBefore(f.from!)) {
      return false;
    }
    if (f.to != null && !tx.occurredAt.isBefore(f.to!)) {
      return false;
    }
    if (f.query.trim().isNotEmpty) {
      final String q = f.query.trim().toLowerCase();
      final bool inPayee = (tx.payee ?? '').toLowerCase().contains(q);
      final bool inNote = (tx.note ?? '').toLowerCase().contains(q);
      if (!inPayee && !inNote) {
        return false;
      }
    }
    return true;
  }

  void replaceOfflineTempTransaction({
    required String localTempId,
    required TransactionModel syncedTransaction,
  }) {
    final List<TransactionModel> withoutTemp = state.items
        .where((TransactionModel t) => t.id != localTempId)
        .toList();
    if (_matchesFilter(syncedTransaction, state.filter)) {
      state = state.copyWith(
        items: _insertSorted(withoutTemp, syncedTransaction),
      );
    } else {
      state = state.copyWith(items: withoutTemp);
    }
  }

  List<TransactionModel> _insertSorted(
    List<TransactionModel> list,
    TransactionModel item,
  ) {
    final List<TransactionModel> next = <TransactionModel>[
      item,
      ...list.where((TransactionModel t) => t.id != item.id),
    ];
    next.sort((TransactionModel a, TransactionModel b) {
      final int cmp = b.occurredAt.compareTo(a.occurredAt);
      return cmp != 0 ? cmp : b.id.compareTo(a.id);
    });
    return next;
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
      final TransactionModel created = await _repo.createTransaction(
        type: type,
        amount: amount,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        occurredAt: occurredAt,
        payee: payee,
        note: note,
      );
      // Section 10 Performance Optimization:
      // Update the in-memory list and account balances in-place without triggering
      // a full-app reload or resetting pagination state.
      if (_matchesFilter(created, state.filter)) {
        state = state.copyWith(items: _insertSorted(state.items, created));
      }
      onTransactionEffect(created, 1);
      onSilentDashboardSync();
      onSyncSuccess();
      return created;
    } on ApiException catch (e) {
      // Section 13 Offline Resilience:
      // If internet connectivity drops while saving a transaction, enqueue into
      // persistent Local Storage so zero financial data or local slip attachment
      // is lost.
      if (e.isConnectivityError) {
        final TransactionModel offlineTx = await onEnqueueOfflineTransaction(
          type: type,
          amount: amount,
          accountId: accountId,
          toAccountId: toAccountId,
          categoryId: categoryId,
          occurredAt: occurredAt,
          payee: payee,
          note: note,
        );
        if (_matchesFilter(offlineTx, state.filter)) {
          state = state.copyWith(items: _insertSorted(state.items, offlineTx));
        }
        onTransactionEffect(offlineTx, 1);
        return offlineTx;
      }
      rethrow;
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
    TransactionModel? previous;
    for (final TransactionModel item in state.items) {
      if (item.id == id) {
        previous = item;
        break;
      }
    }

    final TransactionModel updated = await _repo.updateTransaction(
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

    if (previous != null) {
      onTransactionEffect(previous, -1);
    }
    onTransactionEffect(updated, 1);

    final List<TransactionModel> withoutOld = state.items
        .where((TransactionModel t) => t.id != id)
        .toList();
    state = state.copyWith(
      items: _matchesFilter(updated, state.filter)
          ? _insertSorted(withoutOld, updated)
          : withoutOld,
    );
    onSilentDashboardSync();
    return updated;
  }

  Future<void> deleteTransaction(String id) async {
    TransactionModel? removed;
    for (final TransactionModel item in state.items) {
      if (item.id == id) {
        removed = item;
        break;
      }
    }
    await _repo.deleteTransaction(id);
    state = state.copyWith(
      items: state.items.where((TransactionModel t) => t.id != id).toList(),
    );
    if (removed != null) {
      onTransactionEffect(removed, -1);
    }
    onSilentDashboardSync();
  }
}

final StateNotifierProvider<TransactionsController, TransactionsState>
transactionsControllerProvider =
    StateNotifierProvider<TransactionsController, TransactionsState>((Ref ref) {
      final bool isAuthenticated = ref.watch(
        authControllerProvider.select((AuthState s) => s.isAuthenticated),
      );
      return TransactionsController(
        repo: ref.watch(transactionsRepositoryProvider),
        isAuthenticated: isAuthenticated,
        onTransactionEffect: (TransactionModel tx, int direction) {
          final AccountsController accountsCtrl = ref.read(
            accountsControllerProvider.notifier,
          );
          if (tx.type == TransactionType.income) {
            accountsCtrl.applyBalanceDeltaInPlace(
              accountId: tx.accountId,
              deltaSatang: tx.amount * direction,
            );
          } else if (tx.type == TransactionType.expense) {
            accountsCtrl.applyBalanceDeltaInPlace(
              accountId: tx.accountId,
              deltaSatang: -tx.amount * direction,
            );
          } else if (tx.type == TransactionType.transfer) {
            accountsCtrl.applyBalanceDeltaInPlace(
              accountId: tx.accountId,
              deltaSatang: -tx.amount * direction,
            );
            if (tx.toAccountId != null) {
              accountsCtrl.applyBalanceDeltaInPlace(
                accountId: tx.toAccountId!,
                deltaSatang: tx.amount * direction,
              );
            }
          }
        },
        onSilentDashboardSync: () {
          ref.read(dashboardControllerProvider.notifier).refresh(silent: true);
        },
        onEnqueueOfflineTransaction: ({
          required TransactionType type,
          required int amount,
          required String accountId,
          String? toAccountId,
          String? categoryId,
          required DateTime occurredAt,
          String? payee,
          String? note,
        }) {
          return ref
              .read(dataSyncControllerProvider.notifier)
              .enqueueOfflineTransaction(
                type: type,
                amount: amount,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                occurredAt: occurredAt,
                payee: payee,
                note: note,
              );
        },
        onSyncSuccess: () {
          ref.read(dataSyncControllerProvider.notifier).markSyncedNow();
        },
      );
    });

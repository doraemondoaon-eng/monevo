import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/accounts/presentation/accounts_controller.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/categories/presentation/categories_controller.dart';
import '../../features/dashboard/presentation/dashboard_controller.dart';
import '../../features/transactions/data/transactions_repository.dart';
import '../../features/transactions/domain/transaction_model.dart';
import '../../features/transactions/presentation/transactions_controller.dart';
import '../network/api_exception.dart';
import '../storage/local_image_storage_service.dart';

/// Section 13 Data Synchronization Status:
/// Tracks Cloud-to-Device synchronization of financial records & accounts,
/// offline pending queue persistence, and retry status.
enum SyncStage {
  synced,
  syncing,
  offlinePending,
  syncError,
}

class PendingTransactionDraft {
  const PendingTransactionDraft({
    required this.localTempId,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.occurredAt,
    this.payee,
    this.note,
    required this.createdAt,
  });

  factory PendingTransactionDraft.fromJson(Map<String, dynamic> json) {
    return PendingTransactionDraft(
      localTempId: (json['localTempId'] ?? '').toString(),
      type: TransactionType.fromApi(json['type']?.toString()),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      accountId: (json['accountId'] ?? '').toString(),
      toAccountId: json['toAccountId']?.toString(),
      categoryId: json['categoryId']?.toString(),
      occurredAt:
          DateTime.tryParse((json['occurredAt'] ?? '').toString()) ??
          DateTime.now(),
      payee: json['payee']?.toString(),
      note: json['note']?.toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String localTempId;
  final TransactionType type;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final DateTime occurredAt;
  final String? payee;
  final String? note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'localTempId': localTempId,
    'type': type.apiValue,
    'amount': amount,
    'accountId': accountId,
    'toAccountId': toAccountId,
    'categoryId': categoryId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'payee': payee,
    'note': note,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  TransactionModel toOptimisticTransactionModel() {
    return TransactionModel(
      id: localTempId,
      type: type,
      amount: amount,
      currency: 'THB',
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      occurredAt: occurredAt,
      payee: payee,
      note: note,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }
}

class DataSyncState {
  const DataSyncState({
    this.stage = SyncStage.synced,
    this.pendingQueue = const <PendingTransactionDraft>[],
    this.lastSyncedAt,
    this.retryAttemptCount = 0,
    this.lastErrorMessage,
  });

  final SyncStage stage;
  final List<PendingTransactionDraft> pendingQueue;
  final DateTime? lastSyncedAt;
  final int retryAttemptCount;
  final String? lastErrorMessage;

  int get pendingCount => pendingQueue.length;
  bool get hasPendingOfflineItems => pendingQueue.isNotEmpty;
  bool get isSyncing => stage == SyncStage.syncing;

  DataSyncState copyWith({
    SyncStage? stage,
    List<PendingTransactionDraft>? pendingQueue,
    DateTime? lastSyncedAt,
    int? retryAttemptCount,
    String? lastErrorMessage,
    bool clearError = false,
  }) {
    return DataSyncState(
      stage: stage ?? this.stage,
      pendingQueue: pendingQueue ?? this.pendingQueue,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      retryAttemptCount: retryAttemptCount ?? this.retryAttemptCount,
      lastErrorMessage: clearError
          ? null
          : (lastErrorMessage ?? this.lastErrorMessage),
    );
  }
}

/// Section 13 Data Synchronization Controller:
/// - Syncs income/expense/transfer records & bank accounts via Backend API.
/// - Strictly NEVER syncs transaction slip images or backup files to Cloud.
/// - Persists offline-recorded transactions in Local Storage (`pendingQueue`)
///   so zero data is lost when internet connectivity drops.
/// - Supports automatic exponential-backoff retry and manual Retry/Sync.
class DataSyncController extends StateNotifier<DataSyncState> {
  DataSyncController(this._ref) : super(const DataSyncState()) {
    _hydrateState();
  }

  final Ref _ref;
  static const String _pendingQueueKey = 'monevo.sync.pending_queue_v1';
  static const String _lastSyncedAtKey = 'monevo.sync.last_synced_at_v1';

  Future<void> _hydrateState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? rawQueue = prefs.getString(_pendingQueueKey);
      final String? rawLastSync = prefs.getString(_lastSyncedAtKey);

      final List<PendingTransactionDraft> loadedQueue =
          <PendingTransactionDraft>[];
      if (rawQueue != null && rawQueue.isNotEmpty) {
        final Object? decoded = jsonDecode(rawQueue);
        if (decoded is List<dynamic>) {
          for (final dynamic item in decoded) {
            if (item is Map<String, dynamic>) {
              loadedQueue.add(PendingTransactionDraft.fromJson(item));
            }
          }
        }
      }

      final DateTime? lastSynced = rawLastSync != null
          ? DateTime.tryParse(rawLastSync)
          : null;

      if (!mounted) {
        return;
      }

      state = state.copyWith(
        pendingQueue: loadedQueue,
        lastSyncedAt: lastSynced ?? DateTime.now(),
        stage: loadedQueue.isNotEmpty
            ? SyncStage.offlinePending
            : SyncStage.synced,
      );

      final bool isAuthenticated = _ref.read(authControllerProvider).isAuthenticated;
      if (isAuthenticated && loadedQueue.isNotEmpty) {
        await syncAllAndFlushOfflineQueue();
      }
    } catch (_) {
      // Ignore hydration errors on cold start.
    }
  }

  Future<void> _persistQueue(List<PendingTransactionDraft> queue) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> serialized = queue
        .map((PendingTransactionDraft d) => d.toJson())
        .toList();
    await prefs.setString(_pendingQueueKey, jsonEncode(serialized));
  }

  Future<void> _persistLastSyncedAt(DateTime timestamp) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncedAtKey, timestamp.toUtc().toIso8601String());
  }

  /// Enqueues a transaction created while offline into persistent Local Storage
  /// so no financial data is lost when internet connection drops.
  Future<TransactionModel> enqueueOfflineTransaction({
    required TransactionType type,
    required int amount,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required DateTime occurredAt,
    String? payee,
    String? note,
  }) async {
    final DateTime now = DateTime.now();
    final String localTempId =
        'offline_tx_${now.microsecondsSinceEpoch}';
    final PendingTransactionDraft draft = PendingTransactionDraft(
      localTempId: localTempId,
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      occurredAt: occurredAt,
      payee: payee,
      note: note,
      createdAt: now,
    );

    final List<PendingTransactionDraft> nextQueue = <PendingTransactionDraft>[
      ...state.pendingQueue,
      draft,
    ];
    await _persistQueue(nextQueue);
    if (mounted) {
      state = state.copyWith(
        stage: SyncStage.offlinePending,
        pendingQueue: nextQueue,
        clearError: true,
      );
    }
    return draft.toOptimisticTransactionModel();
  }

  /// Marks a successful online transaction/account operation as synced.
  Future<void> markSyncedNow() async {
    final DateTime now = DateTime.now();
    await _persistLastSyncedAt(now);
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      stage: state.pendingQueue.isNotEmpty
          ? SyncStage.offlinePending
          : SyncStage.synced,
      lastSyncedAt: now,
      retryAttemptCount: 0,
      clearError: true,
    );
  }

  /// Flushes any offline-queued transactions to the Backend API (with automatic
  /// retry up to [maxRetries] on transient failures) and pulls the latest
  /// financial data (accounts, categories, transactions, dashboard summary)
  /// from the Cloud Server.
  ///
  /// Note: Transaction slip images and local backup files are NEVER uploaded
  /// to the Cloud Server (Section 3 & Section 13).
  Future<bool> syncAllAndFlushOfflineQueue({int maxRetries = 2}) async {
    if (state.isSyncing) {
      return false;
    }

    state = state.copyWith(
      stage: SyncStage.syncing,
      clearError: true,
    );

    final TransactionsRepository txRepo = _ref.read(
      transactionsRepositoryProvider,
    );
    final LocalImageAttachmentsController imageCtrl = _ref.read(
      localImageAttachmentsProvider.notifier,
    );
    final TransactionsController txCtrl = _ref.read(
      transactionsControllerProvider.notifier,
    );

    List<PendingTransactionDraft> remaining = List<PendingTransactionDraft>.from(
      state.pendingQueue,
    );

    int attempt = 0;
    while (attempt <= maxRetries) {
      try {
        // 1. Flush any offline-queued transactions in chronological order
        while (remaining.isNotEmpty) {
          final PendingTransactionDraft draft = remaining.first;
          final TransactionModel created = await txRepo.createTransaction(
            type: draft.type,
            amount: draft.amount,
            accountId: draft.accountId,
            toAccountId: draft.toAccountId,
            categoryId: draft.categoryId,
            occurredAt: draft.occurredAt,
            payee: draft.payee,
            note: draft.note,
          );

          // Rebind any local slip image attached to draft.localTempId to created.id
          await imageCtrl.rebindTransactionId(
            oldTransactionId: draft.localTempId,
            newTransactionId: created.id,
          );

          // Replace temporary item in TransactionsController in-place
          txCtrl.replaceOfflineTempTransaction(
            localTempId: draft.localTempId,
            syncedTransaction: created,
          );

          remaining.removeAt(0);
          await _persistQueue(remaining);
          if (mounted) {
            state = state.copyWith(pendingQueue: List<PendingTransactionDraft>.from(remaining));
          }
        }

        // 2. Pull latest financial records & accounts from Backend API
        await Future.wait<void>(<Future<void>>[
          _ref.read(accountsControllerProvider.notifier).loadAccounts(),
          _ref.read(categoriesControllerProvider.notifier).loadCategories(),
          _ref.read(transactionsControllerProvider.notifier).loadInitial(),
          _ref.read(dashboardControllerProvider.notifier).refresh(silent: true),
        ]);

        final DateTime syncedAt = DateTime.now();
        await _persistLastSyncedAt(syncedAt);
        if (mounted) {
          state = state.copyWith(
            stage: SyncStage.synced,
            pendingQueue: const <PendingTransactionDraft>[],
            lastSyncedAt: syncedAt,
            retryAttemptCount: 0,
            clearError: true,
          );
        }
        return true;
      } on ApiException catch (e) {
        attempt += 1;
        if (attempt <= maxRetries && e.isConnectivityError) {
          if (mounted) {
            state = state.copyWith(retryAttemptCount: attempt);
          }
          await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        if (mounted) {
          state = state.copyWith(
            stage: remaining.isNotEmpty
                ? SyncStage.offlinePending
                : SyncStage.syncError,
            pendingQueue: remaining,
            retryAttemptCount: attempt,
            lastErrorMessage: e.message,
          );
        }
        return false;
      } catch (e) {
        if (mounted) {
          state = state.copyWith(
            stage: remaining.isNotEmpty
                ? SyncStage.offlinePending
                : SyncStage.syncError,
            pendingQueue: remaining,
            lastErrorMessage: e.toString(),
          );
        }
        return false;
      }
    }
    return false;
  }
}

final StateNotifierProvider<DataSyncController, DataSyncState>
dataSyncControllerProvider =
    StateNotifierProvider<DataSyncController, DataSyncState>((Ref ref) {
      return DataSyncController(ref);
    });


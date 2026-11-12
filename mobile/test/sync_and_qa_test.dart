import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/network/api_exception.dart';
import 'package:monevo/core/storage/local_file_driver_stub.dart';
import 'package:monevo/core/storage/local_image_storage_service.dart';
import 'package:monevo/core/sync/data_sync_controller.dart';
import 'package:monevo/features/dashboard/domain/dashboard_models.dart';
import 'package:monevo/features/transactions/data/transactions_repository.dart';
import 'package:monevo/features/transactions/domain/transaction_model.dart';
import 'package:monevo/features/transactions/presentation/transactions_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineSimulatingTransactionsRepo extends TransactionsRepository {
  _OfflineSimulatingTransactionsRepo() : super(Dio());

  bool isOffline = false;
  int serverSeq = 1;

  @override
  Future<List<TransactionModel>> getCachedRecentTransactions() async {
    return <TransactionModel>[];
  }

  @override
  Future<PaginatedTransactions> getTransactions({
    TransactionFilter filter = const TransactionFilter(),
    String? cursor,
    int limit = 25,
  }) async {
    return const PaginatedTransactions(
      items: <TransactionModel>[],
      nextCursor: null,
    );
  }

  @override
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
    if (isOffline) {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach server',
      );
    }
    final DateTime now = DateTime.now().toUtc();
    return TransactionModel(
      id: 'srv-uuid-${serverSeq++}',
      type: type,
      amount: amount,
      currency: 'THB',
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      occurredAt: occurredAt,
      payee: payee,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }
}

void main() {
  group('Section 13 & 14 QA: Offline Disconnection, Sync & Incremental Updates', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('ApiException.isConnectivityError identifies NETWORK_ERROR and TIMEOUT', () {
      const ApiException netErr = ApiException(
        code: 'NETWORK_ERROR',
        message: 'Offline',
      );
      const ApiException timeoutErr = ApiException(
        code: 'TIMEOUT',
        message: 'Timed out',
      );
      const ApiException valErr = ApiException(
        code: 'VALIDATION_ERROR',
        message: 'Invalid input',
        statusCode: 400,
      );

      expect(netErr.isConnectivityError, isTrue);
      expect(timeoutErr.isConnectivityError, isTrue);
      expect(valErr.isConnectivityError, isFalse);
    });

    test('LocalImageStorageService.rebindTransactionId moves offline temp ID to server UUID', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalFileDriver driver = createPlatformFileDriver();
      final LocalImageStorageService imageService = LocalImageStorageService(
        prefs: prefs,
        fileDriver: driver,
      );

      final Uint8List slipBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      await imageService.saveImageForTransaction(
        transactionId: 'offline_tx_1001',
        picked: PickedLocalImage(
          fileName: 'slip_offline.jpg',
          bytes: slipBytes,
        ),
      );

      final LocalImageAttachment? rebound = await imageService.rebindTransactionId(
        oldTransactionId: 'offline_tx_1001',
        newTransactionId: 'srv-uuid-9001',
      );

      expect(rebound, isNotNull);
      expect(rebound!.transactionId, 'srv-uuid-9001');

      final Map<String, LocalImageAttachment> mappings =
          await imageService.loadAllMappings();
      expect(mappings.containsKey('offline_tx_1001'), isFalse);
      expect(mappings.containsKey('srv-uuid-9001'), isTrue);
      expect(await imageService.readAttachmentBytes(rebound), equals(slipBytes));
    });

    test('TransactionsController handles online creation and offline disconnection without data loss', () async {
      final _OfflineSimulatingTransactionsRepo repo =
          _OfflineSimulatingTransactionsRepo();
      final Map<String, int> accountBalances = <String, int>{
        'acc-bank': 100000, // ฿1,000.00
        'acc-cash': 50000, // ฿500.00
      };
      final List<PendingTransactionDraft> offlineQueue =
          <PendingTransactionDraft>[];
      int syncSuccessCount = 0;

      final TransactionsController controller = TransactionsController(
        repo: repo,
        isAuthenticated: true,
        onTransactionEffect: (TransactionModel tx, int direction) {
          if (tx.type == TransactionType.income) {
            accountBalances[tx.accountId] =
                (accountBalances[tx.accountId] ?? 0) + (tx.amount * direction);
          } else if (tx.type == TransactionType.expense) {
            accountBalances[tx.accountId] =
                (accountBalances[tx.accountId] ?? 0) - (tx.amount * direction);
          } else if (tx.type == TransactionType.transfer) {
            accountBalances[tx.accountId] =
                (accountBalances[tx.accountId] ?? 0) - (tx.amount * direction);
            if (tx.toAccountId != null) {
              accountBalances[tx.toAccountId!] =
                  (accountBalances[tx.toAccountId!] ?? 0) +
                  (tx.amount * direction);
            }
          }
        },
        onSilentDashboardSync: () {},
        onEnqueueOfflineTransaction: ({
          required TransactionType type,
          required int amount,
          required String accountId,
          String? toAccountId,
          String? categoryId,
          required DateTime occurredAt,
          String? payee,
          String? note,
        }) async {
          final PendingTransactionDraft draft = PendingTransactionDraft(
            localTempId: 'offline_tx_${offlineQueue.length + 1}',
            type: type,
            amount: amount,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            occurredAt: occurredAt,
            payee: payee,
            note: note,
            createdAt: DateTime.now().toUtc(),
          );
          offlineQueue.add(draft);
          return draft.toOptimisticTransactionModel();
        },
        onSyncSuccess: () {
          syncSuccessCount += 1;
        },
      );

      // 1) Online income +฿500.00 to acc-bank
      final TransactionModel onlineTx = await controller.createTransaction(
        type: TransactionType.income,
        amount: 50000,
        accountId: 'acc-bank',
        categoryId: 'cat-salary',
        occurredAt: DateTime.utc(2026, 11, 12, 8),
        payee: 'Company',
      );
      expect(onlineTx.id, 'srv-uuid-1');
      expect(accountBalances['acc-bank'], 150000);
      expect(syncSuccessCount, 1);

      // 2) Simulate internet disconnection -> record expense -฿120.00 from acc-cash
      repo.isOffline = true;
      final TransactionModel offlineTx = await controller.createTransaction(
        type: TransactionType.expense,
        amount: 12000,
        accountId: 'acc-cash',
        categoryId: 'cat-food',
        occurredAt: DateTime.utc(2026, 11, 12, 9),
        payee: 'Cafe',
      );
      expect(offlineTx.id, 'offline_tx_1');
      expect(offlineQueue.length, 1);
      expect(accountBalances['acc-cash'], 38000); // Updated optimistically in-place
      expect(controller.state.items.any((TransactionModel t) => t.id == 'offline_tx_1'), isTrue);

      // 3) Internet reconnects -> replace temp transaction with server UUID
      repo.isOffline = false;
      final TransactionModel syncedServerTx = await repo.createTransaction(
        type: offlineQueue.first.type,
        amount: offlineQueue.first.amount,
        accountId: offlineQueue.first.accountId,
        categoryId: offlineQueue.first.categoryId,
        occurredAt: offlineQueue.first.occurredAt,
        payee: offlineQueue.first.payee,
      );
      controller.replaceOfflineTempTransaction(
        localTempId: 'offline_tx_1',
        syncedTransaction: syncedServerTx,
      );
      expect(controller.state.items.any((TransactionModel t) => t.id == 'offline_tx_1'), isFalse);
      expect(controller.state.items.any((TransactionModel t) => t.id == 'srv-uuid-2'), isTrue);
    });

    test('Analytics & Cloud Storage Usage models parse accurately (Sections 7 & 12)', () {
      final DailyCashflowPoint daily = DailyCashflowPoint.fromJson(<String, dynamic>{
        'date': '2026-11-12',
        'income': 500000,
        'expense': 125000,
        'net': 375000,
      });
      expect(daily.date, '2026-11-12');
      expect(daily.net, 375000);

      final YearlyCashflowPoint yearly = YearlyCashflowPoint.fromJson(<String, dynamic>{
        'year': '2026',
        'income': 60000000,
        'expense': 24000000,
        'net': 36000000,
      });
      expect(yearly.year, '2026');
      expect(yearly.income, 60000000);

      final ServerStorageUsage storage = ServerStorageUsage.fromJson(<String, dynamic>{
        'databaseBytes': 8388608,
        'quotaBytes': 536870912,
        'usagePercent': 1.56,
        'rowCounts': <String, dynamic>{
          'accounts': 3,
          'categories': 18,
          'transactions': 42,
        },
        'policyStatus': <String, dynamic>{
          'transactionImagesOnServer': 0,
          'backupFilesOnServer': 0,
        },
      });
      expect(storage.databaseBytes, 8388608);
      expect(storage.quotaBytes, 536870912);
      expect(storage.transactionImagesOnServer, 0);
      expect(storage.backupFilesOnServer, 0);
    });
  });
}


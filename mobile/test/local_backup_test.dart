import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/storage/local_cache_service.dart';
import 'package:monevo/core/storage/local_file_driver_stub.dart';
import 'package:monevo/core/storage/local_image_storage_service.dart';
import 'package:monevo/core/storage/secure_storage_service.dart';
import 'package:monevo/features/accounts/data/accounts_api.dart';
import 'package:monevo/features/accounts/data/accounts_repository.dart';
import 'package:monevo/features/accounts/domain/account_model.dart';
import 'package:monevo/features/auth/data/auth_api.dart';
import 'package:monevo/features/auth/data/auth_repository.dart';
import 'package:monevo/features/backup/data/backup_crypto.dart';
import 'package:monevo/features/backup/data/local_backup_service.dart';
import 'package:monevo/features/backup/domain/backup_models.dart';
import 'package:monevo/features/categories/data/categories_api.dart';
import 'package:monevo/features/categories/data/categories_repository.dart';
import 'package:monevo/features/categories/domain/category_model.dart';
import 'package:monevo/features/transactions/data/transactions_api.dart';
import 'package:monevo/features/transactions/data/transactions_repository.dart';
import 'package:monevo/features/transactions/domain/transaction_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Local Backup & Restore System (Section 4)', () {
    late LocalBackupService backupService;

    const BackupSettingsPayload sampleSettings = BackupSettingsPayload(
      themeMode: 'dark',
      languageCode: 'th',
      useBuddhistEra: true,
      privacyMode: false,
      autoLockSeconds: 60,
      displayName: 'Somchai',
      baseCurrency: 'THB',
      timezone: 'Asia/Bangkok',
    );

    final AccountModel sampleAccount = AccountModel.fromJson(<String, dynamic>{
      'id': 'acc-kbank-1',
      'name': 'KBank Main',
      'type': 'bank',
      'institution': 'KBank',
      'accountNumberLast4': '8899',
      'currency': 'THB',
      'openingBalance': 100000,
      'balance': 250000,
      'color': '#0D9488',
      'icon': 'account_balance',
      'includeInNetWorth': true,
      'isArchived': false,
      'sortOrder': 0,
      'createdAt': '2026-11-12T02:00:00.000Z',
      'updatedAt': '2026-11-12T02:00:00.000Z',
    });

    final CategoryModel sampleCategory = CategoryModel.fromJson(<String, dynamic>{
      'id': 'cat-food-1',
      'name': 'อาหารและเครื่องดื่ม',
      'type': 'expense',
      'icon': 'restaurant',
      'color': '#F43F5E',
      'isArchived': false,
      'sortOrder': 0,
      'createdAt': '2026-11-12T02:00:00.000Z',
      'updatedAt': '2026-11-12T02:00:00.000Z',
    });

    final TransactionModel sampleExpense = TransactionModel.fromJson(
      <String, dynamic>{
        'id': 'tx-exp-1',
        'type': 'expense',
        'amount': 15000,
        'currency': 'THB',
        'accountId': 'acc-kbank-1',
        'toAccountId': null,
        'categoryId': 'cat-food-1',
        'occurredAt': '2026-11-12T05:00:00.000Z',
        'payee': 'After You',
        'note': 'Honey Toast',
        'createdAt': '2026-11-12T05:00:00.000Z',
        'updatedAt': '2026-11-12T05:00:00.000Z',
      },
    );

    BackupPayload buildSamplePayload() {
      final List<AccountModel> accounts = <AccountModel>[sampleAccount];
      final List<CategoryModel> categories = <CategoryModel>[sampleCategory];
      final List<TransactionModel> transactions = <TransactionModel>[
        sampleExpense,
      ];
      final String checksum = BackupPayload.computeChecksum(
        backupFormatVersion: BackupPayload.currentFormatVersion,
        settings: sampleSettings,
        accounts: accounts,
        categories: categories,
        transactions: transactions,
      );
      return BackupPayload(
        backupFormatVersion: BackupPayload.currentFormatVersion,
        appVersion: '1.0.0',
        createdAt: DateTime.utc(2026, 11, 12, 6),
        settings: sampleSettings,
        accounts: accounts,
        categories: categories,
        transactions: transactions,
        checksumSha256: checksum,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalCacheService cache = LocalCacheService(prefs);
      final Dio dummyDio = Dio();
      final LocalFileDriver driver = createPlatformFileDriver();
      final LocalImageStorageService imageStorage = LocalImageStorageService(
        prefs: prefs,
        fileDriver: driver,
      );

      backupService = LocalBackupService(
        accountsRepo: AccountsRepository(
          api: AccountsApi(dummyDio),
          cache: cache,
        ),
        categoriesRepo: CategoriesRepository(
          api: CategoriesApi(dummyDio),
          cache: cache,
        ),
        transactionsRepo: TransactionsRepository(
          api: TransactionsApi(dummyDio),
          cache: cache,
        ),
        authRepo: AuthRepository(
          api: AuthApi(dummyDio),
          secureStorage: InMemorySecureStorageService(),
          localCache: cache,
        ),
        imageStorage: imageStorage,
        fileDriver: driver,
      );
    });

    test('BackupCrypto encrypts and decrypts with password and rejects wrong password', () {
      final Uint8List plaintext = Uint8List.fromList(
        utf8.encode('{"secret":"monevo-local-backup"}'),
      );
      final Map<String, dynamic> envelope = BackupCrypto.encryptToEnvelope(
        plaintextBytes: plaintext,
        password: 'CorrectHorseBatteryStaple!',
      );

      expect(BackupCrypto.isEncryptedJsonMap(envelope), isTrue);

      final Uint8List decrypted = BackupCrypto.decryptFromEnvelope(
        envelope: envelope,
        password: 'CorrectHorseBatteryStaple!',
      );
      expect(utf8.decode(decrypted), '{"secret":"monevo-local-backup"}');

      expect(
        () => BackupCrypto.decryptFromEnvelope(
          envelope: envelope,
          password: 'WrongPassword',
        ),
        throwsA(isA<BackupInvalidPasswordException>()),
      );
    });

    test('BackupPayload verifies checksum and rejects tampered data or unsupported versions', () {
      final BackupPayload payload = buildSamplePayload();
      final Map<String, dynamic> jsonMap = payload.toJson();

      final BackupPayload verified = BackupPayload.fromAndVerifyJson(jsonMap);
      expect(verified.accounts.length, 1);
      expect(verified.categories.length, 1);
      expect(verified.transactions.length, 1);
      expect(verified.includesImages, isFalse);

      // Tamper with transaction amount -> checksum mismatch
      final Map<String, dynamic> tampered =
          jsonDecode(jsonEncode(jsonMap)) as Map<String, dynamic>;
      ((tampered['transactions'] as List<dynamic>).first
              as Map<String, dynamic>)['amount'] =
          999999;

      expect(
        () => BackupPayload.fromAndVerifyJson(tampered),
        throwsA(isA<BackupCorruptedException>()),
      );

      // Future unsupported format version
      final Map<String, dynamic> futureVersion =
          jsonDecode(jsonEncode(jsonMap)) as Map<String, dynamic>;
      futureVersion['backupFormatVersion'] = 99;
      expect(
        () => BackupPayload.fromAndVerifyJson(futureVersion),
        throwsA(isA<BackupUnsupportedVersionException>()),
      );
    });

    test('LocalBackupService encodes and decodes both .json and .zip (plain and encrypted)', () {
      final BackupPayload payload = buildSamplePayload();

      // 1. Plain JSON
      final Uint8List plainJsonBytes = backupService.encodeBackupBytes(
        payload: payload,
        format: BackupFileFormat.json,
      );
      final DecodedBackupContainer parsedPlainJson = backupService
          .parseAndValidateBackupBytes(plainJsonBytes);
      expect(parsedPlainJson.wasEncrypted, isFalse);
      expect(parsedPlainJson.payload.transactions.first.id, 'tx-exp-1');

      // 2. Encrypted ZIP
      final Uint8List encryptedZipBytes = backupService.encodeBackupBytes(
        payload: payload,
        format: BackupFileFormat.zip,
        password: 'MyBackupPassword2026',
      );

      expect(
        () => backupService.parseAndValidateBackupBytes(encryptedZipBytes),
        throwsA(isA<BackupPasswordRequiredException>()),
      );

      final DecodedBackupContainer parsedEncryptedZip = backupService
          .parseAndValidateBackupBytes(
            encryptedZipBytes,
            password: 'MyBackupPassword2026',
          );
      expect(parsedEncryptedZip.wasEncrypted, isTrue);
      expect(parsedEncryptedZip.payload.accounts.first.name, 'KBank Main');
    });

    test('computeRestorePlanAgainstExisting accurately detects duplicates vs new records', () {
      final BackupPayload payload = buildSamplePayload();
      final DecodedBackupContainer container = DecodedBackupContainer(
        payload: payload,
        wasEncrypted: false,
      );

      // Case A: Existing data already has the same account and category, but no transactions
      final RestorePreviewPlan planA = backupService
          .computeRestorePlanAgainstExisting(
            container: container,
            existingAccounts: <AccountModel>[sampleAccount],
            existingCategories: <CategoryModel>[sampleCategory],
            existingTransactions: const <TransactionModel>[],
          );

      expect(planA.duplicateAccountsCount, 1);
      expect(planA.newAccountsCount, 0);
      expect(planA.duplicateCategoriesCount, 1);
      expect(planA.newCategoriesCount, 0);
      expect(planA.duplicateTransactionsCount, 0);
      expect(planA.newTransactionsCount, 1);

      // Case B: Existing data also has the same transaction
      final RestorePreviewPlan planB = backupService
          .computeRestorePlanAgainstExisting(
            container: container,
            existingAccounts: <AccountModel>[sampleAccount],
            existingCategories: <CategoryModel>[sampleCategory],
            existingTransactions: <TransactionModel>[sampleExpense],
          );

      expect(planB.duplicateTransactionsCount, 1);
      expect(planB.newTransactionsCount, 0);
    });
  });
}


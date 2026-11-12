import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../accounts/domain/account_model.dart';
import '../../categories/domain/category_model.dart';
import '../../transactions/domain/transaction_model.dart';

enum BackupFileFormat {
  json('json'),
  zip('zip');

  const BackupFileFormat(this.extension);
  final String extension;
}

class BackupException implements Exception {
  const BackupException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'BackupException($code): $message';
}

class BackupPasswordRequiredException extends BackupException {
  const BackupPasswordRequiredException()
    : super(
        'PASSWORD_REQUIRED',
        'This backup file is encrypted and requires a password.',
      );
}

class BackupInvalidPasswordException extends BackupException {
  const BackupInvalidPasswordException()
    : super(
        'INVALID_PASSWORD',
        'Incorrect password or corrupted encrypted backup file.',
      );
}

class BackupCorruptedException extends BackupException {
  const BackupCorruptedException(String details)
    : super('CORRUPTED_FILE', details);
}

class BackupUnsupportedVersionException extends BackupException {
  const BackupUnsupportedVersionException(this.fileVersion)
    : super(
        'UNSUPPORTED_VERSION',
        'Backup format version $fileVersion is not supported by this version of MONEVO.',
      );

  final int fileVersion;
}

class BackupSettingsPayload {
  const BackupSettingsPayload({
    required this.themeMode,
    required this.languageCode,
    required this.useBuddhistEra,
    required this.privacyMode,
    required this.autoLockSeconds,
    required this.displayName,
    required this.baseCurrency,
    required this.timezone,
  });

  factory BackupSettingsPayload.fromJson(Map<String, dynamic> json) {
    return BackupSettingsPayload(
      themeMode: (json['themeMode'] ?? 'system').toString(),
      languageCode: (json['languageCode'] ?? 'th').toString(),
      useBuddhistEra: json['useBuddhistEra'] != false,
      privacyMode: json['privacyMode'] == true,
      autoLockSeconds: (json['autoLockSeconds'] as num?)?.toInt() ?? 30,
      displayName: (json['displayName'] ?? '').toString(),
      baseCurrency: (json['baseCurrency'] ?? 'THB').toString(),
      timezone: (json['timezone'] ?? 'Asia/Bangkok').toString(),
    );
  }

  final String themeMode;
  final String languageCode;
  final bool useBuddhistEra;
  final bool privacyMode;
  final int autoLockSeconds;
  final String displayName;
  final String baseCurrency;
  final String timezone;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'themeMode': themeMode,
    'languageCode': languageCode,
    'useBuddhistEra': useBuddhistEra,
    'privacyMode': privacyMode,
    'autoLockSeconds': autoLockSeconds,
    'displayName': displayName,
    'baseCurrency': baseCurrency,
    'timezone': timezone,
  };
}

class BackupPayload {
  const BackupPayload({
    required this.backupFormatVersion,
    required this.appVersion,
    required this.createdAt,
    required this.settings,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.checksumSha256,
    this.includesImages = false,
  });

  static const String expectedSchema = 'com.monevo.local_backup';
  static const int currentFormatVersion = 1;

  final int backupFormatVersion;
  final String appVersion;
  final DateTime createdAt;
  final bool includesImages;
  final BackupSettingsPayload settings;
  final List<AccountModel> accounts;
  final List<CategoryModel> categories;
  final List<TransactionModel> transactions;
  final String checksumSha256;

  List<TransactionModel> get incomeTransactions => transactions
      .where((TransactionModel t) => t.type == TransactionType.income)
      .toList();

  List<TransactionModel> get expenseTransactions => transactions
      .where((TransactionModel t) => t.type == TransactionType.expense)
      .toList();

  List<TransactionModel> get transferTransactions => transactions
      .where((TransactionModel t) => t.type == TransactionType.transfer)
      .toList();

  static String computeChecksum({
    required int backupFormatVersion,
    required BackupSettingsPayload settings,
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required List<TransactionModel> transactions,
  }) {
    final Map<String, dynamic> canonical = <String, dynamic>{
      'v': backupFormatVersion,
      'settings': settings.toJson(),
      'accounts': accounts.map((AccountModel a) => a.toJson()).toList(),
      'categories': categories.map((CategoryModel c) => c.toJson()).toList(),
      'transactions': transactions
          .map((TransactionModel t) => t.toJson())
          .toList(),
    };
    final List<int> bytes = utf8.encode(jsonEncode(canonical));
    return sha256.convert(bytes).toString();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema': expectedSchema,
      'backupFormatVersion': backupFormatVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'includesImages': includesImages,
      'imagePolicyNotice':
          'Transaction data backup does not include slip/receipt images. Use Image Backup (ZIP) to export images separately.',
      'summaryCounts': <String, int>{
        'accounts': accounts.length,
        'categories': categories.length,
        'transactions': transactions.length,
        'incomeTransactions': incomeTransactions.length,
        'expenseTransactions': expenseTransactions.length,
        'transferTransactions': transferTransactions.length,
      },
      'settings': settings.toJson(),
      'accounts': accounts.map((AccountModel a) => a.toJson()).toList(),
      'categories': categories.map((CategoryModel c) => c.toJson()).toList(),
      'transactions': transactions
          .map((TransactionModel t) => t.toJson())
          .toList(),
      'checksumSha256': checksumSha256,
    };
  }

  static BackupPayload fromAndVerifyJson(Map<String, dynamic> json) {
    final String? schema = json['schema']?.toString();
    if (schema != expectedSchema) {
      throw const BackupCorruptedException(
        'Invalid backup schema identifier.',
      );
    }

    final int? version = (json['backupFormatVersion'] as num?)?.toInt();
    if (version == null || version < 1) {
      throw const BackupCorruptedException('Missing or invalid backup version.');
    }
    if (version > currentFormatVersion) {
      throw BackupUnsupportedVersionException(version);
    }

    final Map<String, dynamic>? settingsJson =
        json['settings'] as Map<String, dynamic>?;
    final List<dynamic>? rawAccounts = json['accounts'] as List<dynamic>?;
    final List<dynamic>? rawCategories = json['categories'] as List<dynamic>?;
    final List<dynamic>? rawTransactions =
        json['transactions'] as List<dynamic>?;
    final String? storedChecksum = json['checksumSha256']?.toString();

    if (settingsJson == null ||
        rawAccounts == null ||
        rawCategories == null ||
        rawTransactions == null ||
        storedChecksum == null ||
        storedChecksum.isEmpty) {
      throw const BackupCorruptedException(
        'Backup file is missing required sections or checksum.',
      );
    }

    final BackupSettingsPayload settings = BackupSettingsPayload.fromJson(
      settingsJson,
    );
    final List<AccountModel> accounts = rawAccounts
        .whereType<Map<String, dynamic>>()
        .map(AccountModel.fromJson)
        .toList();
    final List<CategoryModel> categories = rawCategories
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList();
    final List<TransactionModel> transactions = rawTransactions
        .whereType<Map<String, dynamic>>()
        .map(TransactionModel.fromJson)
        .toList();

    final String expectedChecksum = computeChecksum(
      backupFormatVersion: version,
      settings: settings,
      accounts: accounts,
      categories: categories,
      transactions: transactions,
    );

    if (expectedChecksum != storedChecksum) {
      throw const BackupCorruptedException(
        'Checksum mismatch: the backup file has been modified or corrupted.',
      );
    }

    return BackupPayload(
      backupFormatVersion: version,
      appVersion: (json['appVersion'] ?? '1.0.0').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      includesImages: json['includesImages'] == true,
      settings: settings,
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      checksumSha256: storedChecksum,
    );
  }
}

class RestorePreviewPlan {
  const RestorePreviewPlan({
    required this.payload,
    required this.wasEncrypted,
    required this.accountsToCreate,
    required this.duplicateAccountsCount,
    required this.existingAccountIdByBackupId,
    required this.categoriesToCreate,
    required this.duplicateCategoriesCount,
    required this.existingCategoryIdByBackupId,
    required this.transactionsToCreate,
    required this.duplicateTransactionsCount,
  });

  final BackupPayload payload;
  final bool wasEncrypted;

  final List<AccountModel> accountsToCreate;
  final int duplicateAccountsCount;
  final Map<String, String> existingAccountIdByBackupId;

  final List<CategoryModel> categoriesToCreate;
  final int duplicateCategoriesCount;
  final Map<String, String> existingCategoryIdByBackupId;

  final List<TransactionModel> transactionsToCreate;
  final int duplicateTransactionsCount;

  int get totalAccounts => payload.accounts.length;
  int get totalCategories => payload.categories.length;
  int get totalTransactions => payload.transactions.length;

  int get newAccountsCount => accountsToCreate.length;
  int get newCategoriesCount => categoriesToCreate.length;
  int get newTransactionsCount => transactionsToCreate.length;
}

class RestoreResultSummary {
  const RestoreResultSummary({
    required this.accountsRestored,
    required this.accountsSkippedDuplicate,
    required this.categoriesRestored,
    required this.categoriesSkippedDuplicate,
    required this.transactionsRestored,
    required this.transactionsSkippedDuplicate,
    required this.settingsRestored,
    this.safetySnapshotPath,
  });

  final int accountsRestored;
  final int accountsSkippedDuplicate;
  final int categoriesRestored;
  final int categoriesSkippedDuplicate;
  final int transactionsRestored;
  final int transactionsSkippedDuplicate;
  final bool settingsRestored;
  final String? safetySnapshotPath;
}


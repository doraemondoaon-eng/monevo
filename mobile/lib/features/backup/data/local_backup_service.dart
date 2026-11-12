import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_file_driver.dart';
import '../../../core/storage/local_image_storage_service.dart';
import '../../../l10n/app_strings.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_models.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../domain/backup_models.dart';
import 'backup_crypto.dart';

class DecodedBackupContainer {
  const DecodedBackupContainer({
    required this.payload,
    required this.wasEncrypted,
  });

  final BackupPayload payload;
  final bool wasEncrypted;
}

class ImageBackupSummary {
  const ImageBackupSummary({
    required this.imageCount,
    required this.totalBytes,
    this.savedPath,
  });

  final int imageCount;
  final int totalBytes;
  final String? savedPath;
}

/// Section 4 Local Backup and Restore System:
/// Operates 100% locally on the user's device. Backup files are NEVER uploaded
/// to the server.
class LocalBackupService {
  LocalBackupService({
    required AccountsRepository accountsRepo,
    required CategoriesRepository categoriesRepo,
    required TransactionsRepository transactionsRepo,
    required AuthRepository authRepo,
    required LocalImageStorageService imageStorage,
    LocalFileDriver? fileDriver,
  }) : _accountsRepo = accountsRepo,
       _categoriesRepo = categoriesRepo,
       _transactionsRepo = transactionsRepo,
       _authRepo = authRepo,
       _imageStorage = imageStorage,
       _fileDriver = fileDriver ?? createPlatformFileDriver();

  final AccountsRepository _accountsRepo;
  final CategoriesRepository _categoriesRepo;
  final TransactionsRepository _transactionsRepo;
  final AuthRepository _authRepo;
  final LocalImageStorageService _imageStorage;
  final LocalFileDriver _fileDriver;

  static const String _zipJsonEntryName = 'monevo_backup.json';
  static const String _zipManifestEntryName = 'manifest.json';
  static const String _imagesManifestEntryName = 'images_manifest.json';

  /// Fetches all user accounts (including archived), all categories (including archived),
  /// all transaction history pages (income, expense, and transfer), and app settings.
  Future<BackupPayload> collectBackupPayload({
    required AppSettingsState appSettings,
    User? currentUser,
  }) async {
    final List<AccountModel> accounts = await _accountsRepo.getAccounts(
      includeArchived: true,
    );
    final List<CategoryModel> categories = await _categoriesRepo.getCategories(
      includeArchived: true,
    );

    final List<TransactionModel> allTransactions = <TransactionModel>[];
    String? cursor;
    do {
      final PaginatedTransactions page = await _transactionsRepo.getTransactions(
        limit: 100,
        cursor: cursor,
      );
      allTransactions.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null && cursor.isNotEmpty);

    final BackupSettingsPayload settings = BackupSettingsPayload(
      themeMode: appSettings.themeMode.name,
      languageCode: appSettings.language.code,
      useBuddhistEra: appSettings.useBuddhistEra,
      privacyMode: appSettings.privacyMode,
      autoLockSeconds: appSettings.autoLockSeconds,
      displayName: currentUser?.displayName ?? '',
      baseCurrency: currentUser?.baseCurrency ?? 'THB',
      timezone: currentUser?.timezone ?? 'Asia/Bangkok',
    );

    final String checksum = BackupPayload.computeChecksum(
      backupFormatVersion: BackupPayload.currentFormatVersion,
      settings: settings,
      accounts: accounts,
      categories: categories,
      transactions: allTransactions,
    );

    return BackupPayload(
      backupFormatVersion: BackupPayload.currentFormatVersion,
      appVersion: '1.0.0',
      createdAt: DateTime.now().toUtc(),
      settings: settings,
      accounts: accounts,
      categories: categories,
      transactions: allTransactions,
      checksumSha256: checksum,
    );
  }

  /// Encodes [payload] into `.json` or `.zip` bytes, optionally encrypted with [password].
  Uint8List encodeBackupBytes({
    required BackupPayload payload,
    required BackupFileFormat format,
    String? password,
  }) {
    final Uint8List plainJsonBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload.toJson())),
    );

    final bool shouldEncrypt = password != null && password.trim().isNotEmpty;
    final Uint8List innerJsonBytes;
    if (shouldEncrypt) {
      final Map<String, dynamic> envelope = BackupCrypto.encryptToEnvelope(
        plaintextBytes: plainJsonBytes,
        password: password.trim(),
      );
      innerJsonBytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(envelope)),
      );
    } else {
      innerJsonBytes = plainJsonBytes;
    }

    if (format == BackupFileFormat.json) {
      return innerJsonBytes;
    }

    final Map<String, dynamic> manifest = <String, dynamic>{
      'application': 'MONEVO Personal Finance',
      'backupFormatVersion': payload.backupFormatVersion,
      'createdAt': payload.createdAt.toUtc().toIso8601String(),
      'encrypted': shouldEncrypt,
      'includesImages': false,
      'note':
          'Main data backup excludes transaction slip/receipt images. Use Image Backup (ZIP) to export images separately.',
    };
    final Uint8List manifestBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
    );

    final Archive archive = Archive()
      ..addFile(
        ArchiveFile(_zipJsonEntryName, innerJsonBytes.length, innerJsonBytes),
      )
      ..addFile(
        ArchiveFile(
          _zipManifestEntryName,
          manifestBytes.length,
          manifestBytes,
        ),
      );

    final List<int> zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  /// Prompts the user to select where to save the backup file on their device.
  Future<String?> saveBytesToUserChosenLocation({
    required String dialogTitle,
    required String suggestedFileName,
    required Uint8List bytes,
    required List<String> allowedExtensions,
  }) async {
    try {
      final String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedFileName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        bytes: bytes,
      );
      if (savedPath != null && savedPath.isNotEmpty) {
        // Ensure bytes are persisted even on desktop/older Android platforms
        // where saveFile returns only a path without writing the bytes.
        await _fileDriver.writeExternalFile(savedPath, bytes);
        return savedPath;
      }
      return null;
    } catch (_) {
      final String? dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
      if (dir == null || dir.isEmpty) {
        return null;
      }
      final String sep = dir.contains('\\') ? '\\' : '/';
      final String fullPath = '$dir$sep$suggestedFileName';
      await _fileDriver.writeExternalFile(fullPath, bytes);
      return fullPath;
    }
  }

  /// Opens the device File Picker to select a `.json` or `.zip` backup file.
  Future<Uint8List?> pickBackupFileFromDevice({
    List<String> allowedExtensions = const <String>['json', 'zip'],
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final PlatformFile file = result.files.first;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }
    if (file.path != null && file.path!.isNotEmpty) {
      return _fileDriver.readBytes(file.path!);
    }
    return null;
  }

  /// Parses, unzips (if `.zip`), decrypts (if encrypted), checks version,
  /// and verifies the SHA-256 checksum of [rawBytes].
  DecodedBackupContainer parseAndValidateBackupBytes(
    Uint8List rawBytes, {
    String? password,
  }) {
    if (rawBytes.isEmpty) {
      throw const BackupCorruptedException('Backup file is empty.');
    }

    Uint8List jsonBytes = rawBytes;
    if (_looksLikeZip(rawBytes)) {
      try {
        final Archive archive = ZipDecoder().decodeBytes(rawBytes);
        ArchiveFile? backupEntry;
        for (final ArchiveFile file in archive.files) {
          if (file.isFile &&
              (file.name == _zipJsonEntryName ||
                  file.name.endsWith('.json')) &&
              file.name != _zipManifestEntryName) {
            backupEntry = file;
            break;
          }
        }
        if (backupEntry == null) {
          throw const BackupCorruptedException(
            'ZIP archive does not contain monevo_backup.json.',
          );
        }
        final List<int> content = backupEntry.content as List<int>;
        jsonBytes = Uint8List.fromList(content);
      } on BackupException {
        rethrow;
      } catch (_) {
        throw const BackupCorruptedException(
          'Could not extract ZIP backup archive.',
        );
      }
    }

    final Map<String, dynamic> decodedMap;
    try {
      final Object? parsed = jsonDecode(utf8.decode(jsonBytes));
      if (parsed is! Map<String, dynamic>) {
        throw const BackupCorruptedException('Top-level JSON must be an object.');
      }
      decodedMap = parsed;
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupCorruptedException('Invalid JSON format in backup file.');
    }

    bool wasEncrypted = false;
    Map<String, dynamic> payloadMap = decodedMap;

    if (BackupCrypto.isEncryptedJsonMap(decodedMap)) {
      wasEncrypted = true;
      if (password == null || password.trim().isEmpty) {
        throw const BackupPasswordRequiredException();
      }
      final Uint8List decryptedBytes = BackupCrypto.decryptFromEnvelope(
        envelope: decodedMap,
        password: password.trim(),
      );
      try {
        final Object? inner = jsonDecode(utf8.decode(decryptedBytes));
        if (inner is! Map<String, dynamic>) {
          throw const BackupCorruptedException('Decrypted payload is not valid.');
        }
        payloadMap = inner;
      } catch (_) {
        throw const BackupCorruptedException('Decrypted JSON is malformed.');
      }
    }

    final BackupPayload payload = BackupPayload.fromAndVerifyJson(payloadMap);
    return DecodedBackupContainer(payload: payload, wasEncrypted: wasEncrypted);
  }

  /// Compares [container] against current user data to detect duplicates and
  /// compute exact item counts before executing a restore.
  Future<RestorePreviewPlan> buildRestorePreview(
    DecodedBackupContainer container,
  ) async {
    final List<AccountModel> existingAccounts = await _accountsRepo.getAccounts(
      includeArchived: true,
    );
    final List<CategoryModel> existingCategories = await _categoriesRepo
        .getCategories(includeArchived: true);

    final List<TransactionModel> existingTransactions = <TransactionModel>[];
    String? cursor;
    do {
      final PaginatedTransactions page = await _transactionsRepo.getTransactions(
        limit: 100,
        cursor: cursor,
      );
      existingTransactions.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null && cursor.isNotEmpty);

    return computeRestorePlanAgainstExisting(
      container: container,
      existingAccounts: existingAccounts,
      existingCategories: existingCategories,
      existingTransactions: existingTransactions,
    );
  }

  /// Pure duplicate-detection & ID-mapping planner (directly testable).
  RestorePreviewPlan computeRestorePlanAgainstExisting({
    required DecodedBackupContainer container,
    required List<AccountModel> existingAccounts,
    required List<CategoryModel> existingCategories,
    required List<TransactionModel> existingTransactions,
  }) {
    final BackupPayload payload = container.payload;

    // 1. Accounts duplicate detection (by id or natural key name+type+last4)
    final Map<String, String> existingAccountIdByBackupId = <String, String>{};
    final List<AccountModel> accountsToCreate = <AccountModel>[];
    int duplicateAccounts = 0;

    for (final AccountModel backupAcc in payload.accounts) {
      AccountModel? match;
      for (final AccountModel ex in existingAccounts) {
        final bool sameId = ex.id == backupAcc.id;
        final bool sameNaturalKey =
            ex.name.trim().toLowerCase() ==
                backupAcc.name.trim().toLowerCase() &&
            ex.type == backupAcc.type &&
            (ex.accountNumberLast4 ?? '') ==
                (backupAcc.accountNumberLast4 ?? '');
        if (sameId || sameNaturalKey) {
          match = ex;
          break;
        }
      }
      if (match != null) {
        duplicateAccounts++;
        existingAccountIdByBackupId[backupAcc.id] = match.id;
      } else {
        accountsToCreate.add(backupAcc);
      }
    }

    // 2. Categories duplicate detection (by id or natural key name+type)
    final Map<String, String> existingCategoryIdByBackupId = <String, String>{};
    final List<CategoryModel> categoriesToCreate = <CategoryModel>[];
    int duplicateCategories = 0;

    for (final CategoryModel backupCat in payload.categories) {
      CategoryModel? match;
      for (final CategoryModel ex in existingCategories) {
        final bool sameId = ex.id == backupCat.id;
        final bool sameNaturalKey =
            ex.name.trim().toLowerCase() ==
                backupCat.name.trim().toLowerCase() &&
            ex.type == backupCat.type;
        if (sameId || sameNaturalKey) {
          match = ex;
          break;
        }
      }
      if (match != null) {
        duplicateCategories++;
        existingCategoryIdByBackupId[backupCat.id] = match.id;
      } else {
        categoriesToCreate.add(backupCat);
      }
    }

    // 3. Transactions duplicate detection (by id or fingerprint)
    final Set<String> existingIds = existingTransactions
        .map((TransactionModel t) => t.id)
        .toSet();
    final Set<String> existingFingerprints = existingTransactions
        .map(_transactionFingerprint)
        .toSet();

    final List<TransactionModel> transactionsToCreate = <TransactionModel>[];
    int duplicateTransactions = 0;

    for (final TransactionModel backupTx in payload.transactions) {
      final String resolvedAccId =
          existingAccountIdByBackupId[backupTx.accountId] ?? backupTx.accountId;
      final String? resolvedToAccId = backupTx.toAccountId != null
          ? (existingAccountIdByBackupId[backupTx.toAccountId!] ??
                backupTx.toAccountId)
          : null;
      final String? resolvedCatId = backupTx.categoryId != null
          ? (existingCategoryIdByBackupId[backupTx.categoryId!] ??
                backupTx.categoryId)
          : null;

      final TransactionModel candidate = backupTx.copyWith(
        accountId: resolvedAccId,
        toAccountId: resolvedToAccId,
        categoryId: resolvedCatId,
      );

      final String fp = _transactionFingerprint(candidate);
      if (existingIds.contains(backupTx.id) ||
          existingFingerprints.contains(fp)) {
        duplicateTransactions++;
      } else {
        existingFingerprints.add(fp);
        transactionsToCreate.add(backupTx);
      }
    }

    return RestorePreviewPlan(
      payload: payload,
      wasEncrypted: container.wasEncrypted,
      accountsToCreate: accountsToCreate,
      duplicateAccountsCount: duplicateAccounts,
      existingAccountIdByBackupId: existingAccountIdByBackupId,
      categoriesToCreate: categoriesToCreate,
      duplicateCategoriesCount: duplicateCategories,
      existingCategoryIdByBackupId: existingCategoryIdByBackupId,
      transactionsToCreate: transactionsToCreate,
      duplicateTransactionsCount: duplicateTransactions,
    );
  }

  /// Executes a safe, non-destructive restore:
  /// 1. Writes an automatic pre-restore safety snapshot to private app storage.
  /// 2. Creates missing categories & accounts, mapping backup IDs to live IDs.
  /// 3. Creates non-duplicate transactions in chronological order.
  /// 4. Reconciles all affected accounts so balances remain 100% consistent.
  Future<RestoreResultSummary> executeRestore({
    required RestorePreviewPlan plan,
    required AppSettingsController settingsController,
    required AppSettingsState currentSettings,
    User? currentUser,
    bool restoreSettings = true,
  }) async {
    // 1. Prevent data loss: create an automatic pre-restore safety snapshot
    String? safetySnapshotPath;
    try {
      final BackupPayload preSnapshot = await collectBackupPayload(
        appSettings: currentSettings,
        currentUser: currentUser,
      );
      final Uint8List snapshotBytes = encodeBackupBytes(
        payload: preSnapshot,
        format: BackupFileFormat.json,
      );
      safetySnapshotPath = await _fileDriver.copyToAppStorage(
        targetFileName:
            'pre_restore_safety_${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: snapshotBytes,
      );
    } catch (_) {
      // Proceed even if local safety snapshot cannot be written
    }

    final Map<String, String> accountIdMap = Map<String, String>.from(
      plan.existingAccountIdByBackupId,
    );
    final Map<String, String> categoryIdMap = Map<String, String>.from(
      plan.existingCategoryIdByBackupId,
    );

    // 2. Restore missing categories
    int categoriesRestored = 0;
    for (final CategoryModel cat in plan.categoriesToCreate) {
      final CategoryModel created = await _categoriesRepo.createCategory(
        name: cat.name,
        type: cat.type,
        icon: cat.icon,
        color: cat.color,
      );
      if (cat.isArchived) {
        await _categoriesRepo.updateCategory(created.id, isArchived: true);
      }
      categoryIdMap[cat.id] = created.id;
      categoriesRestored++;
    }

    // 3. Restore missing accounts
    int accountsRestored = 0;
    for (final AccountModel acc in plan.accountsToCreate) {
      final AccountModel created = await _accountsRepo.createAccount(
        name: acc.name,
        type: acc.type,
        institution: acc.institution,
        accountNumberLast4: acc.accountNumberLast4,
        currency: acc.currency,
        openingBalance: acc.openingBalance,
        color: acc.color,
        icon: acc.icon,
        includeInNetWorth: acc.includeInNetWorth,
      );
      if (acc.isArchived) {
        await _accountsRepo.updateAccount(created.id, isArchived: true);
      }
      accountIdMap[acc.id] = created.id;
      accountsRestored++;
    }

    // 4. Restore missing transactions (oldest -> newest)
    final List<TransactionModel> chronological = List<TransactionModel>.from(
      plan.transactionsToCreate,
    )..sort((TransactionModel a, TransactionModel b) =>
        a.occurredAt.compareTo(b.occurredAt));

    int transactionsRestored = 0;
    final Set<String> touchedAccountIds = <String>{};
    for (final TransactionModel tx in chronological) {
      final String? targetAccountId = accountIdMap[tx.accountId];
      if (targetAccountId == null) {
        continue;
      }
      final String? targetToAccountId = tx.toAccountId != null
          ? accountIdMap[tx.toAccountId!]
          : null;
      final String? targetCategoryId = tx.categoryId != null
          ? categoryIdMap[tx.categoryId!]
          : null;

      await _transactionsRepo.createTransaction(
        type: tx.type,
        amount: tx.amount,
        accountId: targetAccountId,
        toAccountId: targetToAccountId,
        categoryId: targetCategoryId,
        occurredAt: tx.occurredAt,
        payee: tx.payee,
        note: tx.note,
      );
      touchedAccountIds.add(targetAccountId);
      if (targetToAccountId != null) {
        touchedAccountIds.add(targetToAccountId);
      }
      transactionsRestored++;
    }

    // 5. Reconcile touched accounts to ensure cached balances match ledger
    for (final String accountId in touchedAccountIds) {
      try {
        await _accountsRepo.reconcileAccount(accountId);
      } catch (_) {}
    }

    // 6. Optionally restore local & profile settings
    if (restoreSettings) {
      final BackupSettingsPayload s = plan.payload.settings;
      final ThemeMode mode = s.themeMode == 'light'
          ? ThemeMode.light
          : (s.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.system);
      await settingsController.setThemeMode(mode);
      await settingsController.setLanguage(
        AppLanguage.fromCode(s.languageCode),
      );
      await settingsController.setUseBuddhistEra(s.useBuddhistEra);
      await settingsController.setPrivacyMode(s.privacyMode);
      await settingsController.setAutoLockSeconds(s.autoLockSeconds);
      if (s.displayName.trim().isNotEmpty) {
        try {
          await _authRepo.updateProfile(
            displayName: s.displayName.trim(),
            timezone: s.timezone,
          );
        } catch (_) {}
      }
    }

    return RestoreResultSummary(
      accountsRestored: accountsRestored,
      accountsSkippedDuplicate: plan.duplicateAccountsCount,
      categoriesRestored: categoriesRestored,
      categoriesSkippedDuplicate: plan.duplicateCategoriesCount,
      transactionsRestored: transactionsRestored,
      transactionsSkippedDuplicate: plan.duplicateTransactionsCount,
      settingsRestored: restoreSettings,
      safetySnapshotPath: safetySnapshotPath,
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4.3: Separate Image Backup & Restore (ZIP on user's device)
  // ---------------------------------------------------------------------------

  /// Packages all locally stored slip/receipt images into a ZIP archive
  /// so the user can transfer their transaction images to a new phone.
  Future<({Uint8List zipBytes, int imageCount, int totalImageBytes})>
  buildImagesBackupZipBytes() async {
    final Map<String, LocalImageAttachment> mappings =
        await _imageStorage.loadAllMappings();

    final Archive archive = Archive();
    final List<Map<String, dynamic>> manifestEntries = <Map<String, dynamic>>[];
    int totalBytes = 0;

    for (final LocalImageAttachment att in mappings.values) {
      final Uint8List? bytes = await _imageStorage.readAttachmentBytes(att);
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      final String archiveEntryName =
          'images/${att.transactionId}_${att.originalFileName}';
      archive.addFile(ArchiveFile(archiveEntryName, bytes.length, bytes));
      totalBytes += bytes.length;

      manifestEntries.add(<String, dynamic>{
        'transactionId': att.transactionId,
        'originalFileName': att.originalFileName,
        'archiveEntryName': archiveEntryName,
        'sizeBytes': bytes.length,
        'attachedAt': att.attachedAt.toUtc().toIso8601String(),
      });
    }

    final Map<String, dynamic> manifest = <String, dynamic>{
      'schema': 'com.monevo.local_images_backup',
      'backupFormatVersion': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'imageCount': manifestEntries.length,
      'items': manifestEntries,
    };
    final Uint8List manifestBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
    );
    archive.addFile(
      ArchiveFile(
        _imagesManifestEntryName,
        manifestBytes.length,
        manifestBytes,
      ),
    );

    final List<int> encoded = ZipEncoder().encode(archive);

    return (
      zipBytes: Uint8List.fromList(encoded),
      imageCount: manifestEntries.length,
      totalImageBytes: totalBytes,
    );
  }

  /// Restores transaction slip/receipt images from a separate Image Backup ZIP
  /// into the app's private storage and re-links them to their Transaction IDs.
  Future<ImageBackupSummary> restoreImagesFromZipBytes(
    Uint8List zipBytes,
  ) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const BackupCorruptedException('Invalid image backup ZIP file.');
    }

    ArchiveFile? manifestFile;
    final Map<String, ArchiveFile> filesByName = <String, ArchiveFile>{};
    for (final ArchiveFile f in archive.files) {
      if (!f.isFile) {
        continue;
      }
      if (f.name == _imagesManifestEntryName) {
        manifestFile = f;
      } else {
        filesByName[f.name] = f;
      }
    }

    if (manifestFile == null) {
      throw const BackupCorruptedException(
        'ZIP file is missing images_manifest.json.',
      );
    }

    final Object? decoded = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    );
    if (decoded is! Map<String, dynamic> ||
        decoded['schema'] != 'com.monevo.local_images_backup') {
      throw const BackupCorruptedException('Invalid image backup manifest.');
    }

    final List<dynamic> items =
        (decoded['items'] as List<dynamic>?) ?? <dynamic>[];
    int restoredCount = 0;
    int totalBytes = 0;

    for (final Object? rawItem in items) {
      if (rawItem is! Map<String, dynamic>) {
        continue;
      }
      final String txId = (rawItem['transactionId'] ?? '').toString();
      final String originalName =
          (rawItem['originalFileName'] ?? 'receipt.jpg').toString();
      final String entryName = (rawItem['archiveEntryName'] ?? '').toString();
      final ArchiveFile? entry = filesByName[entryName];
      if (txId.isEmpty || entry == null) {
        continue;
      }
      final Uint8List imageBytes = Uint8List.fromList(
        entry.content as List<int>,
      );
      if (imageBytes.isEmpty) {
        continue;
      }
      await _imageStorage.saveImageForTransaction(
        transactionId: txId,
        picked: PickedLocalImage(
          fileName: originalName,
          bytes: imageBytes,
        ),
      );
      restoredCount++;
      totalBytes += imageBytes.length;
    }

    return ImageBackupSummary(
      imageCount: restoredCount,
      totalBytes: totalBytes,
    );
  }

  static bool _looksLikeZip(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  static String _transactionFingerprint(TransactionModel tx) {
    final String minuteIso = tx.occurredAt
        .toUtc()
        .toIso8601String()
        .substring(0, 16);
    return '${tx.type.apiValue}|${tx.amount}|$minuteIso|${tx.accountId}|${tx.toAccountId ?? ''}|${(tx.payee ?? '').trim().toLowerCase()}|${(tx.note ?? '').trim().toLowerCase()}';
  }
}

final Provider<LocalBackupService> localBackupServiceProvider =
    Provider<LocalBackupService>((Ref ref) {
      return LocalBackupService(
        accountsRepo: ref.watch(accountsRepositoryProvider),
        categoriesRepo: ref.watch(categoriesRepositoryProvider),
        transactionsRepo: ref.watch(transactionsRepositoryProvider),
        authRepo: ref.watch(authRepositoryProvider),
        imageStorage: ref.watch(localImageStorageServiceProvider),
      );
    });


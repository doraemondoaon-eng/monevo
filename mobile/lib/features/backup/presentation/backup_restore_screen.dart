import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_image_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../accounts/presentation/accounts_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../categories/presentation/categories_controller.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../transactions/presentation/transactions_controller.dart';
import '../data/local_backup_service.dart';
import '../domain/backup_models.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  BackupFileFormat _selectedFormat = BackupFileFormat.zip;
  bool _encryptWithPassword = false;
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  String _timestampSuffix() {
    final DateTime now = DateTime.now();
    final String y = now.year.toString().padLeft(4, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm';
  }

  Future<void> _handleExportBackup(AppStrings strings) async {
    if (_encryptWithPassword && _passwordCtrl.text.trim().length < 4) {
      _setStatus(
        strings.tr(
          'กรุณาตั้งรหัสผ่านสำหรับเข้ารหัสไฟล์อย่างน้อย 4 ตัวอักษร',
          'Please enter a backup password of at least 4 characters.',
        ),
        isError: true,
      );
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final LocalBackupService backupService = ref.read(
        localBackupServiceProvider,
      );
      final AppSettingsState appSettings = ref.read(settingsControllerProvider);
      final AuthState authState = ref.read(authControllerProvider);

      final BackupPayload payload = await backupService.collectBackupPayload(
        appSettings: appSettings,
        currentUser: authState.user,
      );

      final Uint8List bytes = backupService.encodeBackupBytes(
        payload: payload,
        format: _selectedFormat,
        password: _encryptWithPassword ? _passwordCtrl.text.trim() : null,
      );

      final String ext = _selectedFormat.extension;
      final String fileName = 'monevo_backup_${_timestampSuffix()}.$ext';

      final String? savedPath = await backupService
          .saveBytesToUserChosenLocation(
            dialogTitle: strings.tr(
              'เลือกตำแหน่งบันทึกไฟล์สำรองข้อมูล MONEVO',
              'Choose location to save MONEVO Backup',
            ),
            suggestedFileName: fileName,
            bytes: bytes,
            allowedExtensions: <String>[ext],
          );

      if (!mounted) {
        return;
      }

      if (savedPath == null) {
        _setStatus(
          strings.tr('ยกเลิกการบันทึกไฟล์สำรองข้อมูล', 'Backup cancelled.'),
        );
      } else {
        _setStatus(
          strings.tr(
            'สำรองข้อมูลลงในเครื่องสำเร็จ (${payload.accounts.length} บัญชี, ${payload.categories.length} หมวดหมู่, ${payload.transactions.length} ธุรกรรม) → $savedPath\nหมายเหตุ: ไฟล์สำรองข้อมูลหลักนี้ไม่รวมรูปภาพสลิป/ใบเสร็จ',
            'Backup saved on device (${payload.accounts.length} accounts, ${payload.categories.length} categories, ${payload.transactions.length} transactions) → $savedPath\nNote: Main backup does not include slip/receipt images.',
          ),
        );
      }
    } catch (e) {
      _setStatus(
        strings.tr(
          'เกิดข้อผิดพลาดในการสร้างไฟล์สำรองข้อมูล: $e',
          'Failed to create backup: $e',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _promptForBackupPassword(AppStrings strings) async {
    final TextEditingController ctrl = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            strings.tr(
              'ไฟล์ Backup ถูกเข้ารหัสด้วยรหัสผ่าน',
              'Encrypted Backup File',
            ),
          ),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: strings.tr(
                'กรอกรหัสผ่านของไฟล์ Backup',
                'Enter backup password',
              ),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: Text(strings.tr('ถอดรหัส', 'Decrypt')),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _handleRestoreBackup(AppStrings strings) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final LocalBackupService backupService = ref.read(
        localBackupServiceProvider,
      );
      final Uint8List? rawBytes = await backupService.pickBackupFileFromDevice(
        allowedExtensions: const <String>['json', 'zip'],
      );
      if (rawBytes == null || !mounted) {
        setState(() => _busy = false);
        return;
      }

      DecodedBackupContainer? container;
      try {
        container = backupService.parseAndValidateBackupBytes(rawBytes);
      } on BackupPasswordRequiredException {
        if (!mounted) {
          return;
        }
        final String? pwd = await _promptForBackupPassword(strings);
        if (pwd == null || pwd.trim().isEmpty || !mounted) {
          setState(() => _busy = false);
          return;
        }
        container = backupService.parseAndValidateBackupBytes(
          rawBytes,
          password: pwd,
        );
      }

      final RestorePreviewPlan plan = await backupService.buildRestorePreview(
        container,
      );
      if (!mounted) {
        return;
      }

      setState(() => _busy = false);

      final ({bool confirmed, bool restoreSettings})? decision =
          await _showPreRestorePreviewDialog(strings, plan);
      if (decision == null || !decision.confirmed || !mounted) {
        return;
      }

      setState(() => _busy = true);
      final RestoreResultSummary summary = await backupService.executeRestore(
        plan: plan,
        settingsController: ref.read(settingsControllerProvider.notifier),
        currentSettings: ref.read(settingsControllerProvider),
        currentUser: ref.read(authControllerProvider).user,
        restoreSettings: decision.restoreSettings,
      );

      // Refresh in-memory controllers
      await Future.wait<void>(<Future<void>>[
        ref.read(accountsControllerProvider.notifier).loadAccounts(),
        ref.read(categoriesControllerProvider.notifier).loadCategories(),
        ref.read(transactionsControllerProvider.notifier).loadInitial(),
        ref.read(dashboardControllerProvider.notifier).refresh(),
      ]);

      if (!mounted) {
        return;
      }

      _setStatus(
        strings.tr(
          'กู้คืนข้อมูลสำเร็จ: นำเข้าใหม่ ${summary.accountsRestored} บัญชี (ข้ามซ้ำ ${summary.accountsSkippedDuplicate}), ${summary.categoriesRestored} หมวดหมู่ (ข้ามซ้ำ ${summary.categoriesSkippedDuplicate}), ${summary.transactionsRestored} ธุรกรรม (ข้ามซ้ำ ${summary.transactionsSkippedDuplicate})',
          'Restore completed: imported ${summary.accountsRestored} accounts (${summary.accountsSkippedDuplicate} duplicates skipped), ${summary.categoriesRestored} categories (${summary.categoriesSkippedDuplicate} duplicates skipped), ${summary.transactionsRestored} transactions (${summary.transactionsSkippedDuplicate} duplicates skipped).',
        ),
      );
    } on BackupInvalidPasswordException {
      _setStatus(
        strings.tr(
          'รหัสผ่านของไฟล์ Backup ไม่ถูกต้อง หรือไฟล์ถูกแก้ไข',
          'Incorrect backup password or authentication tag mismatch.',
        ),
        isError: true,
      );
    } on BackupUnsupportedVersionException catch (e) {
      _setStatus(
        strings.tr(
          'ไม่รองรับไฟล์ Backup เวอร์ชัน ${e.fileVersion} กรุณาอัปเดตแอป MONEVO',
          'Unsupported backup format version ${e.fileVersion}. Please update the app.',
        ),
        isError: true,
      );
    } on BackupCorruptedException catch (e) {
      _setStatus(
        strings.tr(
          'ไฟล์ Backup ไม่ถูกต้องหรือเสียหาย: ${e.message}',
          'Invalid or corrupted backup file: ${e.message}',
        ),
        isError: true,
      );
    } catch (e) {
      _setStatus(
        strings.tr(
          'การกู้คืนข้อมูลล้มเหลว: $e',
          'Restore failed: $e',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<({bool confirmed, bool restoreSettings})?> _showPreRestorePreviewDialog(
    AppStrings strings,
    RestorePreviewPlan plan,
  ) {
    bool restoreSettings = true;
    final bool useBuddhistEra = ref.read(
      settingsControllerProvider.select((AppSettingsState s) => s.useBuddhistEra),
    );
    return showDialog<({bool confirmed, bool restoreSettings})>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return AlertDialog(
              title: Text(
                strings.tr(
                  'ตรวจสอบข้อมูลก่อนกู้คืน (Pre-Restore)',
                  'Verify Backup Before Restore',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.income.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.income,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.tr(
                                'ไฟล์ถูกต้อง (Format v${plan.payload.backupFormatVersion} · SHA-256 Checksum ผ่าน)',
                                'Integrity verified (Format v${plan.payload.backupFormatVersion} · SHA-256 Checksum OK)',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.tr(
                        'สร้างเมื่อ: ${AppDateUtils.formatDateTime(plan.payload.createdAt.toLocal(), language: strings.language, useBuddhistEra: useBuddhistEra)}',
                        'Created at: ${AppDateUtils.formatDateTime(plan.payload.createdAt.toLocal(), language: strings.language, useBuddhistEra: useBuddhistEra)}',
                      ),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const Divider(height: 20),
                    _PreviewStatRow(
                      label: strings.tr('บัญชีธนาคาร', 'Accounts'),
                      total: plan.totalAccounts,
                      newCount: plan.newAccountsCount,
                      duplicateCount: plan.duplicateAccountsCount,
                      strings: strings,
                    ),
                    const SizedBox(height: 8),
                    _PreviewStatRow(
                      label: strings.tr('หมวดหมู่', 'Categories'),
                      total: plan.totalCategories,
                      newCount: plan.newCategoriesCount,
                      duplicateCount: plan.duplicateCategoriesCount,
                      strings: strings,
                    ),
                    const SizedBox(height: 8),
                    _PreviewStatRow(
                      label: strings.tr(
                        'ธุรกรรม (รับ ${plan.payload.incomeTransactions.length} / จ่าย ${plan.payload.expenseTransactions.length} / โอน ${plan.payload.transferTransactions.length})',
                        'Transactions (In ${plan.payload.incomeTransactions.length} / Out ${plan.payload.expenseTransactions.length} / Trf ${plan.payload.transferTransactions.length})',
                      ),
                      total: plan.totalTransactions,
                      newCount: plan.newTransactionsCount,
                      duplicateCount: plan.duplicateTransactionsCount,
                      strings: strings,
                    ),
                    const Divider(height: 20),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: restoreSettings,
                      onChanged: (bool? v) {
                        setModalState(() => restoreSettings = v ?? true);
                      },
                      title: Text(
                        strings.tr(
                          'นำเข้าการตั้งค่าแอปด้วย (ภาษา, ธีม, พ.ศ./ค.ศ.)',
                          'Also restore app settings (language, theme, calendar)',
                        ),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.tr(
                        '• ระบบจะเก็บข้อมูลเดิมไว้ทั้งหมด และนำเข้าเฉพาะรายการที่ไม่ซ้ำ\n• ระบบจะสร้าง Safety Snapshot สำรองข้อมูลปัจจุบันให้อัตโนมัติก่อนเริ่มนำเข้า',
                        '• Existing records are preserved; duplicates are skipped automatically.\n• A pre-restore safety snapshot is saved automatically before import.',
                      ),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(
                    (confirmed: false, restoreSettings: false),
                  ),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(
                    (confirmed: true, restoreSettings: restoreSettings),
                  ),
                  child: Text(
                    strings.tr('ยืนยันการ Restore', 'Confirm Restore'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleExportImagesZip(AppStrings strings) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final LocalBackupService backupService = ref.read(
        localBackupServiceProvider,
      );
      final ({Uint8List zipBytes, int imageCount, int totalImageBytes})
      built = await backupService.buildImagesBackupZipBytes();

      if (built.imageCount == 0) {
        _setStatus(
          strings.tr(
            'ยังไม่มีรูปสลิปหรือใบเสร็จที่แนบไว้ในเครื่องนี้',
            'No local slip or receipt images found on this device.',
          ),
        );
        return;
      }

      final String fileName =
          'monevo_images_backup_${_timestampSuffix()}.zip';
      final String? savedPath = await backupService
          .saveBytesToUserChosenLocation(
            dialogTitle: strings.tr(
              'เลือกตำแหน่งบันทึกไฟล์ ZIP รูปภาพสลิป/ใบเสร็จ',
              'Choose location to save Receipt/Slip Images ZIP',
            ),
            suggestedFileName: fileName,
            bytes: built.zipBytes,
            allowedExtensions: const <String>['zip'],
          );

      if (savedPath == null) {
        _setStatus(
          strings.tr('ยกเลิกการส่งออกไฟล์รูปภาพ', 'Image backup cancelled.'),
        );
      } else {
        final String kb = (built.totalImageBytes / 1024).toStringAsFixed(1);
        _setStatus(
          strings.tr(
            'สำรองรูปภาพสลิป/ใบเสร็จจำนวน ${built.imageCount} รูป ($kb KB) เป็นไฟล์ ZIP สำเร็จ → $savedPath',
            'Exported ${built.imageCount} slip/receipt images ($kb KB) to ZIP → $savedPath',
          ),
        );
      }
    } catch (e) {
      _setStatus(
        strings.tr(
          'เกิดข้อผิดพลาดในการสำรองรูปภาพ: $e',
          'Image backup failed: $e',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleRestoreImagesZip(AppStrings strings) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final LocalBackupService backupService = ref.read(
        localBackupServiceProvider,
      );
      final Uint8List? zipBytes = await backupService.pickBackupFileFromDevice(
        allowedExtensions: const <String>['zip'],
      );
      if (zipBytes == null || !mounted) {
        setState(() => _busy = false);
        return;
      }

      final ImageBackupSummary summary = await backupService
          .restoreImagesFromZipBytes(zipBytes);
      await ref.read(localImageAttachmentsProvider.notifier).reload();

      if (!mounted) {
        return;
      }
      final String kb = (summary.totalBytes / 1024).toStringAsFixed(1);
      _setStatus(
        strings.tr(
          'นำเข้ารูปภาพสลิป/ใบเสร็จกลับเข้าเครื่องสำเร็จ ${summary.imageCount} รูป ($kb KB)',
          'Restored ${summary.imageCount} slip/receipt images ($kb KB) to device storage.',
        ),
      );
    } on BackupException catch (e) {
      _setStatus(e.message, isError: true);
    } catch (e) {
      _setStatus(
        strings.tr(
          'ไม่สามารถนำเข้าไฟล์ ZIP รูปภาพได้: $e',
          'Failed to restore image backup ZIP: $e',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final int localImagesCount = ref.watch(
      localImageAttachmentsProvider.select(
        (Map<String, LocalImageAttachment> m) => m.length,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.tr(
            'สำรองและกู้คืนข้อมูล (ในเครื่อง)',
            'Local Backup & Restore',
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          children: <Widget>[
            // Section 4.3 Mandatory User Notice Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withAlpha(28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold.withAlpha(120)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.accentGold,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.tr(
                        'หมายเหตุสำคัญ: การสำรองข้อมูลธุรกรรมหลัก (JSON / ZIP) จะทำงานบนอุปกรณ์นี้เท่านั้นและไม่รวมรูปภาพสลิปหรือใบเสร็จ หากต้องการย้ายรูปภาพไปยังโทรศัพท์เครื่องใหม่ กรุณาใช้หัวข้อ "สำรองรูปภาพแยกต่างหาก (ZIP)" ด้านล่าง',
                        'Important: Main transaction backups (JSON / ZIP) run strictly on your device and DO NOT include slip/receipt images. To move images to a new phone, use "Separate Image Backup (ZIP)" below.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_statusMessage != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_statusIsError ? AppColors.expense : AppColors.income)
                      .withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (_statusIsError
                            ? AppColors.expense
                            : AppColors.income)
                        .withAlpha(110),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _statusIsError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _statusIsError
                          ? AppColors.expense
                          : AppColors.income,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4.1 Backup Card
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.save_alt_rounded,
                        color: AppColors.primaryEmerald,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.tr(
                            '1. สำรองข้อมูลหลักลงในเครื่อง (Backup)',
                            '1. Create Local Data Backup',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.tr(
                      'รวมรายรับทั้งหมด, รายจ่ายทั้งหมด, บัญชีธนาคาร, หมวดหมู่, ประวัติธุรกรรม และการตั้งค่าระบบ',
                      'Includes all income, expenses, bank accounts, categories, transaction history, and settings.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.tr('รูปแบบไฟล์ (File Format)', 'File Format'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<BackupFileFormat>(
                    segments: <ButtonSegment<BackupFileFormat>>[
                      ButtonSegment<BackupFileFormat>(
                        value: BackupFileFormat.zip,
                        icon: const Icon(Icons.folder_zip_outlined, size: 18),
                        label: Text(
                          strings.tr('ZIP (บรรจุ JSON)', 'ZIP (with JSON)'),
                        ),
                      ),
                      const ButtonSegment<BackupFileFormat>(
                        value: BackupFileFormat.json,
                        icon: Icon(Icons.data_object_rounded, size: 18),
                        label: Text('JSON (.json)'),
                      ),
                    ],
                    selected: <BackupFileFormat>{_selectedFormat},
                    onSelectionChanged: (Set<BackupFileFormat> sel) {
                      setState(() => _selectedFormat = sel.first);
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      strings.tr(
                        'เข้ารหัสไฟล์ด้วยรหัสผ่าน (PBKDF2 + SHA-256)',
                        'Encrypt backup with password',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: _encryptWithPassword,
                    onChanged: (bool val) {
                      setState(() => _encryptWithPassword = val);
                    },
                  ),
                  if (_encryptWithPassword) ...<Widget>[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: strings.tr(
                          'ตั้งรหัสผ่านสำหรับไฟล์ Backup',
                          'Backup encryption password',
                        ),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _handleExportBackup(strings),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      strings.tr(
                        'เลือกตำแหน่งและบันทึกไฟล์ Backup',
                        'Choose Location & Save Backup',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4.2 Restore Card
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.restore_page_outlined,
                        color: AppColors.primaryEmerald,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.tr(
                            '2. กู้คืนข้อมูลจากไฟล์ Backup (Restore)',
                            '2. Restore Data from Backup File',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.tr(
                      'รองรับไฟล์ .json และ .zip (ทั้งแบบปกติและเข้ารหัส) พร้อมตรวจสอบความถูกต้อง, ตรวจสอบเวอร์ชัน, คัดกรองข้อมูลซ้ำ และแสดงสรุปจำนวนรายการก่อนนำเข้าโดยไม่ทำให้ข้อมูลเดิมสูญหาย',
                      'Supports .json and .zip (plain or encrypted) with checksum verification, version check, duplicate filtering, and pre-restore item count preview.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _handleRestoreBackup(strings),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      strings.tr(
                        'เลือกไฟล์ Backup (.json / .zip) เพื่อตรวจสอบและกู้คืน',
                        'Select Backup File (.json / .zip) to Verify & Restore',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4.3 Separate Image Backup Card
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.photo_library_outlined,
                        color: AppColors.primaryEmerald,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.tr(
                            '3. สำรองและกู้คืนรูปภาพแยกต่างหาก (Image ZIP)',
                            '3. Separate Slip / Receipt Image Backup (ZIP)',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.tr(
                      'สำหรับย้ายรูปสลิปและใบเสร็จไปยังโทรศัพท์เครื่องใหม่ (ขณะนี้มีรูปภาพแนบในเครื่อง $localImagesCount รูป)',
                      'Transfer slip and receipt images to a new phone ($localImagesCount images currently stored on this device).',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () => _handleExportImagesZip(strings),
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(
                      strings.tr(
                        'สำรองรูปภาพทั้งหมดเป็นไฟล์ ZIP ลงในเครื่อง',
                        'Export All Slip/Receipt Images as ZIP',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _handleRestoreImagesZip(strings),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: Text(
                      strings.tr(
                        'นำเข้ารูปภาพจากไฟล์ ZIP (Restore Images)',
                        'Import Images from Backup ZIP',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStatRow extends StatelessWidget {
  const _PreviewStatRow({
    required this.label,
    required this.total,
    required this.newCount,
    required this.duplicateCount,
    required this.strings,
  });

  final String label;
  final int total;
  final int newCount;
  final int duplicateCount;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          strings.tr(
            'ทั้งหมด $total รายการ → นำเข้าใหม่ $newCount รายการ · ซ้ำ (ข้าม) $duplicateCount รายการ',
            'Total $total → Import $newCount new · Skip $duplicateCount duplicates',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}


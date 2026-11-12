import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_image_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../accounts/domain/account_model.dart';
import '../../accounts/presentation/accounts_controller.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/presentation/categories_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction_model.dart';
import 'transaction_form_sheet.dart';
import 'transactions_controller.dart';

/// Section 8.2 Transaction Detail Screen (`/transactions/:id`):
/// Displays full transaction metadata, linked bank account(s), category,
/// local slip/receipt attachment stored on device (Section 3.3), and edit/delete actions.
class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.initialTransaction,
  });

  final String transactionId;
  final TransactionModel? initialTransaction;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  TransactionModel? _transaction;
  bool _loading = false;
  ApiException? _error;
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    _transaction = widget.initialTransaction;
    _loadTransactionAndLocalImage();
  }

  Future<void> _loadTransactionAndLocalImage() async {
    setState(() {
      _loading = _transaction == null;
      _error = null;
    });
    try {
      final TransactionModel tx =
          _transaction ??
          await ref
              .read(transactionsRepositoryProvider)
              .getTransaction(widget.transactionId);
      final LocalImageAttachment? attachment = ref
          .read(localImageAttachmentsProvider)[tx.id];
      Uint8List? bytes;
      if (attachment != null) {
        bytes = await ref
            .read(localImageStorageServiceProvider)
            .readAttachmentBytes(attachment);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _transaction = tx;
        _localImageBytes = bytes;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openEditSheet(TransactionModel tx) async {
    final bool? updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransactionFormSheet(existing: tx),
    );
    if (updated == true && mounted) {
      _transaction = null;
      await _loadTransactionAndLocalImage();
    }
  }

  Future<void> _confirmAndDelete(TransactionModel tx, AppStrings strings) async {
    final LocalImageAttachment? attachment = ref
        .read(localImageAttachmentsProvider)[tx.id];
    bool deleteLocalFile = true;

    if (attachment != null) {
      final String? choice = await showDialog<String>(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: Text(strings.deleteTransactionConfirm),
            content: Text(
              strings.tr(
                'รายการนี้มีรูปสลิป/ใบเสร็จที่บันทึกไว้ในเครื่อง คุณต้องการจัดการไฟล์รูปภาพอย่างไร?',
                'This transaction has a local slip/receipt image on your device. How would you like to handle the image file?',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: Text(strings.cancel),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop('keep_image'),
                child: Text(
                  strings.tr(
                    'ลบรายการแต่เก็บรูปไว้ในเครื่อง',
                    'Delete Transaction, Keep Image',
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
                onPressed: () => Navigator.of(ctx).pop('delete_both'),
                child: Text(
                  strings.tr(
                    'ลบทั้งรายการและรูปภาพ',
                    'Delete Transaction & Image',
                  ),
                ),
              ),
            ],
          );
        },
      );
      if (choice == null || choice == 'cancel') {
        return;
      }
      deleteLocalFile = choice == 'delete_both';
    } else {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(strings.deleteTransactionConfirm),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(strings.delete),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    await ref
        .read(transactionsControllerProvider.notifier)
        .deleteTransaction(tx.id);
    if (attachment != null) {
      await ref
          .read(localImageAttachmentsProvider.notifier)
          .removeForTransaction(tx.id, deleteLocalFile: deleteLocalFile);
    }
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final bool useBuddhistEra = ref.watch(
      settingsControllerProvider.select((AppSettingsState s) => s.useBuddhistEra),
    );
    final AccountsState accountsState = ref.watch(accountsControllerProvider);
    final CategoriesState categoriesState = ref.watch(
      categoriesControllerProvider,
    );

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(strings.tr('รายละเอียดธุรกรรม', 'Transaction Detail')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _transaction == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(strings.tr('รายละเอียดธุรกรรม', 'Transaction Detail')),
        ),
        body: ErrorStateView(
          message:
              _error?.localizedMessage(strings) ?? strings.genericErrorMessage,
          onRetry: _loadTransactionAndLocalImage,
        ),
      );
    }

    final TransactionModel tx = _transaction!;
    final AccountModel? fromAccount = accountsState.findById(tx.accountId);
    final AccountModel? toAccount = accountsState.findById(tx.toAccountId);
    final CategoryModel? category = categoriesState.findById(tx.categoryId);

    final bool isIncome = tx.type == TransactionType.income;
    final bool isTransfer = tx.type == TransactionType.transfer;
    final Color accentColor = isTransfer
        ? AppColors.transfer
        : (isIncome ? AppColors.income : AppColors.expense);

    final int signedSatang = isTransfer
        ? tx.amount
        : (isIncome ? tx.amount : -tx.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('รายละเอียดธุรกรรม', 'Transaction Detail')),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openEditSheet(tx),
            icon: const Icon(Icons.edit_outlined),
            tooltip: strings.edit,
          ),
          IconButton(
            onPressed: () => _confirmAndDelete(tx, strings),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            tooltip: strings.delete,
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          children: <Widget>[
            // Amount & Status Hero Card
            PremiumCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      isTransfer
                          ? Icons.swap_horiz_rounded
                          : IconMapper.resolve(category?.icon),
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isTransfer
                          ? strings.transfer
                          : (isIncome ? strings.income : strings.expense),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AmountText(
                    satang: signedSatang,
                    showPlusSign: isIncome,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                  if (tx.payee != null && tx.payee!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      tx.payee!.trim(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Rows Card
            PremiumCard(
              child: Column(
                children: <Widget>[
                  _DetailRow(
                    label: isTransfer
                        ? strings.fromAccountLabel
                        : strings.accountLabel,
                    value: fromAccount?.name ?? '—',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  if (isTransfer) ...<Widget>[
                    const Divider(height: 24),
                    _DetailRow(
                      label: strings.toAccountLabel,
                      value: toAccount?.name ?? '—',
                      icon: Icons.east_rounded,
                    ),
                  ] else ...<Widget>[
                    const Divider(height: 24),
                    _DetailRow(
                      label: strings.categoryLabel,
                      value: category?.name ?? strings.uncategorized,
                      icon: IconMapper.resolve(category?.icon),
                    ),
                  ],
                  const Divider(height: 24),
                  _DetailRow(
                    label: strings.dateTimeLabel,
                    value:
                        '${AppDateUtils.formatFullDate(tx.occurredAt, language: strings.language, useBuddhistEra: useBuddhistEra)} · ${AppDateUtils.formatTimeOnly(tx.occurredAt)}',
                    icon: Icons.schedule_rounded,
                  ),
                  if (tx.note != null && tx.note!.trim().isNotEmpty) ...<Widget>[
                    const Divider(height: 24),
                    _DetailRow(
                      label: strings.noteLabel,
                      value: tx.note!.trim(),
                      icon: Icons.notes_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3.3 & Section 13 Local Slip / Receipt Image Card (Device-Only)
            if (_localImageBytes != null)
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppColors.primaryEmerald,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.tr(
                              'รูปสลิป / ใบเสร็จ (จัดเก็บในเครื่องเท่านั้น)',
                              'Slip / Receipt Image (Stored Locally on Device)',
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _localImageBytes!,
                        width: double.infinity,
                        cacheWidth: 1080,
                        filterQuality: FilterQuality.medium,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              )
            else
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.phonelink_erase_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.tr(
                              'ไม่พบรูปภาพธุรกรรมในอุปกรณ์นี้',
                              'No Local Transaction Image on This Device',
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.tr(
                        'ข้อมูลการเงินของรายการนี้ซิงก์จาก Server เรียบร้อยแล้ว แต่รูปภาพสลิป/ใบเสร็จจากอุปกรณ์เดิมจะไม่ซิงก์ผ่าน Cloud และไม่สามารถเปิดดูจากอุปกรณ์ใหม่ได้โดยอัตโนมัติ (หากย้ายเครื่อง สามารถนำเข้าไฟล์ ZIP รูปภาพได้ที่หน้าสำรองข้อมูล)',
                        'Financial data for this record is synced from the Server, but slip/receipt images from a previous device are never synced to the Cloud and cannot be viewed automatically on a new device. You can import an Image Backup ZIP in Backup & Restore.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => _openEditSheet(tx),
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                          label: Text(
                            strings.tr('แนบรูปในเครื่องนี้', 'Attach Image on Device'),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push('/backup'),
                          icon: const Icon(Icons.folder_zip_outlined, size: 16),
                          label: Text(
                            strings.tr('นำเข้า ZIP รูปภาพ', 'Import Image ZIP'),
                          ),
                        ),
                      ],
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
